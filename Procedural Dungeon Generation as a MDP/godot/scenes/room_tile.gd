extends Node2D
class_name RoomTile

@export var skeleton1 : PackedScene = preload("res://objects/enemies/skeleton/skeleton.tscn")
@export var skeleton2 : PackedScene = preload("res://objects/enemies/skeleton/skeleton2.tscn")
@export var skeleton3 : PackedScene = preload("res://objects/enemies/skeleton/skeleton3.tscn")
@export var chest1 : PackedScene = preload("res://objects/chests/chest.tscn")
@export var chest2 : PackedScene = preload("res://objects/chests/chest2.tscn")
@export var chest3 : PackedScene = preload("res://objects/chests/chest3.tscn")

const width : int = 384
const height : int = 224
var _enemy_counts : Dictionary = {
	1: 0,
	2: 0,
	3: 0
}
var _chest_counts : Dictionary = {
	1: 0,
	2: 0,
	3: 0
}
var ENEMIES : Dictionary = {
	1: skeleton1,
	2: skeleton2,
	3: skeleton3
}
var CHESTS : Dictionary = {
	1: chest1,
	2: chest2,
	3: chest3
}
var total_chests_placed : int = 0
var chest_locations : Array = []

func _init() -> void:
	for x in range( width/10 , width-32 , width/10):
		for y in range( height/10 , height-32 , height/10):
			chest_locations.push_back(Vector2(x,y))

func _process(delta: float) -> void:
	pass

func set_enemy_count(enemy_type : int, count : int):
	_enemy_counts[enemy_type] = count
	var placement_margin = 20
	for i in range(count):
		var new_enemy = ENEMIES[enemy_type].instantiate()
		new_enemy.position = Vector2( randf_range(placement_margin, width-placement_margin) , randf_range(placement_margin, height-placement_margin) )
		$Enemies.add_child(new_enemy)

func set_chest_count(chest_type : int, count : int):
	_chest_counts[chest_type] = count
	var placement_margin = 20
	for i in range(count):
		var new_chest = CHESTS[chest_type].instantiate()
		new_chest.position = chest_locations[randi_range(0,len(chest_locations)-1)]
		total_chests_placed += 1
		$Chests.add_child(new_chest)

func set_doors(adj_room_flags : Array):
	$TopArea2D.monitoring = bool(adj_room_flags[0])
	if !adj_room_flags[0]:
		$TileMapLayer.set_cell(Vector2i(12,0), 0, Vector2i(2, 0))
		$TileMapLayer.set_cell(Vector2i(11,0), 0, Vector2i(3, 0))
		
	$BottomArea2D.monitoring = bool(adj_room_flags[1])
	if !adj_room_flags[1]:
		$TileMapLayer.set_cell(Vector2i(12,13), 0, Vector2i(2, 4))
		$TileMapLayer.set_cell(Vector2i(11,13), 0, Vector2i(3, 4))
		
	$LeftArea2D.monitoring = bool(adj_room_flags[2])
	if !adj_room_flags[2]:
		$TileMapLayer.set_cell(Vector2i(0,6), 0, Vector2i(0, 1))
		$TileMapLayer.set_cell(Vector2i(0,7), 0, Vector2i(0, 2))
		
	$RightArea2D.monitoring = bool(adj_room_flags[3])
	if !adj_room_flags[3]:
		$TileMapLayer.set_cell(Vector2i(23,6), 0, Vector2i(5, 1))
		$TileMapLayer.set_cell(Vector2i(23,7), 0, Vector2i(5, 2))
