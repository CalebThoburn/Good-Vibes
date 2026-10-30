class_name MachineBody
extends RigidBody2D
## A machine placed in the world. Hover over it and press Q to activate it; click it to
## pick it back up. Spawned by BlockWorld.spawn_machine().

const MASS_PER_TIDBIT := 10.0

var view := MachineView.new()


func _init() -> void:
	collision_layer = BlockWorld.MACHINE_LAYER
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.PLAYER_LAYER | BlockWorld.MACHINE_LAYER
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * MachineDesign.SIZE * MachineDesign.TIDBIT_PIXELS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	add_child(view)


func setup(design: MachineDesign, world: BlockWorld) -> void:
	mass = maxf(design.tidbits.size(), 1) * MASS_PER_TIDBIT
	view.run(design, world, self)
