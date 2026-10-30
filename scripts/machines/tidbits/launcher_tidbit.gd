extends TidbitType
## Fires a block the way it faces when a signal reaches its port. Its barrel needs a
## clear path to the edge of the grid. With string attached it fires a grapple instead,
## which holds on for as long as the signal keeps coming.

@export var block := &"dirt"
@export var launch_speed := 450.0
## Grapple reach per string, in pixels.
@export var length_per_string := 2.0 * BlockGrid.CELL_SIZE


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input != 0 or not get_problem(machine.design, cell).is_empty():
		return
	var direction := machine.design.facing(cell)
	var string := machine.design.item_count(cell, &"string")
	if string > 0:
		machine.hold_grapple(cell, direction, string * length_per_string)
	else:
		machine.launch_block(cell, direction, Blocks.id_of(block), launch_speed)


func get_problem(design: MachineDesign, cell: Vector2i) -> String:
	if not design.is_clear_to_edge(cell, design.facing(cell)):
		return "Barrel is blocked by another tidbit"
	return ""


func get_status(design: MachineDesign, cell: Vector2i) -> String:
	var string := design.item_count(cell, &"string")
	if string == 0:
		return ""
	return "Grapple reach: %d blocks" % roundi(string * length_per_string / BlockGrid.CELL_SIZE)


func _draw_glyph(canvas: CanvasItem) -> void:
	var dark := color.darkened(0.5)
	canvas.draw_rect(Rect2(-0.05, -0.15, 0.5, 0.3), dark)
	canvas.draw_rect(Rect2(0.36, -0.22, 0.12, 0.44), dark)
	canvas.draw_circle(Vector2.ZERO, 0.2, color.darkened(0.25))
