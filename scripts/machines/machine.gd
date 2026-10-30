class_name Machine
extends RefCounted
## A running machine. Every input a tidbit receives is handled on the next machine tick,
## so each tidbit along a chain adds one tick of delay. A signal that should stay on is
## sent again every tick.

## Input index for the player activating the machine (Q).
const ACTIVATE := -1
## How long launched blocks pass through whatever is holding the machine.
const LAUNCH_GRACE_TIME := 0.2

var design: MachineDesign
## Node whose local space is the machine's space (see MachineDesign.cell_position).
var host: MachineView
var world: BlockWorld
## The body carrying the machine: the player, or the machine's own body when placed.
var holder: PhysicsBody2D
## What the machine's own grapples must not hook: the holder, plus a held machine's hitbox.
var self_colliders: Array[RID] = []
## Ticks this machine has run.
var tick_count := 0
## Runtime state of tidbits that need it (cell -> anything), owned by their TidbitType.
var states: Dictionary[Vector2i, Variant] = {}

# Inputs to handle next tick, as Vector3i(cell.x, cell.y, input). Duplicates merge.
var _inputs: Dictionary[Vector3i, bool] = {}
var _grapples: Dictionary[Vector2i, GrappleHook] = {}


func _init(p_design: MachineDesign, p_host: MachineView, p_world: BlockWorld, p_holder: PhysicsBody2D) -> void:
	design = p_design
	host = p_host
	world = p_world
	holder = p_holder
	if holder:
		self_colliders.append(holder.get_rid())


## False once the machine is unequipped, picked up, or otherwise out of the world.
func is_running() -> bool:
	return is_instance_valid(host) and host.is_inside_tree() and host.machine == self


func activate() -> void:
	for cell in design.tidbits:
		_inputs[Vector3i(cell.x, cell.y, ACTIVATE)] = true


func tick() -> void:
	tick_count += 1
	var inputs := _inputs
	_inputs = {}
	for input in inputs:
		var cell := Vector2i(input.x, input.y)
		var type := design.get_tidbit(cell)
		if type:
			type.on_input(self, cell, input.z)
	for cell in design.tidbits:
		design.tidbits[cell].on_tick(self, cell)


## Pulses everything wired to a tidbit's port. They see it next tick.
func send(cell: Vector2i, port: int) -> void:
	for other in design.linked(MachineDesign.Link.WIRE, Vector3i(cell.x, cell.y, port)):
		_inputs[other] = true


## Global point on the machine's edge in front of a cell, facing `direction` (machine
## space), pushed out by `gap` pixels.
func muzzle(cell: Vector2i, direction: Vector2i, gap := 0.0) -> Vector2:
	var reach := (design.cells_to_edge(cell, direction) + 0.5) * MachineDesign.TIDBIT_PIXELS + gap
	return host.to_global(MachineDesign.cell_position(cell) + Vector2(direction) * reach)


## A direction in machine space, in global space.
func aim(direction: Vector2i) -> Vector2:
	return host.global_transform.basis_xform(Vector2(direction)).normalized()


## Fires a block out of the machine's edge from a cell, in a direction in machine space.
func launch_block(cell: Vector2i, direction: Vector2i, block_id: int, speed: float) -> void:
	var exit := muzzle(cell, direction, BlockGrid.CELL_SIZE * 0.5 + 1.0)
	var heading := aim(direction)
	var blocks: Dictionary[Vector2i, int] = {Vector2i.ZERO: block_id}
	var half_block := Vector2.ONE * BlockGrid.CELL_SIZE * 0.5
	var body := world.spawn_body(blocks, Transform2D(heading.angle(), exit) * Transform2D(0.0, -half_block))
	body.linear_velocity = heading * speed + _holder_velocity()

	if holder:
		body.add_collision_exception_with(holder)
		var held_by := holder
		world.get_tree().create_timer(LAUNCH_GRACE_TIME).timeout.connect(func() -> void:
			if is_instance_valid(body) and is_instance_valid(held_by):
				body.remove_collision_exception_with(held_by))


## Keeps a cell's grapple going for this tick, firing one if none is out. The grapple
## lets go of whatever it holds once a tick passes without this being called.
func hold_grapple(cell: Vector2i, direction: Vector2i, max_length: float) -> void:
	if _grapples.has(cell):
		_grapples[cell].last_signal_tick = tick_count
		return
	var hook := GrappleHook.new(self, cell, direction, max_length)
	hook.last_signal_tick = tick_count
	_grapples[cell] = hook
	hook.tree_exited.connect(func() -> void: _grapples.erase(cell))
	world.add_child(hook)


func _holder_velocity() -> Vector2:
	if holder is CharacterBody2D:
		return holder.velocity
	if holder is RigidBody2D:
		return holder.linear_velocity
	return Vector2.ZERO
