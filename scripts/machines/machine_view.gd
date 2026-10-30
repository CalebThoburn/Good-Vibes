class_name MachineView
extends Node2D
## Draws a machine in the world and runs it on the machine clock. Its local space is the
## machine's space (see MachineDesign.cell_position).

var machine: Machine


func _init() -> void:
	material = SunShade.lit_material()


## Starts running a design, or stops when `design` is null.
func run(design: MachineDesign, world: BlockWorld, holder: PhysicsBody2D) -> void:
	machine = Machine.new(design, self, world, holder) if design else null
	queue_redraw()


func _enter_tree() -> void:
	MachineClock.ticked.connect(_on_tick)


func _exit_tree() -> void:
	MachineClock.ticked.disconnect(_on_tick)


func _on_tick() -> void:
	if machine:
		machine.tick()


func _draw() -> void:
	if machine:
		MachineDrawer.draw_world(self, machine.design)
