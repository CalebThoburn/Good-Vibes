class_name LanternGlow
extends Node2D
## The light of a burning lantern. Lives while the lantern keeps burning; SunShade
## gathers every glow into the lighting each frame.

const GROUP := &"lantern_glows"

var machine: Machine
var cell: Vector2i
var radius: float
## The machine tick the lantern last burned on.
var last_signal_tick := 0


func _init(p_machine: Machine, p_cell: Vector2i, p_radius: float) -> void:
	machine = p_machine
	cell = p_cell
	radius = p_radius
	last_signal_tick = machine.tick_count
	top_level = true
	add_to_group(GROUP)


func _physics_process(_delta: float) -> void:
	if not machine.is_running() or machine.tick_count > last_signal_tick:
		queue_free()
		return
	global_position = machine.host.to_global(MachineDesign.cell_position(cell))


## How bright it is right now, with a little flicker.
func strength() -> float:
	var time := Time.get_ticks_msec() / 1000.0
	return 0.9 + 0.06 * sin(time * 7.3 + global_position.x) + 0.04 * sin(time * 13.1)
