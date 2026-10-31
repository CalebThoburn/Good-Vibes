class_name ItemSlot
extends Control
## One kind of item in the inventory, shown only while the player has some. Drag it onto
## a workbench tidbit to attach or load it, or drop items from workbench tidbits here (or
## anywhere on the shelf, see ItemShelf) to take them out. Dragging moves one; hold Shift
## for all.

const SIZE := 52.0

var inventory: Inventory
var type: ItemType


## Starts dragging items: one, or all `available` with Shift held. Leave `from_cell`
## as NO_CELL when they come from the inventory rather than a workbench tidbit; set
## `stored` when they're held by the tidbit rather than attached to it.
static func drag_item(source: Control, item: ItemType, available: int, from_cell := MachineDesign.NO_CELL, stored := false) -> Variant:
	if available <= 0:
		return null
	var amount := available if Input.is_key_pressed(KEY_SHIFT) else 1
	source.set_drag_preview(MachineDrawer.make_preview(Vector2.ONE * SIZE * 0.6, func(canvas: Control) -> void:
		item.draw(canvas, Rect2(Vector2.ZERO, canvas.size))))
	var data := {kind = &"item", item = item, amount = amount}
	if from_cell != MachineDesign.NO_CELL:
		data.from_cell = from_cell
		data.stored = stored
	return data


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIZE


func _ready() -> void:
	tooltip_text = "%s\n%s\nDrag onto a tidbit to attach or load it (Shift: whole stack)." % [type.display_name, type.description]
	inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func _draw() -> void:
	var count := inventory.item_count(type.id)
	draw_rect(Rect2(Vector2.ZERO, size), CraftingGrid.BACKGROUND_COLOR)
	type.draw(self, Rect2(Vector2.ONE * 8, size - Vector2.ONE * 16))
	if count == 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var font := get_theme_default_font()
	draw_string_outline(font, Vector2(0, size.y - 3), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 3, 14, 4, Color.BLACK)
	draw_string(font, Vector2(0, size.y - 3), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 3, 14)


## Takes items dropped from a workbench tidbit back into the inventory.
static func take_back(inventory: Inventory, data: Dictionary) -> void:
	if data.stored:
		inventory.unstore_item(data.from_cell, data.item.id, data.amount)
	else:
		inventory.detach_item(data.from_cell, data.item.id, data.amount)


## Whether drag data is items from a workbench tidbit.
static func is_from_bench(data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == &"item" and data.has("from_cell")


func _on_inventory_changed() -> void:
	visible = inventory.item_count(type.id) > 0
	queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	return drag_item(self, type, inventory.item_count(type.id))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return is_from_bench(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	take_back(inventory, data)
