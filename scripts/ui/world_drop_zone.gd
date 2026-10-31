class_name WorldDropZone
extends Control
## Covers the screen behind the workbench so machines (and carried creatures) can be
## dropped into the world.

var player: Player


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") in [&"machine", &"creature"] and not data.has("from_cell")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.kind == &"creature":
		player.drop_creature(data.creature, player.get_global_mouse_position())
	else:
		player.drop_machine(data.machine, player.get_global_mouse_position())
