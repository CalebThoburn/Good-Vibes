extends TidbitType
## While powered, sucks the way it faces. With a clear path to the edge of the grid it
## pulls on whatever is in front (see VacuumNozzle). With another tidbit in the way, it
## sucks that tidbit's contents into its own storage instead, one thing per tick.
## Either way, it pushes what it holds out through its pipe, one thing per tick.

const POWER := 0
const OUTLET := 0


func can_store(_thing: Variant) -> bool:
	return true


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input == POWER:
		machine.states[cell] = machine.tick_count


func on_tick(machine: Machine, cell: Vector2i) -> void:
	machine.pipe_out(cell, OUTLET)
	if machine.states.get(cell, -1) != machine.tick_count:
		return
	var direction := machine.design.facing(cell)
	var blocker := machine.design.first_tidbit_toward(cell, direction)
	if blocker != MachineDesign.NO_CELL:
		var thing: Variant = machine.take(blocker)
		if thing != null and not machine.give(cell, thing):
			machine.give(blocker, thing) # Full; put it back.
		return
	var nozzle := machine.get_effect(cell) as VacuumNozzle
	if nozzle:
		nozzle.last_signal_tick = machine.tick_count
	else:
		machine.start_effect(cell, VacuumNozzle.new(machine, cell, direction))


func get_status(design: MachineDesign, cell: Vector2i) -> String:
	if not design.is_clear_to_edge(cell, design.facing(cell)):
		return "Blocked: sucks the contents out of the tidbit in front"
	return ""


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.12, -0.12), Vector2(0.46, -0.34),
			Vector2(0.46, 0.34), Vector2(-0.12, 0.12)]), color.darkened(0.35))
	canvas.draw_circle(Vector2(-0.2, 0.0), 0.2, color.lightened(0.25))
	canvas.draw_circle(Vector2(-0.2, 0.0), 0.09, color.darkened(0.5))
