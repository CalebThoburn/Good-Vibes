class_name Creature
extends CharacterBody2D
## A living creature, grown from its species' body plan and a seed: every part is
## rolled from the seed, so a creature comes back the same when loaded. Its brain sets
## which way it walks and where its head reaches; its parts do the rest (legs step,
## the stomach digests). Moving costs energy, which comes from what it eats. With none
## left it can only shuffle along slowly and loses health, and with no health left it
## dies.
##
## The creature's origin is the ground under its middle; its collision box covers the
## body and legs. It hops up one-block steps and won't walk off drops it can't take.

const GROUP := &"creatures"
## Seconds a body lies before it's gone.
const DEAD_TIME := 30.0
## Art is only redrawn this close to the camera, px.
const ACTIVE_REACH := 600.0
## Leg tucked into the body, as a share of its length.
const LEG_TUCK := 0.12
## Share of its speed it can still manage with no energy left.
const EXHAUSTED_PACE := 0.35
## Seconds of trying to walk without getting anywhere before it counts as blocked.
const STALL_TIME := 1.0

var species: CreatureSpecies
var world: BlockWorld
var seed_value := 0
var parts: Array[BodyPart] = []
var brain: CreatureBrain
## 1 facing right, -1 facing left.
var facing := 1
var energy := 0.0
var health := 0.0
var dead := false
## Set by the brain: which way to walk (-1 to 1, 0 to stand).
var walk := 0.0
## Set by the brain: which way to face while walking (1 or -1), so it can back up. 0
## faces the way it walks.
var face := 0
## Set by the brain: whether it'll take drops up to species.desperate_drop.
var desperate := false
## Set when a walk was stopped by a wall it can't hop, a drop it won't take, or
## anything else that keeps it from getting anywhere.
var blocked := false
## How high the middle of the body rides above the ground.
var ride_height := 0.0
var box_size := Vector2.ZERO

var _art: CreatureArt
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _dead_time := 0.0
var _stalled := 0.0


func setup(p_species: CreatureSpecies, p_world: BlockWorld, p_seed: int) -> void:
	species = p_species
	world = p_world
	seed_value = p_seed
	energy = species.start_energy
	health = species.max_health
	add_to_group(GROUP)
	collision_layer = BlockWorld.CREATURE_LAYER
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.MACHINE_LAYER
	floor_snap_length = 4.0
	_grow()
	_art = CreatureArt.new(self)
	_art.z_index = -2 # With the player, behind the grass.
	add_child(_art)
	if species.brain:
		brain = species.brain.new(self)


## The first part with a name (the near one, for paired parts).
func part(part_name: StringName) -> BodyPart:
	for candidate in parts:
		if candidate.name == part_name:
			return candidate
	return null


## The first part of a kind (a BodyPart script).
func part_of(kind: Script) -> BodyPart:
	for candidate in parts:
		if candidate.get_script() == kind:
			return candidate
	return null


func flora() -> Flora:
	return world.flora


func spend(amount: float) -> void:
	energy = maxf(energy - amount, 0.0)


func gain(amount: float) -> void:
	energy = minf(energy + amount, species.max_energy)


## Whether a leg may lift now: no leg in the other half of the gait is in the air (legs
## step in diagonal pairs).
func may_step(leg: LegPart) -> bool:
	if dead:
		return false
	for other in parts:
		if other is LegPart and other.stepping and other.gait_group != leg.gait_group:
			return false
	return true


## The height of the ground (or anything standing on it) under a point, within reach
## below it, or NAN if there's nothing.
func ground_below(point: Vector2, reach: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2.DOWN * reach,
			BlockWorld.BLOCK_LAYER | BlockWorld.MACHINE_LAYER)
	query.hit_from_inside = true # From inside a wall, the ground is right there.
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else NAN


## Drops a block of dung behind it. Returns whether there was room.
func drop_dung() -> bool:
	var size := Vector2.ONE * BlockGrid.CELL_SIZE
	var center := global_position + Vector2(-facing * (box_size.x * 0.5 + size.x * 0.5 + 1.0), -size.y * 0.5 - 1.0)
	if not world.is_area_free(center, size):
		return false
	var dung: Dictionary[Vector2i, int] = {Vector2i.ZERO: Blocks.id_of(&"dung")}
	var body := world.spawn_body(dung, Transform2D(0.0, center - size * 0.5))
	body.linear_velocity = Vector2(-facing * 20.0, 0.0)
	return true


func die() -> void:
	dead = true
	walk = 0.0
	face = 0
	brain = null


func to_data() -> Dictionary:
	var saved := {}
	for i in parts.size():
		var state := parts[i].to_data()
		if not state.is_empty():
			saved[i] = state
	return {species = species.id, seed = seed_value, position = global_position, velocity = velocity,
			facing = facing, energy = energy, health = health, dead = dead, dead_time = _dead_time, parts = saved}


