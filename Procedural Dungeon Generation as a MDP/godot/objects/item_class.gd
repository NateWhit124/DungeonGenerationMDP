extends Node
class_name Item

var affects_property : String = "health"
var effect_amount : float = 1

func _init(property : String, amount : float):
	affects_property = property
	effect_amount = amount
