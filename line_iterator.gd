class_name LineIterator extends Node

var result : Dictionary

var start : Vector2
var end : Vector2

var start_x : int
var start_y : int
var end_x : int
var end_y : int

var direction : Vector2
var norm_direction : Vector2
var step_x : int
var step_y : int

var near_x : float
var near_y : float

var step_to_vertical_side : float
var step_to_horizontal_side : float

var dx : float
var dy : float

var current_x : int
var current_y : int

var grid_bound_x : int
var grid_bound_y : int

var counter : int = 0

func _init(_start : Vector2, _end : Vector2):
	start = _start
	end = _end
	
	start_x = floor(start.x)
	start_y = floor(start.y)
	end_x = floor(end.x)
	end_y = floor(end.y)

	direction = end - start
	norm_direction = direction.normalized()
	step_x = 1 if direction.x > 0 else -1
	step_y = 1 if direction.y > 0 else -1
	
	near_x = start_x + 1 - start.x if step_x > 0 else start.x - start_x
	near_y = start_y + 1 - start.y if step_y > 0 else start.y - start_y
	
	step_to_vertical_side = near_x / norm_direction.x
	step_to_horizontal_side = near_y / norm_direction.y
	
	dx = 1.0 / norm_direction.x
	dy = 1.0 / norm_direction.y
	
	current_x = start_x
	current_y = start_y
	
	grid_bound_x = abs(end_x - start_x)
	grid_bound_y = abs(end_y - start_y)
	
func _iter_init(arg):
	result["pixel"] = Vector2i(start_x, start_y)
	#current = Vector2i(start_x, start_y)
	return steps_left()

func _iter_next(arg):
	# calculate the next step
	if abs(step_to_vertical_side) < abs(step_to_horizontal_side):
		step_to_vertical_side = step_to_vertical_side + dx # to the next vertical grid line
		current_x = current_x + step_x
	else:
		step_to_horizontal_side = step_to_horizontal_side + dy # to the next horizontal grid line
		current_y = current_y + step_y
	
	counter += 1
	
	result["pixel"] = Vector2i(current_x, current_y)
	# this is where i would really like to include more info :')
	return steps_left()

func _iter_get(arg):
	# return the current result
	return result

func steps_left() -> bool:
	# should we continue or stop
	#return counter != (grid_bound_x + grid_bound_y)
	# i *think* the +1 here lets us include the last position too
	return counter != (grid_bound_x + grid_bound_y)
