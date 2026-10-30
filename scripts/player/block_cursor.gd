class_name BlockCursor
extends Node2D
## Outlines a rect in some transformed space, such as a rotated machine. Keep top_level on.

var _rect := Rect2()
var _color := Color.WHITE


## Outlines `rect`, given in the space of `xform`.
func show_rect(xform: Transform2D, rect: Rect2, color: Color) -> void:
	global_transform = xform
	_rect = rect
	_color = color
	show()
	queue_redraw()


func _draw() -> void:
	draw_rect(_rect, _color, false, 1.0)
