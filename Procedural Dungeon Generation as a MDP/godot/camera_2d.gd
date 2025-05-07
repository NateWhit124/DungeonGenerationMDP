extends Camera2D

@export var player_nodepath : NodePath
@export var room_tile_width : int
@export var room_tile_height : int

var player_ref : CharacterBody2D

func _ready() -> void:
	player_ref = get_node(player_nodepath)

func _process(delta: float) -> void:
	global_position = floor(player_ref.global_position / Vector2(room_tile_width,room_tile_height)) * Vector2(room_tile_width,room_tile_height)
