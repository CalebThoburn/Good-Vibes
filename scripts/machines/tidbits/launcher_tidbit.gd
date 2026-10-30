extends TidbitType
## Fires what it holds (blocks or whole machines, delivered by pipe) the way it faces when
## a signal reaches its port. Its barrel needs a clear path to the edge of the grid. With
## string attached it fires a grapple instead, which holds on while the signal keeps coming.

const POWER := 0

@export var launch_speed := 450.0
## Grapple reach per string, in pixels.
@export var length_per_string := 2.0 * BlockGrid.CELL_SIZE


func can_store(thing: Variant) -> bool:
	return thing is MachineDesign or (thing is StringName and Items.get_type(thing).block != &"")


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input != POWER or not get_problem(machine.design, cell).is_empty():
		return
	var direction := machine.design.facing(cell)
	var string := machine.design.item_count(cell, &"string")
	if string > 0:
		_hold_grapple(machine, cell, direction, string * length_per_string)
		return
	var ammo := machine.design.stored_things(cell)
	if ammo.is_empty():
		return
	var shot: Variant = ammo[0]
	machine.design.unstore(cell, shot)
	if shot is MachineDesign:
		machine.launch_machine(cell, direction, shot, launch_speed)
	else:
		machine.launch_block(cell, direction, Blocks.id_of(Items.get_type(shot).block), launch_speed)


func get_problem(design: MachineDesign, cell: Vector2i) -> String:
	if not design.is_clear_to_edge(cell, design.facing(cell)):
		return "Barrel is blocked by another tidbit"
	return ""


func get_status(design: MachineDesign, cell: Vector2i) -> String:
	var string := design.item_count(cell, &"string")
	if string > 0:
		return "Grapple reach: %d blocks" % roundi(string * length_per_string / BlockGrid.CELL_SIZE)
	if design.stored_things(cell).is_empty():
		return "Empty: pipe blocks or machines in to fire them"
	return ""


## Keeps the grapple going for this tick, firing one if none is out. It lets go of
## whatever it holds once a tick passes without a signal.
func _hold_grapple(machine: Machine, cell: Vector2i, direction: Vector2i, max_length: float) -> void:
	var hook := machine.get_effect(cell) as GrappleHook
	if hook:
		hook.last_signal_tick = machine.tick_count
	else:
		machine.start_effect(cell, GrappleHook.new(machine, cell, direction, max_length))


func _draw_glyph(canvas: CanvasItem) -> void:
	var dark := color.darkened(0.5)
	canvas.draw_rect(Rect2(-0.05, -0.15, 0.5, 0.3), dark)
	canvas.draw_rect(Rect2(0.36, -0.22, 0.12, 0.44), dark)
	canvas.draw_circle(Vector2.ZERO, 0.2, color.darkened(0.25))