func load_data(data: Dictionary) -> void:
	global_position = data.position
	velocity = data.velocity
	facing = data.facing
	energy = data.energy
	health = data.health
	_dead_time = data.dead_time
	if data.dead:
		die()
	for i: int in data.parts:
		if i < parts.size():
			parts[i].load_data(data.parts[i])


func _physics_process(delta: float) -> void:
	if global_position.y > world.kill_y():
		queue_free()
		return
	if dead:
		_dead_time += delta
		_art.modulate.a = clampf((DEAD_TIME - _dead_time) / 3.0, 0.0, 1.0)
		if _dead_time >= DEAD_TIME:
			queue_free()
			return
	else:
		if brain:
			brain.think(delta)
		spend(species.metabolism * delta)
		if energy <= 0.0:
			health -= species.starve_rate * delta
			if health <= 0.0:
				die()
		elif energy > species.max_energy * 0.5:
			health = minf(health + species.heal_rate * delta, species.max_health)
	_move(delta)
	for body_part in parts:
		body_part.update(delta)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.get_screen_center_position().distance_to(global_position) < ACTIVE_REACH:
		_art.queue_redraw()


func _move(delta: float) -> void:
	blocked = false
	var direction := 0.0 if dead else signf(walk)
	if direction != 0.0 and is_on_floor():
		facing = face if face != 0 else int(direction)
		if _drop_ahead(direction) > (species.desperate_drop if desperate else species.max_drop):
			direction = 0.0
			blocked = true
		elif is_on_wall() and get_wall_normal().x * direction < 0.0:
			if _can_hop(direction):
				velocity.y = -species.jump_speed
				spend(species.jump_cost)
			else:
				blocked = true
	var target := direction * absf(walk) * species.walk_speed * (1.0 if energy > 0.0 else EXHAUSTED_PACE)
	if is_on_floor() or dead:
		velocity.x = move_toward(velocity.x, target, species.acceleration * delta)
	elif direction != 0.0: # Keep going over the step mid-hop.
		velocity.x = target
	velocity.y += _gravity * delta
	move_and_slide()
	# Wedged somehow (against a corner, under a fallen block): give up going that way.
	var stuck := direction != 0.0 and get_real_velocity().x * direction < 1.0
	_stalled = _stalled + delta if stuck else 0.0
	if _stalled > STALL_TIME:
		blocked = true


## How far the ground drops just ahead, px (INF for further than it can see; 0 or less
## for a step or wall, which hopping deals with).
func _drop_ahead(direction: float) -> float:
	var ahead := global_position + Vector2(direction * (box_size.x * 0.5 + 4.0), -4.0)
	var ground := ground_below(ahead, BlockGrid.CELL_SIZE * 6.0)
	return INF if is_nan(ground) else ground - global_position.y


## Whether the way ahead is clear a block up, so a hop would get it over.
func _can_hop(direction: float) -> bool:
	var up := global_transform.translated(Vector2(0.0, -BlockGrid.CELL_SIZE - 2.0))
	return not test_move(global_transform, Vector2(0.0, -BlockGrid.CELL_SIZE - 2.0)) \
			and not test_move(up, Vector2(direction * 4.0, 0.0))


## Rolls every part of the body plan from the seed and connects them, then sizes the
## collision box to the body and legs.
func _grow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for template in species.body_plan:
		var sides: Array[int] = [BodyPart.Side.MIDDLE]
		if template.paired:
			sides = [BodyPart.Side.NEAR, BodyPart.Side.FAR]
		for side in sides:
			var grown: BodyPart = template.duplicate()
			grown.creature = self
			grown.side = side
			grown.parent = _parent_for(grown)
			if not grown.fits(grown.parent):
				push_warning("%s: %s can't hang off %s" % [species.id, grown.name, grown.parent_name])
				continue
			grown.roll(rng)
			if grown.parent:
				grown.parent.children.append(grown)
			parts.append(grown)
	var torso := part_of(TorsoPart) as TorsoPart
	var leg := part_of(LegPart) as LegPart
	var body_size := torso.size if torso else Vector2(8.0, 8.0)
	ride_height = body_size.y * 0.5 + (leg.length * (1.0 - LEG_TUCK) if leg else 0.0)
	box_size = Vector2(body_size.x * 0.75, ride_height + body_size.y * 0.35)
	var shape := RectangleShape2D.new()
	shape.size = box_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -box_size.y * 0.5)
	add_child(collision)
	for grown in parts:
		grown.setup()


## The part a new part hangs off: one by its parent name on the same side if there is
## one (for parts hanging off paired parts), otherwise the first by that name.
func _parent_for(child: BodyPart) -> BodyPart:
	if child.parent_name.is_empty():
		return null
	var found: BodyPart = null
	for candidate in parts:
		if candidate.name == child.parent_name:
			if candidate.side == child.side:
				return candidate
			if found == null:
				found = candidate
	return found
