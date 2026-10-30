class_name AirNozzle
extends Node2D
## Air moving through a tidbit's nozzle while it keeps getting a signal: suction for a
## vacuum, a blast for an empty launcher.
##
## It acts on the nearest thing ahead and on the machine with the same force, so mass
## decides who moves: suction pulls them together, blowing pushes them apart. Flush
## against something the force triples, so a blower makes a strong jet against a wall.
## Blowing also always thrusts the machine back, even with nothing ahead, so launchers
## can drive a machine along.
## Suction also grips what it's flush against, so it can cling to walls, and swallows
## loose single blocks, machines and cut pieces of tree (as wood) that reach the nozzle
## into the vacuum's storage.

enum Mode { SUCK, BLOW }

const RANGE := 4.0 * BlockGrid.CELL_SIZE
## Force at the nozzle (mass * px/s²), falling off to nothing at RANGE.
const AIR_FORCE := 15000.0
## The least a blower pushes its machine back with, whatever is ahead of it.
const THRUST := 20000.0
const FLUSH_DISTANCE := 3.0
const FLUSH_FORCE_MULTIPLIER := 3.0
## While flush, the share of motion between the machine and what it's stuck to that is
## cancelled each physics frame.
const FLUSH_GRIP := 0.9
const SWALLOW_DISTANCE := 4.0
## The nozzle feels for things with three rays this far apart.
const RAY_SPREAD := 5.0
const AIR_COLOR := Color(1, 1, 1, 0.35)

var machine: Machine
var cell: Vector2i
var direction: Vector2i
var mode: Mode
## The machine tick the nozzle was last signalled on.
var last_signal_tick := 0

var _hit_distance := RANGE


func _init(p_machine: Machine, p_cell: Vector2i, p_direction: Vector2i, p_mode: Mode) -> void:
	machine = p_machine
	cell = p_cell
	direction = p_direction
	mode = p_mode
	last_signal_tick = machine.tick_count
	top_level = true
	z_index = 1
	visibility_layer = SunShade.NO_SHADE_LAYER


func _physics_process(delta: float) -> void:
	if not machine.is_running() or machine.tick_count > last_signal_tick:
		queue_free()
		return
	_push_air(delta)
	queue_redraw()


func _draw() -> void:
	# Streaks of air flowing into (or out of) the nozzle.
	var nozzle := machine.muzzle(cell, direction)
	var aim := machine.aim(direction)
	var side := aim.orthogonal()
	var flow := fmod(Time.get_ticks_msec() / 1000.0 * 3.0, 1.0)
	if mode == Mode.SUCK:
		flow = 1.0 - flow
	for i in 3:
		var along := fposmod(flow - i / 3.0, 1.0) * _hit_distance
		var spread := side * (i - 1) * RAY_SPREAD * (1.0 + along / RANGE)
		var start := nozzle + aim * along + spread
		draw_line(start, start - aim * 4.0 - spread * 0.2, AIR_COLOR, 1.0)


func _push_air(delta: float) -> void:
	var nozzle := machine.muzzle(cell, direction)
	var aim := machine.aim(direction)
	var hit := _nearest_hit(aim)
	var sucking := mode == Mode.SUCK
	var body := MachinePhysics.body_of(hit.collider) if not hit.is_empty() else null
	_hit_distance = RANGE
	var force := 0.0
	var flush := false
	if body:
		var distance := maxf((hit.position - nozzle).dot(aim), 0.0)
		_hit_distance = distance
		if sucking and distance <= SWALLOW_DISTANCE and _swallow(body):
			return
		force = AIR_FORCE * pow(1.0 - distance / RANGE, 2.0)
		flush = distance <= FLUSH_DISTANCE
		if flush:
			force *= FLUSH_FORCE_MULTIPLIER
		# Toward each other when sucking, apart when blowing.
		MachinePhysics.apply_impulse(body, aim * force * delta * (-1.0 if sucking else 1.0), hit.position)
	if machine.holder:
		if sucking:
			MachinePhysics.apply_impulse(machine.holder, aim * force * delta, nozzle)
		else: # Thrust goes through the machine's middle, so it drives it along without tipping it.
			MachinePhysics.apply_central_impulse(machine.holder, -aim * maxf(force, THRUST) * delta)
	if sucking and flush:
		_grip(body, hit.position, nozzle)


## The nearest thing in front of the nozzle, as an intersect_ray result, or {}.
func _nearest_hit(aim: Vector2) -> Dictionary:
	# Rays start inside the machine so something already touching the nozzle still counts.
	var origin := machine.host.to_global(MachineDesign.cell_position(cell))
	var nozzle := machine.muzzle(cell, direction)
	var space := get_world_2d().direct_space_state
	var nearest := {}
	var nearest_distance := INF
	for i in 3:
		var offset := aim.orthogonal() * (i - 1) * RAY_SPREAD
		var query := PhysicsRayQueryParameters2D.create(origin + offset, nozzle + offset + aim * RANGE,
				BlockWorld.BLOCK_LAYER | BlockWorld.PLAYER_LAYER | BlockWorld.MACHINE_LAYER, machine.self_colliders)
		query.collide_with_areas = true # Held machines are areas.
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and (hit.position - origin).dot(aim) < nearest_distance:
			nearest = hit
			nearest_distance = (hit.position - origin).dot(aim)
	return nearest


## Takes a loose single block, a placed machine, or a cut piece of tree (as wood) into
## storage. Returns whether it did.
func _swallow(body: PhysicsBody2D) -> bool:
	if body is PlantDebris:
		var taken := 0
		for i in body.wood(): # Whatever doesn't fit is lost with the rest of it.
			if not machine.give(cell, &"wood"):
				break
			taken += 1
		if taken == 0:
			return false
		body.queue_free()
		return true
	var thing: Variant = null
	if body is BlockBody and body.grid.cells.size() == 1:
		thing = Blocks.get_type(body.grid.cells.values()[0]).id
	elif body is MachineBody:
		thing = body.view.machine.design
	if thing == null or not machine.give(cell, thing):
		return false
	body.queue_free()
	return true


## Cancels most motion between the machine and what the nozzle is stuck to.
func _grip(body: PhysicsBody2D, point: Vector2, nozzle: Vector2) -> void:
	var holder := machine.holder
	if holder == null:
		return
	var inverse_sum := MachinePhysics.inverse_mass(holder) + MachinePhysics.inverse_mass(body)
	if inverse_sum == 0.0:
		return
	var relative := MachinePhysics.velocity_of(holder) - MachinePhysics.velocity_of(body)
	var impulse := -relative * FLUSH_GRIP / inverse_sum
	MachinePhysics.apply_impulse(holder, impulse, nozzle)
	MachinePhysics.apply_impulse(body, -impulse, point)
