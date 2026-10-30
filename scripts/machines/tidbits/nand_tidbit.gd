extends TidbitType
## NAND gate. Each tick, unless both inputs got a signal, it sends a signal out of both
## outputs (two so it can feed two things, since a port takes one wire). With nothing
## wired in, it's on.

const INPUTS: Array[int] = [0, 1]
const OUTPUTS: Array[int] = [2, 3]


func on_input(machine: Machine, cell: Vector2i, input: int) -> void:
	if input in INPUTS:
		_inputs_seen(machine, cell)[input] = machine.tick_count


func on_tick(machine: Machine, cell: Vector2i) -> void:
	var seen := _inputs_seen(machine, cell)
	if INPUTS.all(func(input: int) -> bool: return seen[input] == machine.tick_count):
		return
	for output in OUTPUTS:
		machine.send(cell, output)


## The tick each input last got a signal on.
func _inputs_seen(machine: Machine, cell: Vector2i) -> Dictionary:
	if not machine.states.has(cell):
		machine.states[cell] = {0: -1, 1: -1}
	return machine.states[cell]


func _draw_glyph(canvas: CanvasItem) -> void:
	var body := color.lightened(0.3)
	canvas.draw_rect(Rect2(-0.3, -0.24, 0.24, 0.48), body)
	canvas.draw_circle(Vector2(-0.06, 0.0), 0.24, body)
	canvas.draw_circle(Vector2(0.25, 0.0), 0.07, body)
