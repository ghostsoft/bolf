extends Node2D

const TIMESTEP = 3
const GRAVITY = 260
const FRICTION = 0.95
#const FRICTION = 0.994
const BOUNCINESS = 0.1
const WALL_BOUNCINESS = 0.5
const SHOT_POWER = 300

var VIEW_ISOMETRIC := true

var STILL := false

@onready var ball = %Ball
@onready var shadow = %BallShadow
@onready var sprite = %BallSprite

@onready var shadow1 = load("res://ball_shadow.png")
@onready var shadow2 = load("res://ball_shadow2.png")

@export var normal_tex : Texture2D
@export var height_tex : Texture2D

var normal_map : Image
var height_map : Image

var direction = Vector2.RIGHT

var ball_pos : Vector3
var velocity : Vector3 = Vector3.ZERO

var start_pos : Vector3

var charge_time := 0.0
var magnitude := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	normal_map = normal_tex.get_image()
	height_map = height_tex.get_image()
	
	ball_pos.x = ball.global_position.x
	ball_pos.y = ball.global_position.y
	ball_pos.z = 128
	
	set_ball_pos(ball_pos)
	start_pos = ball_pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	_z_layering()
	
	_collide(delta)
	queue_redraw()
	
	charge_time += delta*2
	if Input.is_action_pressed("ui_left"):
		direction = direction.rotated(-PI * delta)
	if Input.is_action_pressed("ui_right"):
		direction = direction.rotated(PI * delta)
	if Input.is_action_just_pressed("ui_accept"):
		charge_time = 0
		magnitude = 0
	if Input.is_action_pressed("ui_accept"):
		magnitude = ((-cos(charge_time)+1)/2) * SHOT_POWER
		%ProgressBar.value = magnitude
	if Input.is_action_just_released("ui_accept"):
		velocity = Vector3(direction.x * magnitude, direction.y * magnitude, 0)
		%ProgressBar.value = 0
	if Input.is_action_just_pressed("ui_cancel"):
		# just for debugging purposes
		for child in $map.get_children():
			if child is TileMapLayer: child.visible = !child.visible
		$Combo.visible = !$Combo.visible
		VIEW_ISOMETRIC = !VIEW_ISOMETRIC
		_reposition_ball()

func _collide(delta : float) -> void:
	var current_height : int = get_height(Vector2(ball_pos.x, ball_pos.y))

	if velocity.is_equal_approx(Vector3.ZERO) && is_equal_approx(current_height, ball_pos.z):
		STILL = true
		return
	STILL = false
	
	velocity.z -= GRAVITY * delta
	
	var magic_value = GRAVITY*delta
	if velocity.length() < magic_value && normal_map.get_pixelv(Vector2i(ball_pos.x, ball_pos.y)).b == 1:
		# we're safely on the ground and not* moving
		velocity = Vector3.ZERO
	
	var desired_pos = ball_pos + (velocity * delta)
	
	if current_height == -255:
		# we're oob, don't collide
		set_ball_pos(desired_pos)
		return
	
	# regular collisions happen
	var normal : Vector3
	
	# here's a lil hack
	# due to the perspective and how the sprite is placed, we can get too close
	# to walls facing the camera. to offset this we test 3 positions
	# offset towards those walls as well as our ball center
	var collision_points : Array[Vector3]
	collision_points.append(ball_pos)
	collision_points.append(ball_pos + Vector3(0, -4, 0)) # south wall
	collision_points.append(ball_pos + Vector3(4, 0, 0)) # west wall
	collision_points.append(ball_pos + Vector3(3, -3, 0)) # corner between the two
	
	var wall_raycast : Vector2
	for i in collision_points:
		var des_pos = i+(velocity * delta)
		wall_raycast = _dda_raycast(Vector2(i.x, i.y), Vector2(des_pos.x, des_pos.y))
		if wall_raycast != Vector2.INF:
			break
	
	#var wall_raycast = _dda_raycast(Vector2(ball_pos.x, ball_pos.y), Vector2(desired_pos.x, desired_pos.y))
	if wall_raycast != Vector2.INF:
		# wall collision
		# make sure we actually get the pixel where the collision occured, depending on direction
		if velocity.y < 0: wall_raycast.y -= 1
		if velocity.x < 0: wall_raycast.x -= 1
		normal = _get_wall_normal(Vector2i(floor(wall_raycast.x), floor(wall_raycast.y)), Vector2(velocity.x, velocity.y))
		
		velocity = _deflect(velocity, normal, FRICTION, WALL_BOUNCINESS)
		desired_pos = Vector3(wall_raycast.x, wall_raycast.y, ball_pos.z) + (velocity * delta)
	elif desired_pos.z <= current_height:
		# floor collision
		var ncol := normal_map.get_pixelv(Vector2i(desired_pos.x, desired_pos.y))
		normal.x = remap(ncol.r, 0, 1, -1, 1)
		normal.y = -remap(ncol.g, 0, 1, -1, 1)
		normal.z = ncol.b # turns out z is actually just 0 to 1 :)

		velocity = _deflect(velocity, normal, FRICTION, BOUNCINESS)
		desired_pos = ball_pos + (velocity * delta)
		# displace by small amount away from normal
		desired_pos += normal
		desired_pos.z = current_height
		set_ball_pos(desired_pos)
	else:
		# don't collide
		set_ball_pos(desired_pos)

