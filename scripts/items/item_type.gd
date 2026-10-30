class_name ItemType
extends Resource
## Something the player finds in the world. Items attach to tidbits that accept them
## (see TidbitType.accepted_items) and change what those tidbits do, or are held and piped
## around by machines. Each kind is a .tres in res://data/items/, optionally with a script
## extending this one for its icon. Every block type is also an item (see the registry).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color := Color.WHITE
## The BlockType this item is, if it's a block.
@export var block: StringName


func draw(canvas: CanvasItem, rect: Rect2) -> void:
	# Glyphs are drawn in a unit square centered on the rect.
	canvas.draw_set_transform(rect.get_center(), 0.0, rect.size)
	_draw_glyph(canvas)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_glyph(canvas: CanvasItem) -> void:
	if block:
		canvas.draw_rect(Rect2(-0.32, -0.32, 0.64, 0.64), color.darkened(0.35))
		canvas.draw_rect(Rect2(-0.26, -0.26, 0.52, 0.52), color)
	else:
		canvas.draw_circle(Vector2.ZERO, 0.35, color)
