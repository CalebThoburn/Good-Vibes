extends TidbitType
## Always on: sends a signal out of its port every tick.


func on_tick(machine: Machine, cell: Vector2i) -> void:
	machine.send(cell, 0)


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.06, -0.38), Vector2(-0.2, 0.06), Vector2(-0.02, 0.06),
			Vector2(-0.08, 0.38), Vector2(0.2, -0.08), Vector2(0.02, -0.08)]), Color(1.0, 0.9, 0.35))