func _deflect(_direction : Vector3, _normal : Vector3, _friction : float, _bounciness : float) -> Vector3:
	var vDotN : float = _direction.dot(-_normal)
	var u : Vector3 = -_normal*vDotN
	var w : Vector3 = _direction - u
	return (_friction * w) - (_bounciness * u)

func set_ball_pos(pos : Vector3) -> void:
	ball_pos = pos
	_reposition_ball()
	
	# reset if falling out of level
	if ball_pos.z <= -255:
		ball_pos = start_pos
		velocity = Vector3.ZERO
		shadow.visible = true

func _reposition_ball():
	if VIEW_ISOMETRIC:
		ball.global_position.x = ball_pos.x + ball_pos.y
		ball.global_position.y = -(ball_pos.x/2) + (ball_pos.y / 2) - (ball_pos.z - 127)
		# offset
		ball.global_position.y -= 127
		
		var shadow_height : int
		if is_out_of_bounds(Vector2(ball_pos.x, ball_pos.y)):
			shadow.visible = false
		else:
			var height := get_height(Vector2(ball_pos.x, ball_pos.y))
			if height == -255:
				shadow.visible = false
			else:
				shadow.visible = true
				shadow_height = height
			
			# slope
			var normal = normal_map.get_pixel(ball_pos.x, ball_pos.y)
			if normal.b != 1:
				shadow.texture = shadow2
				if normal.g < 0.49 || normal.r > 0.5:
					shadow.flip_h = true
					shadow.global_position.x -= 1
				else:
					shadow.flip_h = false
			else:
				shadow.texture = shadow1
			
		shadow.global_position.x = ball.global_position.x
		shadow.global_position.y = -(ball_pos.x/2) + (ball_pos.y / 2) - (shadow_height - 127)
		# offset
		shadow.global_position.y -= 125
		
		if shadow.global_position.y < ball.global_position.y:
			shadow.global_position.y = ball.global_position.y+2
		
	else:
		shadow.visible = false
		ball.global_position.x = ball_pos.x
		ball.global_position.y = ball_pos.y

func _get_wall_normal(_position : Vector2i, _direction : Vector2) -> Vector3:
	var normal : Vector3
	var px_pos = Vector2i(_position.x % 8, _position.y % 8)
	var anti_diagonal = px_pos.y < (7-px_pos.x)
	var main_diagonal = px_pos.y < px_pos.x
	
	# we have four cases depending on the direction of entry
	if _direction.y < 0:
		if _direction.x > 0:
			# we're moving up and to the right
			# the two possible walls are west and south going anti-diagonal
			if px_pos == Vector2i(0,7):
				# the corner is the lower left corner
				# the two cases depend on if there's a wall below this corner or not
				var wall_below = (get_height(Vector2(_position.x, _position.y+1)) > ball_pos.z + 4)
				if wall_below:
					normal = Vector3.LEFT # west
				else:
					normal = Vector3.UP # south
			elif anti_diagonal:
				normal = Vector3.LEFT # west
			else:
				normal = Vector3.UP # south
		else:
			# we're moving up and to the left
			# the two possible walls are east and south going diagonal
			if px_pos == Vector2i(7,7):
				# the corner is the lower right corner
				# the two cases depend on if there's a wall below this corner or not
				var wall_below = (get_height(Vector2(_position.x, _position.y+1)) > ball_pos.z + 4)
				if wall_below:
					normal = Vector3.RIGHT # east
				else:
					normal = Vector3.UP # south
			elif main_diagonal:
				normal = Vector3.RIGHT # east
			else:
				normal = Vector3.UP # south
	else:
		if _direction.x > 0:
			# we're moving down and to the right
			# the two possible walls are west and north going diagonal
			if px_pos == Vector2i(0,0):
				# the corner is the upper left corner
				# the two cases depend on if there's a wall above this corner or not
				var wall_above = (get_height(Vector2(_position.x, _position.y-1)) > ball_pos.z + 4)
				if wall_above:
					normal = Vector3.LEFT # west
				else:
					normal = Vector3.DOWN # north
			elif main_diagonal:
				normal = Vector3.DOWN # north
			else:
				normal = Vector3.LEFT # west
		else:
			# we're moving down and to the left
			# the two possible walls are west and north going anti-diagonal
			if px_pos == Vector2i(7,0):
				# the corner is the upper right corner
				# the two cases depend on if there's a wall above this corner or not
				var wall_above = (get_height(Vector2(_position.x, _position.y-1)) > ball_pos.z + 4)
				if wall_above:
					normal = Vector3.RIGHT # east
				else:
					normal = Vector3.DOWN # north
			elif anti_diagonal:
				normal = Vector3.DOWN # north
			else:
				normal = Vector3.RIGHT # east
	
	return normal.normalized()

