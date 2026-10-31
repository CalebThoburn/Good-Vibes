class_name ItemShelf
extends ScrollContainer
## The scrolling shelf the inventory's items sit on. It keeps its size however many
## kinds of item the player has, and takes items dropped back from workbench tidbits
## anywhere on it (even where no slot for that item is showing yet).

var inventory: Inventory


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return ItemSlot.is_from_bench(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	ItemSlot.take_back(inventory, data)
