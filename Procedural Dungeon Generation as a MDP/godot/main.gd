extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var dungeon_str = $JuliaMDP.create_random_dungeon()
	var dungeon_dict = JSON.parse_string(dungeon_str)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
