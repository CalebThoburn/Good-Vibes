class_name Machine
extends RefCounted
## A running machine. Every input a tidbit receives is handled on the next machine tick,
## so each tidbit along a chain adds one tick of delay. A signal that should stay on is
## sent again every tick.

## Keys the player activates machines with (see triggers). The input a tidbit gets for
## channel i is activation_input(i).
enum Channel { Q, E, SPACE }
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
var _effects: Dictionary[Vector2i, Node] = {}


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


## The input index tidbits receive when the player presses a channel's key. Negative so
## it never clashes with a port index.
static func activation_input(channel: Channel) -> int:
	return -1 - channel


func activate(channel: Channel) -> void:
	for cell in design.tidbits:
		_inputs[Vector3i(cell.x, cell.y, activation_input(channel))] = true


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
	for cell in design.stored_creatures.keys(): # Creatures inside go on living.
		for creature: StoredCreature in design.creatures_in(cell).duplicate():
			creature.live(design, cell, 1.0 / MachineClock.TICKS_PER_SECOND)


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
	_launch(world.spawn_body(blocks, Transform2D(heading.angle(), exit) * Transform2D(0.0, -half_block)), heading, speed)


## Fires a whole machine out of the machine's edge, placed in the world.
func launch_machine(cell: Vector2i, direction: Vector2i, launched: MachineDesign, speed: float) -> void:
	var half_machine := MachineDesign.SIZE * MachineDesign.TIDBIT_PIXELS * 0.5
	var heading := aim(direction)
	var body := world.spawn_machine(launched, muzzle(cell, direction, half_machine + 1.0))
	body.rotation = heading.angle()
	_launch(body, heading, speed)


## Lets a live creature out of the machine's edge, flying out the way it's fired.
func launch_creature(cell: Vector2i, direction: Vector2i, creature: StoredCreature, speed: float) -> void:
	var heading := aim(direction)
	creature.release(world, muzzle(cell, direction, 4.0), heading * speed * 0.5 + MachinePhysics.velocity_of(holder))


## Fires a loose item (one that isn't a block) out of the machine's edge.
func launch_item(cell: Vector2i, direction: Vector2i, item_id: StringName, speed: float) -> void:
	var heading := aim(direction)
	LooseItem.drop(world, item_id, 1, muzzle(cell, direction, 3.0), heading * speed + MachinePhysics.velocity_of(holder))


## Puts one thing (an item id, a MachineDesign or a StoredCreature) into a tidbit: into its storage if it
## holds that kind of thing, otherwise attached as an upgrade if it takes that. Returns
## whether it fit.
func give(cell: Vector2i, thing: Variant) -> bool:
	var type := design.get_tidbit(cell)
	if type == null:
		return false
	if design.store_room(cell) > 0 and type.can_store(thing):
		design.store(cell, thing)
		return true
	if thing is StringName and design.item_room(cell, thing) > 0:
		design.add_item(cell, thing, 1)
		return true
	return false


## Takes one thing out of a tidbit (stored first, then attached upgrades), or null.
func take(cell: Vector2i) -> Variant:
	var stored := design.stored_things(cell)
	if not stored.is_empty():
		design.unstore(cell, stored[0])
		return stored[0]
	var attached := design.items_on(cell)
	if attached.is_empty():
		return null
	var item_id: StringName = attached.keys()[0]
	design.remove_item(cell, item_id, 1)
	return item_id


## Moves one stored thing out through a tidbit's valve, into the first tidbit piped to it
## that takes it.
func pipe_out(cell: Vector2i, valve: int) -> void:
	var targets := design.linked(MachineDesign.Link.PIPE, Vector3i(cell.x, cell.y, valve))
	if targets.is_empty():
		return
	for thing in design.stored_things(cell):
		for target in targets:
			if give(Vector2i(target.x, target.y), thing):
				design.unstore(cell, thing)
				return


## The world effect (a grapple, a vacuum's suction) a tidbit has running, or null.
func get_effect(cell: Vector2i) -> Node:
	return _effects.get(cell)


## Adds a world effect for a tidbit. It's forgotten once it leaves the tree.
func start_effect(cell: Vector2i, effect: Node) -> void:
	_effects[cell] = effect
	effect.tree_exited.connect(func() -> void: _effects.erase(cell))
	world.add_child(effect)


func _launch(body: RigidBody2D, heading: Vector2, speed: float) -> void:
	body.linear_velocity = heading * speed + MachinePhysics.velocity_of(holder)
	if holder:
		body.add_collision_exception_with(holder)
		var held_by := holder
		world.get_tree().create_timer(LAUNCH_GRACE_TIME).timeout.connect(func() -> void:
			if is_instance_valid(body) and is_instance_valid(held_by):
				body.remove_collision_exception_with(held_by))
