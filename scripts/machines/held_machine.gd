class_name HeldMachine
extends Node2D
## The machine the player has equipped. It pivots on its handle and points at the cursor,
## so a tidbit facing right in the design faces the cursor.

const HOLD_DISTANCE := 10.0

var view := MachineView.new()
## Lets grapples hook the held machine (which then pulls on its holder). Held machines
## have no physics body of their own, so this is an area on the machine layer.
var hitbox := Area2D.new()


func _init() -> void:
	add_child(view)
	hitbox.collision_layer = BlockWorld.MACHINE_LAYER
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.process_mode = PROCESS_MODE_DISABLED # Until something is held.
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * MachineDesign.SIZE * MachineDesign.TIDBIT_PIXELS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	hitbox.add_child(collision)
	view.add_child(hitbox)


func get_design() -> MachineDesign:
	return view.machine.design if view.machine else null


func hold(design: MachineDesign, world: BlockWorld, holder: PhysicsBody2D) -> void:
	if design:
		view.position = -MachineDesign.cell_position(design.find_handle())
	view.run(design, world, holder)
	if view.machine:
		view.machine.self_colliders.append(hitbox.get_rid())
	visible = design != null
	hitbox.process_mode = PROCESS_MODE_INHERIT if design else PROCESS_MODE_DISABLED


## Points the machine along `aim`, given in the parent's space.
func aim_along(aim: Vector2) -> void:
	aim = Vector2.RIGHT if aim.is_zero_approx() else aim.normalized()
	position = aim * HOLD_DISTANCE
	rotation = aim.angle()
	scale.y = -1.0 if aim.x < 0.0 else 1.0 # Keep it right side up when aiming left.
