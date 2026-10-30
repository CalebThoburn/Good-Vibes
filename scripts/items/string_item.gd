extends ItemType
## Drawn as a spool.


func _draw_glyph(canvas: CanvasItem) -> void:
	var wood := Color(0.55, 0.38, 0.22)
	canvas.draw_rect(Rect2(-0.32, -0.38, 0.64, 0.12), wood)
	canvas.draw_rect(Rect2(-0.32, 0.26, 0.64, 0.12), wood)
	canvas.draw_rect(Rect2(-0.22, -0.26, 0.44, 0.52), color)
	for y in [-0.14, 0.0, 0.14]:
		canvas.draw_rect(Rect2(-0.22, y - 0.015, 0.44, 0.03), color.darkened(0.25))
