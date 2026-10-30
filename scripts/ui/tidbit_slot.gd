class_name TidbitSlot
extends Control
## One kind of tidbit in the inventory. Drag it onto the workbench, or drop workbench
## tidbits here to put them away.

const SIZE := 52.0

var inventory: Inventory
var type: TidbitType


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIZE


func _ready() -> void:
	tooltip_text = "%s\n%s" % [type.display_name, type.description]
	inventory.changed.connect(queue_redraw)


func _draw() -> void:
	var count := inventory.count_of(type.id)
	draw_rect(Rect2(Vector2.ZERO, size), CraftingGrid.BACKGROUND_COLOR)
	type.draw(self, Rect2(Vector2.ONE * 6, size - Vector2.ONE * 12), 0)
	if count == 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var font := get_theme_default_font()
	draw_string_outline(font, Vector2(0, size.y - 3), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 3, 14, 4, Color.BLACK)
	draw_string(font, Vector2(0, size.y - 3), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 3, 14)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory.count_of(type.id) <= 0:
		return null
	set_drag_preview(MachineDrawer.make_preview(Vector2.ONE * CraftingGrid.CELL, func(canvas: Control) -> void:
		type.draw(canvas, Rect2(Vector2.ZERO, canvas.size), 0)))
	return {kind = &"tidbit", type = type}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == &"tidbit" and data.has("from_cell")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	inventory.return_tidbit(data.from_cell)
