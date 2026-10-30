extends TidbitType
## While powered, grinds at whatever is just past its tip. A block breaks loose from
## whatever it's part of, leaving a single loose block; a plant part is cut off, along
## with everything beyond it. Harder blocks (BlockType.strength) and thicker wood take
## longer. Its bit needs a clear path to the edge of the grid.

const POWER := 0
## How far past the machine's edge the bit reaches, in pixels.
const REACH := 3.0

## Ticks of grinding per point of block strength.
@export var ticks_per_strength := 1.0


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input == POWER:
		_state(machine, cell).powered_tick = machine.tick_count


func on_tick(machine: Machine, cell: Vector2i) -> void:
	var state := _state(machine, cell)
	if state.powered_tick != machine.tick_count or not get_problem(machine.design, cell).is_empty():
		state.progress = 0
		return
	var tip := machine.muzzle(cell, machine.design.facing(cell), REACH)
	var target := []
	var strength := 0.0
	var plant_hit := machine.world.flora.part_at(tip)
	var block_hit := machine.world.block_at(tip) if plant_hit.is_empty() else {}
	if not plant_hit.is_empty():
		target = [plant_hit.plant.get_instance_id(), plant_hit.part]
		strength = plant_hit.part.thickness * plant_hit.plant.species.wood_strength
	elif not block_hit.is_empty():
		target = [block_hit.grid.get_instance_id(), block_hit.cell]
		strength = Blocks.get_type(block_hit.grid.get_block(block_hit.cell)).strength
	else:
		state.progress = 0
		return
	if target != state.target:
		state.target = target
		state.progress = 0
	state.progress += 1
	if state.progress < ceili(strength * ticks_per_strength):
		return
	state.progress = 0
	if not plant_hit.is_empty():
		plant_hit.plant.cut(plant_hit.part)
	else:
		block_hit.grid.detach_block(block_hit.cell)


func get_problem(design: MachineDesign, cell: Vector2i) -> String:
	if not design.is_clear_to_edge(cell, design.facing(cell)):
		return "Bit is blocked by another tidbit"
	return ""


func _state(machine: Machine, cell: Vector2i) -> Dictionary:
	if not machine.states.has(cell):
		machine.states[cell] = {powered_tick = -1, target = [], progress = 0}
	return machine.states[cell]


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-0.36, -0.2, 0.36, 0.4), color.darkened(0.35))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.0, -0.24), Vector2(0.48, 0.0), Vector2(0.0, 0.24)]),
			color.lightened(0.35))
	canvas.draw_line(Vector2(0.08, -0.12), Vector2(0.24, 0.1), color.darkened(0.3), 0.06)
