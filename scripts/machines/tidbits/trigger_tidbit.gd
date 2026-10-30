extends TidbitType
## Sends a signal out of its port when the player presses its key (its setting: Q, E or
## Space) while holding the machine or hovering over it.


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input == Machine.activation_input(machine.design.get_setting(cell) as Machine.Channel):
		machine.send(cell, 0)


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_circle(Vector2(0.0, -0.08), 0.24, color.darkened(0.4))
	canvas.draw_circle(Vector2(0.0, -0.08), 0.16, color.lightened(0.3))
