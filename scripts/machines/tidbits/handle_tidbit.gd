extends TidbitType
## Lets the machine be equipped. A held machine pivots on its handle.


func allows_equip() -> bool:
	return true


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-0.3, -0.4, 0.6, 0.14), color.darkened(0.4))
	canvas.draw_rect(Rect2(-0.12, -0.26, 0.24, 0.66), color.darkened(0.3))
