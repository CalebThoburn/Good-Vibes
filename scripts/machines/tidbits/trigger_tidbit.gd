extends TidbitType
## Sends a signal out of its port when the player activates the machine.


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input == Machine.ACTIVATE:
		machine.send(cell, 0)


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_circle(Vector2.ZERO, 0.26, color.darkened(0.4))
	canvas.draw_circle(Vector2.ZERO, 0.18, color.lightened(0.3))
