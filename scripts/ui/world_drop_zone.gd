class_name WorldDropZone
extends Control
## Covers the screen behind the workbench so machines can be dropped into the world.

var player: Player


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == &"machine"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	player.drop_machine(data.machine, player.get_global_mouse_position())
