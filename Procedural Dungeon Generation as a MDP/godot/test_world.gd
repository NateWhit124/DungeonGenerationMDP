extends Node2D

@export var base_room_scene : PackedScene = preload("res://scenes/room_tile.tscn")
@export var pillar_room_scene : PackedScene = preload("res://scenes/pillar_room_tile.tscn")
@export var trap_room_scene : PackedScene = preload("res://scenes/trap_room_tile.tscn")

var x_offset = 384
var y_offset = 224
const ROOM_TRANSLATIONS : Dictionary = {
	"up" : Vector2i(0,-224),
	"down" : Vector2i(0,224),
	"left" : Vector2i(-384,0),
	"right" : Vector2i(384,0),
}

var map_json_path : String = "res://test.json"
var map_json : Dictionary = {}
var rooms : Array = []
var enemies : Array = []
var chests : Array = []
const NUMSUBTYPES : int = 3
var map_width : int
var map_height : int
var map_center : Vector2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#map_json = JSON.parse_string(FileAccess.get_file_as_string(map_json_path))
	map_json = JSON.parse_string($JuliaMDP.create_random_dungeon())
	rooms = map_json["rooms"]
	enemies = map_json["enemies"]
	chests = map_json["enemies"]
	chests = map_json["chests"]
	map_width = map_json["width"]
	map_height = map_json["height"]
	map_center = Vector2i(ceil(map_width/2),ceil(map_height/2))
	
	for y in range(map_height):
		for x in range(map_width):
			var current_tile = get_room(x,y)
			if current_tile != 0:
				place_room(Vector2i(x,y), current_tile)

func get_room(x : int, y : int):
	return rooms[x + y*map_height]

func get_chest_count(subtype : int, x : int, y : int):
	return chests[subtype-1][x + y*map_height]

func get_enemy_count(subtype : int, x : int, y : int):
	return enemies[subtype-1][x + y*map_height]

func place_room(coords : Vector2i, type : int):
	var new_room
	match type:
		1: new_room = base_room_scene.instantiate()
		2: new_room = pillar_room_scene.instantiate()
		3: new_room = trap_room_scene.instantiate()
		_: new_room = base_room_scene.instantiate()
	
	new_room.position += Vector2( (coords - map_center) * Vector2i(x_offset, -y_offset) )
	for i in range(1,NUMSUBTYPES+1):
		new_room.set_chest_count(i,get_chest_count(i,coords.x,coords.y))
		new_room.set_enemy_count(i,get_enemy_count(i,coords.x,coords.y))
	
	var offset_idx = 0
	var adj_room_flags = [0, 0, 0, 0] # up, down, left, right
	for offset in [Vector2i(0,1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(1,0)]:
		var test_coords = coords + offset
		if test_coords.x >= 0 && test_coords.y >=0 && test_coords.x < map_width && test_coords.y < map_height && get_room(test_coords.x, test_coords.y) != 0:
			adj_room_flags[offset_idx] = 1
		offset_idx += 1
	new_room.set_doors(adj_room_flags)
	$Rooms.add_child(new_room)
