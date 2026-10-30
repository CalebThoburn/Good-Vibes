class_name ItemType
extends Resource
## Something the player finds in the world. Items attach to tidbits that accept them
## (see TidbitType.accepted_items) and change what those tidbits do. Each kind is a
## .tres in res://data/items/, optionally with a script extending this one for its icon.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color := Color.WHITE


func draw(canvas: CanvasItem, rect: Rect2) -> void:
	# Glyphs are drawn in a unit square centered on the rect.
	canvas.draw_set_transform(rect.get_center(), 0.0, rect.size)
	_draw_glyph(canvas)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_circle(Vector2.ZERO, 0.35, color)