func _z_layering() -> void:
	sprite.z_index = 3+(2*(ceil(ball_pos.z/4)))
	shadow.z_index = sprite.z_index-1

func is_out_of_bounds(pos : Vector2) -> bool:
	return pos.x < 0 or pos.x > height_map.get_width() or pos.y < 0 or pos.y > height_map.get_height()

func get_height(_position : Vector2) -> int:
	if not is_out_of_bounds(_position):
		var val = height_map.get_pixel(_position.x, _position.y)
		if val.a == 0:
			return -255
		else:
			return val.r8
	else:
		return -255

func _get_path() -> Array[Vector2i]:
	var out : Array[Vector2i]
	var length = 50
	var start_point := Vector2(floor(ball_pos.x), floor(ball_pos.y))
	var line = LineCalculator.grid_traversal(start_point, start_point+direction*length)
	var previous_height = 0
	var wall_index = -1
	for i in line.size():
		var current_height = get_height(line[i])
		if current_height > previous_height+4:
			wall_index = i
			break
		previous_height = current_height
	
	if wall_index >= 0:
		out.append(line[wall_index])
		start_point = line[wall_index]
		var wall_normal = _get_wall_normal(start_point, direction)
		var deflected = _deflect(Vector3(direction.x, direction.y, 0), wall_normal, 1, 1)
		length = line.size()-wall_index
		
		line = LineCalculator.grid_traversal(start_point, start_point + Vector2(deflected.x, deflected.y) * length)
		if not line.is_empty(): # sometimes it brings back a 0 length line i guess
			out.append(line.back())
	else:
		out.append(line.back())
	
	return out

# javidx9 / OneLoneCoder "Super Fast Ray Casting in Tiled Worlds using DDA"
# https://www.youtube.com/watch?v=NbSee-XM7WA
func _dda_raycast(ray_start : Vector2, ray_end : Vector2) -> Vector2:
	var out : Vector2 = Vector2.INF
	
	var ray_dir : Vector2 = (ray_end - ray_start).normalized()
	var ray_unit_step_size : Vector2
	#ray_unit_step_size.x = sqrt(1 + (ray_dir.y / ray_dir.x) * (ray_dir.y / ray_dir.x))
	#ray_unit_step_size.y = sqrt(1 + (ray_dir.x / ray_dir.y) * (ray_dir.x / ray_dir.y))
	ray_unit_step_size = Vector2(abs(1 / ray_dir.x), abs(1 / ray_dir.y))
	
	var map_check : Vector2i = Vector2i(floor(ray_start.x), floor(ray_start.y)) # current tile
	var end_check : Vector2i = Vector2i(floor(ray_end.x), floor(ray_end.y)) # final tile to check
	var ray_length_1d : Vector2 # accumulated length in columns/rows
	
	var step : Vector2i
	
	if ray_dir.x < 0:
		step.x = -1
		ray_length_1d.x = (ray_start.x - float(map_check.x)) * ray_unit_step_size.x
	else:
		step.x = 1
		ray_length_1d.x = (float(map_check.x + 1) - ray_start.x) * ray_unit_step_size.x
	if ray_dir.y < 0:
		step.y = -1
		ray_length_1d.y = (ray_start.y - float(map_check.y)) * ray_unit_step_size.y
	else:
		step.y = 1
		ray_length_1d.y = (float(map_check.y + 1) - ray_start.y) * ray_unit_step_size.y
	
	var collided : bool = false
	var distance : float = 0.0
	var prev_checked : Vector2i
	while !collided && (map_check != end_check):
		prev_checked  = map_check
		if ray_length_1d.x < ray_length_1d.y:
			map_check.x += step.x # update current tile
			distance = ray_length_1d.x
			ray_length_1d.x += ray_unit_step_size.x
		else:
			map_check.y += step.y
			distance = ray_length_1d.y
			ray_length_1d.y += ray_unit_step_size.y
		
		#out.append(map_check)
		if get_height(map_check) > get_height(prev_checked) + 4:
			collided = true
	
	if collided:
		out = ray_start + ray_dir * distance
	
	return out

func _draw() -> void:
	
	if STILL:
		var path = _get_path()
		if VIEW_ISOMETRIC:
			for i in path.size():
				var tmp_x = path[i].x
				path[i].x = path[i].x + path[i].y
				path[i].y = -(tmp_x/2) + (path[i].y/2)
		draw_line(ball.global_position, path[0], Color.YELLOW)
		#draw_line(Vector2(floor(ball_pos.x), floor(ball_pos.y)), path[0], Color.YELLOW)
		if path.size() > 1:
			draw_line(path[0], path[1], Color.RED)
