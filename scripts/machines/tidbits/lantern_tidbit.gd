extends TidbitType
## Burns wood to give off light, one piece every BURN_TICKS, for as long as it has any.
## Wood gets loaded on the workbench, or comes in by pipe (or a vacuum sucking it straight
## in).

## Machine ticks one piece of wood burns for (20 ticks a second): two minutes.
const BURN_TICKS := 2400
## How far the light reaches, in pixels.
@export var light_radius := 112.0


func can_store(thing: Variant) -> bool:
	return thing is StringName and thing == &"wood"


func on_tick(machine: Machine, cell: Vector2i) -> void:
	var fuel: int = machine.states.get(cell, 0)
	if fuel <= 0:
		if machine.design.stored_count(cell, &"wood") == 0:
			return # Out: the glow fades once it's no longer kept up.
		machine.design.unstore(cell, &"wood")
		fuel = BURN_TICKS
	machine.states[cell] = fuel - 1
	var glow := machine.get_effect(cell) as LanternGlow
	if glow:
		glow.last_signal_tick = machine.tick_count
	else:
		machine.start_effect(cell, LanternGlow.new(machine, cell, light_radius))


func get_status(design: MachineDesign, cell: Vector2i) -> String:
	var wood := design.stored_count(cell, &"wood")
	if wood == 0:
		return "No wood: load or pipe some in to light it"
	return "Wood for about %d s" % roundi(wood * BURN_TICKS / float(MachineClock.TICKS_PER_SECOND))


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-0.3, -0.4, 0.6, 0.8), color.darkened(0.5))
	canvas.draw_rect(Rect2(-0.2, -0.28, 0.4, 0.56), Color(1.0, 0.8, 0.4))
	canvas.draw_rect(Rect2(-0.08, -0.12, 0.16, 0.28), Color(1.0, 0.95, 0.75))
