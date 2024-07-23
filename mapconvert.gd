@tool
extends Node2D

@export var bake_maps : bool:
	set(value):
		_bake_maps()
		_make_combined()
		_update_texture()
		bake_maps = false

@onready var normal_tiles : Texture2D = load("res://normaltiles.png")
@onready var height_tiles : Texture2D = load("res://heighttiles.png")
var normal_tile_image : Image
var height_tile_image : Image

var bounds : Rect2i
var normal_map : Image
var height_map : Image

var out : Array[Vector3i]

func _make_combined() -> void:
	var combo_map = Image.create_empty(bounds.size.x * 8, bounds.size.y * 8, false, Image.FORMAT_RGBA8)
	combo_map.copy_from(normal_map)
	height_map.adjust_bcs(10, 1, 0)
	for y in combo_map.get_height():
		for x in combo_map.get_width():
			var height_color = height_map.get_pixel(x,y)
			var color = combo_map.get_pixel(x,y) * (Color.WHITE.lerp(height_color, 0.5))
			combo_map.set_pixel(x, y, color)
	combo_map.save_png("./combo.png")

func _update_texture() -> void:
	EditorInterface.get_resource_filesystem().scan_sources()

func get_children_recursive(node : Node) -> Array[Node]:
	var children : Array[Node]
	for n in node.get_children():
		if n.get_child_count() > 0:
			children.append(n)
			children.append_array(get_children_recursive(n))
		else:
			children.append(n)
	return children

# Called when the node enters the scene tree for the first time.
func _bake_maps() -> void:
	normal_tile_image = normal_tiles.get_image()
	height_tile_image = height_tiles.get_image()
	
	for layer in get_children_recursive(self):
		if layer is not TileMapLayer:
			continue
		var tmp_bounds = layer.get_used_rect()
		if tmp_bounds.position.x < bounds.position.x:
			bounds.position.x = tmp_bounds.position.x
		if tmp_bounds.position.y < bounds.position.y:
			bounds.position.y = tmp_bounds.position.y
			
		if tmp_bounds.end.x > bounds.end.x:
			bounds.end.x = tmp_bounds.end.x
		if tmp_bounds.end.y > bounds.end.y:
			bounds.end.y = tmp_bounds.end.y
	
	out.resize(bounds.size.x * bounds.size.y)
	out.fill(Vector3i(-1, -1, -1))

	for layer in get_children_recursive(self):
		if layer is not TileMapLayer:
			continue
		var rect = layer.get_used_rect()
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var height = layer.name.to_int()
				var offset_x = -height/2 as int
				var offset_y = height/2 as int
				print(layer.name + " " + str(offset_x) + str(offset_y))
				
				var tile = layer.get_cell_atlas_coords(Vector2i(x,y))
				
				var index = (x+offset_x) + ((y+offset_y) * bounds.size.x)
				# don't overwrite if the tile is blank
				if Vector2i(tile.x, tile.y) == Vector2i(-1, -1):
					continue
				# don't overwrite if the tile is a wall
				if tile.x > 20:
					continue
				
				out[index].x = tile.x
				out[index].y = tile.y
				out[index].z = height
					
	
	normal_map = Image.create_empty(bounds.size.x * 8, bounds.size.y * 8, false, Image.FORMAT_RGBA8)
	for y in bounds.size.y:
		for x in bounds.size.x:
			var index = x + (y * bounds.size.x)
			if Vector2i(out[index].x, out[index].y) != Vector2i(-1, -1):
				if out[index].y > 0:
					out[index].y = 0
				normal_map.blit_rect(normal_tile_image, Rect2i(out[index].x * 8, out[index].y * 8, 8, 8), Vector2i(x*8,y*8))
	normal_map.save_png("./normal.png")
	
	height_map = Image.create_empty(bounds.size.x * 8, bounds.size.y * 8, false, Image.FORMAT_RGBA8)
	for y in bounds.size.y:
		for x in bounds.size.x:
			var index = x + (y * bounds.size.x)
			if Vector2i(out[index].x, out[index].y) != Vector2i(-1, -1):
				if out[index].y > 0:
					out[index].y = 0
				# somehow do height :)
				var tmp_img : Image = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
				tmp_img.blit_rect(height_tile_image, Rect2i(out[index].x * 8, out[index].y * 8, 8, 8), Vector2i(0,0))
				for i in 8:
					for j in 8:
						var color = tmp_img.get_pixel(i,j)
						color.r8 += (4*out[index].z) -127
						color.g8 = color.r8
						color.b8 = color.r8
						tmp_img.set_pixel(i, j, color)
				height_map.blit_rect(tmp_img, Rect2i(0, 0, 8, 8), Vector2i(x*8,y*8))
	height_map.save_png("./height.png")
