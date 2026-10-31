extends TidbitType
## Fires what it holds (blocks, whole machines, live creatures or other items, loaded on
## the workbench or by pipe) the way it faces when a signal reaches its port. Its barrel needs a clear path to the edge
## of the grid. With string attached it fires a grapple instead, which holds on while the
## signal keeps coming. With nothing to fire, it blows air for as long as the signal lasts.

const POWER := 0

@export var launch_speed := 450.0
## Grapple reach per string, in pixels.
@export var length_per_string := 2.0 * BlockGrid.CELL_SIZE


func can_store(thing: Variant) -> bool:
	return thing is MachineDesign or thing is StoredCreature or (thing is StringName and thing != &"string")


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
		_blow(machine, cell, direction)
		return
	var shot: Variant = ammo[0]
	machine.design.unstore(cell, shot)
	if shot is MachineDesign:
		machine.launch_machine(cell, direction, shot, launch_speed)
	elif shot is StoredCreature:
		machine.launch_creature(cell, direction, shot, launch_speed)
	elif Items.get_type(shot).block:
		machine.launch_block(cell, direction, Blocks.id_of(Items.get_type(shot).block), launch_speed)
	else:
		machine.launch_item(cell, direction, shot, launch_speed)


func get_problem(design: MachineDesign, cell: Vector2i) -> String:
	if not design.is_clear_to_edge(cell, design.facing(cell)):
		return "Barrel is blocked by another tidbit"
	return ""


func get_status(design: MachineDesign, cell: Vector2i) -> String:
	var string := design.item_count(cell, &"string")
	if string > 0:
		return "Grapple reach: %d blocks" % roundi(string * length_per_string / BlockGrid.CELL_SIZE)
	if design.stored_things(cell).is_empty():
		return "Empty: blows air. Pipe things in to fire them"
	return ""


## Keeps the grapple going for this tick, firing one if none is out. It lets go of
## whatever it holds once a tick passes without a signal.
func _hold_grapple(machine: Machine, cell: Vector2i, direction: Vector2i, max_length: float) -> void:
	var effect := machine.get_effect(cell)
	if effect is GrappleHook:
		effect.last_signal_tick = machine.tick_count
	elif effect == null:
		machine.start_effect(cell, GrappleHook.new(machine, cell, direction, max_length))


## Keeps air blowing for this tick, starting it if it isn't already.
func _blow(machine: Machine, cell: Vector2i, direction: Vector2i) -> void:
	var effect := machine.get_effect(cell)
	if effect is AirNozzle:
		effect.last_signal_tick = machine.tick_count
	elif effect == null:
		machine.start_effect(cell, AirNozzle.new(machine, cell, direction, AirNozzle.Mode.BLOW))


func _draw_glyph(canvas: CanvasItem) -> void:
	var dark := color.darkened(0.5)
	canvas.draw_rect(Rect2(-0.05, -0.15, 0.5, 0.3), dark)
	canvas.draw_rect(Rect2(0.36, -0.22, 0.12, 0.44), dark)
	canvas.draw_circle(Vector2.ZERO, 0.2, color.darkened(0.25))
