extends StaticBody2D

@export_range(1,3,1) var chest_type : int = 1
var is_opened : bool = false

var common_items = [
	Item.new("health",1),
	Item.new("health",2),
	Item.new("attack_power",0.5)
]

var rare_items = [
	Item.new("total_health",1),
	Item.new("health",5),
	Item.new("attack_power",2)
]

var legendary_items = [
	Item.new("total_health",3),
	Item.new("health",10),
	Item.new("attack_power",3)
]

var item_types = [common_items, rare_items, legendary_items]

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") && !is_opened:
		body.openable_chest = self

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") && !is_opened:
		body.openable_chest = null

func open() -> Item:
	$AnimatedSprite2D.play("open")
	is_opened = true
	$InteractionArea.monitoring = false
	var items = item_types[chest_type - 1]
	var rand_idx = randi_range(0,len(items)-1) 
	return items[rand_idx]
