package game

import "core:fmt"
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"

Snake :: struct {
	segments:    [dynamic]Segment,
	direction:   [2]int,
	move_speed:  f32,
	move_timer:  f32,
	current_pos: [2]int,
	is_dead:     bool,
}

Segment :: struct {
	position: Vector2,
	w:        i32,
	h:        i32,
}

// This should probably be [2]int tbh
Vector2 :: struct {
	x: f32,
	y: f32,
}

Grid :: struct {
	cols: int,
	rows: int,
}

Food :: struct {
	position:   Vector2,
	reposition: bool,
}

SEGMENT_SIZE :: 80
SCREEN_WIDTH :: 1280
SCREEN_HEIGHT :: 720
GRID :: Grid {
	cols = 16,
	rows = 9,
}
START_POS_X :: (SCREEN_WIDTH / 2)
START_POS_Y :: (SCREEN_HEIGHT / 2) - 40

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}

Direction_Vectors :: [Direction][2]int {
	.Up    = {0, -1},
	.Down  = {0, 1},
	.Left  = {-1, 0},
	.Right = {1, 0},
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Snake")
	rl.SetTargetFPS(60)

	snake := make_snake()
	food := make_food()

	for !rl.WindowShouldClose() {
		get_inputs(&snake)
		update_food_position()
		update_segment_positions(&snake, &food)
		check_game_end(&snake)

		rl.BeginDrawing()

		rl.ClearBackground(rl.WHITE)
		draw_grid()
		draw_food(&food)
		draw_snake(&snake)

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

update_food_position :: proc() {

}

// Are you winning yet, son?
check_game_end :: proc(snake: ^Snake) {
	if !snake.is_dead do return

	snake.move_speed = 0
	fmt.printf("Game over")
}

get_inputs :: proc(snake: ^Snake) {
	if rl.IsKeyPressed(.C) {
		append_segment(snake)
	}

	direction := &snake.direction

	if rl.IsKeyPressed(.A) && direction^ != Direction_Vectors[.Right] {
		direction^ = Direction_Vectors[.Left]
	} else if rl.IsKeyPressed(.S) && direction^ != Direction_Vectors[.Up] {
		direction^ = Direction_Vectors[.Down]
	} else if rl.IsKeyPressed(.D) && direction^ != Direction_Vectors[.Left] {
		direction^ = Direction_Vectors[.Right]
	} else if rl.IsKeyPressed(.W) && direction^ != Direction_Vectors[.Down] {
		direction^ = Direction_Vectors[.Up]
	}
}


//
// Position updates
//

// Updates the segments at an interval related to the speed of the snake
update_segment_positions :: proc(snake: ^Snake, food: ^Food) {
	dt := rl.GetFrameTime()
	snake.move_timer += dt

	if snake.move_timer >= (1.0 / snake.move_speed) {
		snake.move_timer = 0

		// Create array that holds the current segments
		prev_positions := make([]Segment, len(snake.segments))

		// Clean up after proc
		defer delete(prev_positions)

		// Create a new array by slicing snake segments so we don't mutate the original array
		copy(prev_positions, snake.segments[:])

		future_x, future_y := calc_new_position(snake)

		if check_collisions(snake, future_x, future_y) {
			snake.is_dead = true

			return
		}

		// No collision so update the first segment
		snake.segments[0].position.x = future_x
		snake.segments[0].position.y = future_y

		// Eat food, probably couldve made a more generic collision checker /shrug
		if check_food_collision(food, snake) do eat(food, snake)

		// Updates every segment based on the segment before it starting after the first segment
		for i in 1 ..< len(snake.segments) {
			snake.segments[i].position.x = prev_positions[i - 1].position.x
			snake.segments[i].position.y = prev_positions[i - 1].position.y
		}
	}
}

// Calculate the next position the snake is attempting to make
calc_new_position :: proc(snake: ^Snake) -> (f32, f32) {
	move_to_x := f32(snake.direction[0] * SEGMENT_SIZE)
	move_to_y := f32(snake.direction[1] * SEGMENT_SIZE)

	new_x := snake.segments[0].position.x + move_to_x
	new_y := snake.segments[0].position.y + move_to_y

	return new_x, new_y
}

//
// Actions
//

eat :: proc(food: ^Food, snake: ^Snake) {
	append_segment(snake)

	snake.move_speed += 0.4

	reposition_food(food)
}

reposition_food :: proc(food: ^Food) {
	food.position = get_random_grid_position()
}

//
// Segment/snake building helpers
//

// Builds a snake and appends the initial segment
make_snake :: proc() -> Snake {
	snake := Snake {
		segments    = make([dynamic]Segment),
		move_speed  = 1.4,
		direction   = Direction_Vectors[.Down],
		current_pos = [2]int{START_POS_X, START_POS_Y},
		is_dead     = false,
	}

	append(&snake.segments, make_segment(START_POS_X, START_POS_Y))

	return snake
}

// Build the food
make_food :: proc() -> Food {
	position := get_random_grid_position()

	food := Food {
		position   = position,
		reposition = false,
	}

	return food
}

// Build a segment of the snake
make_segment :: proc(x: f32, y: f32) -> Segment {
	return Segment{position = Vector2{x = x, y = y}, w = SEGMENT_SIZE, h = SEGMENT_SIZE}
}

// Append a segment to the snake based on the current last segment in the snake
append_segment :: proc(snake: ^Snake) {
	last_segment := snake.segments[len(snake.segments) - 1]

	append(&snake.segments, make_segment(last_segment.position.x, last_segment.position.y))
}


//
// Draw
//

// Draw a black rect with a white outline
draw_snake :: proc(snake: ^Snake) {
	for segment, index in snake.segments {
		// Black rect
		rl.DrawRectangle(
			i32(segment.position.x),
			i32(segment.position.y),
			segment.w,
			segment.h,
			rl.BLACK,
		)
		// White outline
		rl.DrawRectangleLinesEx(
			rl.Rectangle {
				f32(segment.position.x),
				f32(segment.position.y),
				f32(segment.w),
				f32(segment.h),
			},
			2.0,
			rl.WHITE,
		)
	}
}

// Draw 16x9 grid
draw_grid :: proc() {
	for row in 0 ..< GRID.rows {
		for col in 0 ..< GRID.cols {

			rl.DrawRectangleLinesEx(
				rl.Rectangle {
					f32(col * SEGMENT_SIZE),
					f32(row * SEGMENT_SIZE),
					SEGMENT_SIZE,
					SEGMENT_SIZE,
				},
				1.0,
				rl.BLACK,
			)

		}
	}
}

draw_food :: proc(food: ^Food) {
	rl.DrawRectangle(
		i32(food.position.x),
		i32(food.position.y),
		SEGMENT_SIZE,
		SEGMENT_SIZE,
		rl.GRAY,
	)
}

//
// Collision checking
//

Collision_Proc :: proc(snake: ^Snake, future_x: f32, future_y: f32) -> bool

// Moves through multiple collision checking procs to determine if the first segments
// coordinates are colliding
check_collisions :: proc(snake: ^Snake, future_x: f32, future_y: f32) -> bool {
	collision_procs := [2]Collision_Proc{check_out_of_bounds, check_collide_with_self}

	for collision_proc in collision_procs {
		if collision_proc(snake, future_x, future_y) {
			return true
		}
	}

	return false
}

check_collide_with_self :: proc(snake: ^Snake, future_x: f32, future_y: f32) -> bool {
	for i in 1 ..< len(snake.segments) {
		if snake.segments[i].position.x == future_x && snake.segments[i].position.y == future_y {
			return true
		}
	}
	return false
}

check_out_of_bounds :: proc(snake: ^Snake, future_x: f32, future_y: f32) -> bool {
	/*
		1) True if too far right
		2) True if too far left
		3) true if too far down
		4) True if too far up
	*/
	return(
		future_x + SEGMENT_SIZE > SCREEN_WIDTH ||
		future_x < 0 ||
		future_y + SEGMENT_SIZE > SCREEN_HEIGHT ||
		future_y < 0 \
	)
}

check_food_collision :: proc(food: ^Food, snake: ^Snake) -> bool {
	head := snake.segments[0]

	return head.position.x == food.position.x && head.position.y == food.position.y
}


//
// Utils
//

get_random_grid_position :: proc() -> Vector2 {
	return Vector2 {
		x = f32(rand.int_max(GRID.cols) * SEGMENT_SIZE),
		y = f32(rand.int_max(GRID.rows) * SEGMENT_SIZE),
	}
}
