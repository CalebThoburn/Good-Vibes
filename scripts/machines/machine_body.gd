class_name MachineBody
extends RigidBody2D
## A machine placed in the world. Hover over it and press Q to activate it; click it to
## pick it back up. Spawned by BlockWorld.spawn_machine().

const MASS_PER_TIDBIT := 10.0
## Low enough that one launcher's thrust can slide even a full machine along the ground.
const FRICTION := 0.1
## Sideways air drag, growing with the square of the speed: it hardly slows a heavy,
## slow machine but caps a light, fast one, so a launcher-driven machine settles at a
## top speed. Falling isn't slowed.
const DRAG := 2.0

var view := MachineView.new()


func _init() -> void:
	collision_layer = BlockWorld.MACHINE_LAYER
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.PLAYER_LAYER | BlockWorld.MACHINE_LAYER
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = FRICTION
	add_child(view)


## Starts running a design. Only its tidbits are solid; empty cells let things through.
func setup(design: MachineDesign, world: BlockWorld) -> void:
	for shape in design.collision_shapes():
		add_child(shape)
	mass = maxf(design.tidbits.size(), 1) * MASS_PER_TIDBIT
	view.run(design, world, self)


func _physics_process(_delta: float) -> void:
	apply_central_force(Vector2(-DRAG * linear_velocity.x * absf(linear_velocity.x), 0.0))
