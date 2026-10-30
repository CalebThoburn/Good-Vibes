extends TidbitType
## T flip-flop. Each signal arriving at its input flips it on or off; while on it sends a
## signal out of both outputs every tick (two, since a port takes one wire). It flips
## when a signal starts, so a signal held on for several ticks only flips it once.

const INPUT := 0
const OUTPUTS: Array[int] = [1, 2]

const ON_COLOR := Color(1.0, 0.85, 0.3)


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input != INPUT:
		return
	var state: Dictionary = machine.states.get(cell, {on = false, last_input_tick = -1})
	if state.last_input_tick != machine.tick_count - 1:
		state.on = not state.on
	state.last_input_tick = machine.tick_count
	machine.states[cell] = state


func on_tick(machine: Machine, cell: Vector2i) -> void:
	var state: Dictionary = machine.states.get(cell, {})
	if state.get("on", false):
		for output in OUTPUTS:
			machine.send(cell, output)


func _draw_glyph(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-0.26, -0.13, 0.52, 0.26), color.darkened(0.45))
	canvas.draw_circle(Vector2(0.12, 0.0), 0.15, ON_COLOR)
	canvas.draw_circle(Vector2(-0.12, 0.0), 0.15, color.lightened(0.35))
