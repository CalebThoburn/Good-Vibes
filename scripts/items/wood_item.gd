extends ItemType
## Drawn as a log seen end on beside its bark.


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-0.36, -0.2, 0.6, 0.4), color)
	canvas.draw_rect(Rect2(-0.36, -0.2, 0.6, 0.08), color.lightened(0.2))
	canvas.draw_circle(Vector2(0.24, 0.0), 0.2, color.lightened(0.35))
	canvas.draw_circle(Vector2(0.24, 0.0), 0.09, color.darkened(0.1))
