extends RoomTile

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_active_check_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		for trap in $Traps.get_children():
			trap.traps_on = true

func _on_active_check_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		for trap in $Traps.get_children():
			trap.traps_on = false
