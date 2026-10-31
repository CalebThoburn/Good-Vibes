class_name Creature
extends CharacterBody2D
## A living creature, grown from its species' body plan and a seed: every part is
## rolled from the seed, so a creature comes back the same when loaded.
##
## The head runs it: its brain (a Mind, which learns what its actions lead to) sets which
## way the creature walks (or flies) and where the head reaches, and the legs and wings
## carry that out. Sleep heals it and makes the bile its stomach needs. Blood is its energy: the
## stomach turns food into blood, which flows evenly through every attached part, and
## each part pays its upkeep and the cost of what it does out of it. Losing blood is
## losing energy; with none left the creature dies.
##
## Damage (from drills) tears parts off once they've taken enough, along with whatever
## hangs off them. Torn-off parts tumble away as a CreaturePiece and are no longer part
## of the creature. The part they hung from is left with a wound that leaks what it
## holds (blood; food and dung from a belly), slowing as it clots; what leaks out lands
## as loose items. Losing the head (and its brain), the part the body is built on, or
## all its blood kills it, and then it falls apart: every part becomes a loose piece and
## everything it held spills out.
##
## Creatures smaller than a block can be sucked into a machine alive (see StoredCreature).
##
## The creature's origin is the ground under its middle; its collision box covers the
## body and legs. Walkers hop up one-block steps, stop short of walls they can't hop and
## won't walk off drops they can't take. Creatures with wings fly where the brain steers,
## and swimmers (fish) swim, but only in water.

const GROUP := &"creatures"
## Art is only redrawn this close to the camera, px.
const ACTIVE_REACH := 600.0
## Leg tucked into the body, as a share of its length.
const LEG_TUCK := 0.12
## Share of its speed it can still manage with hardly any blood left.
const EXHAUSTED_PACE := 0.35
## Seconds of trying to walk without getting anywhere before it counts as blocked.
const STALL_TIME := 1.0
## How far ahead it looks for walls, px.
const WALL_LOOKAHEAD := 3.0
## Share of a wound's leaking a second later (it clots).
const CLOTTING := 0.985
## Share of a hurt part's blood spilled per point of damage.
const SPILL_PER_DAMAGE := 0.02

var species: CreatureSpecies
var world: BlockWorld
var seed_value := 0
## The parts still attached.
var parts: Array[BodyPart] = []
## 1 facing right, -1 facing left.
var facing := 1
var dead := false
## Set by the brain: which way to walk (-1 to 1, 0 to stand).
var walk := 0.0
## Set by the brain: which way to face while walking (1 or -1), so it can back up. 0
## faces the way it walks.
var face := 0
## Set by the brain of a flier: the velocity it's trying to fly at.
var fly_velocity := Vector2.ZERO
## Set by the brain: whether it'll take drops up to species.desperate_drop.
var desperate := false
## Set by the brain: how brightly glowing parts light up, 0-1.
var glow := 0.0
## Set by the brain while it sleeps: it heals and makes bile (see _rest).
var sleeping := false
## Seconds left of a call it's making (drawn by its head).
var calling := 0.0
## Set when a walk was stopped by a wall it can't hop, a drop it won't take, or
## anything else that keeps it from getting anywhere.
var blocked := false
## How high the middle of the body rides above the ground.
var ride_height := 0.0
var box_size := Vector2.ZERO
## How heavy it is when machines push or pull it (see MachinePhysics).
var mass: float:
	get: return species.mass

var _art: CreatureArt
var _collision := CollisionShape2D.new()
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _stalled := 0.0
# Every part it grew, attached or not, so saves can say which are gone.
var _grown: Array[BodyPart] = []
var _legs_grown := 0
var _wings_grown := 0
# What's leaked out but not yet a whole item, by item id.
var _spilled: Dictionary[StringName, float] = {}
var _drip := 0.0


func setup(p_species: CreatureSpecies, p_world: BlockWorld, p_seed: int) -> void:
	species = p_species
	world = p_world
	seed_value = p_seed
	add_to_group(GROUP)
	collision_layer = BlockWorld.CREATURE_LAYER
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.MACHINE_LAYER
	floor_snap_length = 4.0
	_grow()
	_art = CreatureArt.new(self)
	_art.z_index = -2 # With the player, behind the grass.
	add_child(_art)
	var head := part_of(HeadPart) as HeadPart
	if head and species.brain:
		head.brain = species.brain.new(self)
	if parts.any(func(body_part: BodyPart) -> bool: return body_part is TorsoPart and body_part.glow_color.a > 0.0):
		var light := CreatureGlow.new(self)
		light.name = "Glow"
		add_child(light)


## The first part with a name (the near one, for paired parts).
func part(part_name: StringName) -> BodyPart:
	for candidate in parts:
		if candidate.name == part_name:
			return candidate
	return null


## The first part of a kind (a BodyPart script, or one it extends).
func part_of(kind: Script) -> BodyPart:
	for candidate in parts:
		if is_instance_of(candidate, kind):
			return candidate
	return null


func flora() -> Flora:
	return world.flora


## What's running it: the brain in its head, or null with the head gone (or dead).
func brain() -> CreatureBrain:
	var head := part_of(HeadPart) as HeadPart
	return head.brain if head and not dead else null


## All the blood (its energy) in its attached parts.
func blood() -> float:
	var total := 0.0
	for body_part in parts:
		total += body_part.blood()
	return total


## The blood its attached parts hold when it's full.
func max_blood() -> float:
	var total := 0.0
	for body_part in parts:
		total += body_part.blood_capacity
	return total


## Every part it grew, attached or not.
func all_grown() -> Array[BodyPart]:
	return _grown


## Whether it steers freely through the air or water (fliers and swimmers) rather than
## walking. A flier whose wings are gone just falls.
func flies() -> bool:
	return _wings_grown > 0 or species.swims


## Whether it lives in water.
func swims() -> bool:
	return species.swims


## Whether its whole body (every part as drawn, not just its collision box) is smaller
## than a block, so a vacuum can take it in whole.
func small() -> bool:
	if parts.is_empty():
		return false
	var bounds := parts[0].extent()
	for body_part in parts:
		bounds = bounds.merge(body_part.extent())
	return maxf(bounds.size.x, bounds.size.y) < BlockGrid.CELL_SIZE


## Pushed like a rigid body of its mass (by machines' air).
func apply_impulse(impulse: Vector2) -> void:
	velocity += impulse / mass


## The attached part a global point lands on (the frontmost), or null.
func part_at(point: Vector2) -> BodyPart:
	var found: BodyPart = null
	for body_part in parts:
		if body_part.hit_distance(point) <= 0.5 and (found == null or body_part.layer() > found.layer()):
			found = body_part
	return found


## Hurts a part. Some of its blood spills, and once it's taken its toughness it tears
## off (or if it's the part the body's built on, the creature dies).
func hurt(body_part: BodyPart, amount: float, at: Vector2) -> void:
	if not body_part.attached or dead:
		return
	body_part.damage += amount
	var spilled := body_part.blood() * SPILL_PER_DAMAGE * amount
	body_part.spend(spilled)
	spill(&"blood", spilled, at)
	Blood.spray(self, at, 2, (at - global_position).normalized() + Vector2.UP)
	if body_part.damage >= body_part.toughness:
		if body_part.parent == null:
			die()
		else:
			tear_off(body_part)


## Tears a part off, with everything hanging off it, and leaves it tumbling loose. The
## part it hung from is left with a wound.
func tear_off(body_part: BodyPart, loose := true) -> void:
	var gone := _attached_below(body_part)
	for lost in gone:
		lost.attached = false
		parts.erase(lost)
	var from := body_part.parent
	from.children.erase(body_part)
	from.wound += body_part.bleeding
	from.wound_socket = body_part.socket
	if not loose:
		return
	var center := _middle_of(body_part)
	Blood.spray(self, center, 16, Vector2.UP, 90.0)
	_add_piece(gone, center)
	if body_part is HeadPart:
		die() # The brain went with it.


## Spills some of what it held at a global point, to land as loose items once there's
## a whole one.
func spill(item_id: StringName, amount: float, at: Vector2) -> void:
	if amount <= 0.0:
		return
	var total: float = _spilled.get(item_id, 0.0) + amount
	var whole := floori(total)
	_spilled[item_id] = total - whole
	LooseItem.drop(world, item_id, whole, at)


## Dies and falls apart: everything it held spills out, and every part tumbles loose on
## its own. The creature itself goes once the last piece has.
func die() -> void:
	if dead:
		return
	dead = true
	walk = 0.0
	face = 0
	glow = 0.0
	var head := part_of(HeadPart) as HeadPart
	if head:
		head.brain = null
	for body_part in parts:
		for item_id in body_part.contents:
			spill(item_id, body_part.contents[item_id], _middle_of(body_part))
		body_part.contents.clear()
	for item_id in _spilled: # The odd bits left over, rounded either way.
		if randf() < _spilled[item_id]:
			LooseItem.drop(world, item_id, 1, global_position + Vector2(0.0, -ride_height))
	_spilled.clear()
	Blood.spray(self, global_position + Vector2(0.0, -ride_height), 20, Vector2.UP, 70.0)
	for body_part in parts:
		body_part.attached = false
		_add_piece([body_part], _middle_of(body_part))
	parts.clear()
	collision_layer = 0
	_art.hide()


func to_data() -> Dictionary:
	var saved := {}
	for i in _grown.size():
		var grown := _grown[i]
		saved[i] = {state = grown.to_data(), damage = grown.damage, attached = grown.attached,
				contents = grown.contents.duplicate(), wound = grown.wound}
	var mind := brain()
	return {species = species.id, seed = seed_value, position = global_position, velocity = velocity,
			facing = facing, parts = saved, mind = mind.to_data() if mind and mind.has_method(&"to_data") else {}}


func load_data(data: Dictionary) -> void:
	global_position = data.position
	velocity = data.velocity
	facing = data.facing
	for i: int in data.parts:
		if i >= _grown.size():
			continue
		var grown := _grown[i]
		var saved: Dictionary = data.parts[i]
		grown.load_data(saved.state)
		grown.damage = saved.damage
		grown.contents.assign(saved.contents)
		if not saved.attached and grown.attached:
			tear_off(grown, false) # Already lost; the piece is long gone.
	for i: int in data.parts: # After tearing, which adds to wounds.
		if i < _grown.size():
			_grown[i].wound = data.parts[i].wound
	var mind := brain()
	if mind and mind.has_method(&"load_data") and not data.get("mind", {}).is_empty():
		mind.load_data(data.mind)


func _physics_process(delta: float) -> void:
	if dead:
		if not get_children().any(func(child: Node) -> bool: return child is CreaturePiece):
			queue_free()
		return
	if global_position.y > world.kill_y():
		queue_free()
		return
	_live(delta)
	if dead:
		return
	if species.swims:
		_swim(delta)
	elif _wings_grown > 0:
		_fly(delta)
	else:
		_move(delta)
	for body_part in parts:
		body_part.update(delta)
	var camera := get_viewport().get_camera_2d()
	if camera and camera.get_screen_center_position().distance_to(global_position) < ACTIVE_REACH:
		_art.queue_redraw()


## Thinking, upkeep, blood flow and wounds.
func _live(delta: float) -> void:
	var mind := brain()
	if mind:
		mind.think(delta)
	else: # Nothing to tell the body what to do.
		walk = 0.0
		face = 0
		fly_velocity = Vector2.ZERO
	for body_part in parts:
		body_part.spend(body_part.upkeep * delta)
	calling = maxf(calling - delta, 0.0)
	if sleeping:
		_rest(delta)
	_leak(delta)
	_circulate()
	if blood() <= 0.0:
		die()


## Asleep, the body makes bile for the stomach and heals its damage, paying in blood,
## and its wounds close faster.
func _rest(delta: float) -> void:
	var belly := part_of(StomachPart) as StomachPart
	if belly:
		belly.contents[&"bile"] = minf(belly.bile() + species.bile_rate * delta, belly.bile_capacity)
	for body_part in parts:
		var healed := minf(body_part.damage, species.heal_rate * delta)
		if healed > 0.0 and body_part.spend(healed * species.heal_cost):
			body_part.damage -= healed
		body_part.wound *= pow(CLOTTING, delta * 2.0)


## Spreads the blood evenly through every attached part, by how much each holds.
func _circulate() -> void:
	var fill := blood() / maxf(max_blood(), 0.0001)
	for body_part in parts:
		body_part.contents[&"blood"] = body_part.blood_capacity * fill


## Wounds leak a share of everything their part holds, and clot.
func _leak(delta: float) -> void:
	for body_part in parts:
		if body_part.wound <= 0.0:
			continue
		var at := body_part.attach_point(body_part.wound_socket, BodyPart.Side.MIDDLE)
		for item_id in body_part.contents.keys():
			var leaked: float = body_part.contents[item_id] * minf(body_part.wound * delta, 1.0)
			body_part.contents[item_id] -= leaked
			spill(item_id, leaked, at)
		body_part.wound *= pow(CLOTTING, delta)
		if body_part.wound < 0.0005:
			body_part.wound = 0.0
		_drip -= delta
		if _drip <= 0.0:
			_drip = clampf(0.01 / maxf(body_part.wound, 0.0001), 0.05, 1.0)
			Blood.spray(self, at, 1, Vector2.DOWN, 15.0)


## Whether a leg may lift now: it's attached, the head is there to tell it to, and no
## leg in the other half of the gait is in the air (legs step in diagonal pairs).
func may_step(leg: LegPart) -> bool:
	if dead or not leg.attached or brain() == null:
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


func _move(delta: float) -> void:
	blocked = false
	var pace := _leg_pace()
	var direction := 0.0 if pace <= 0.0 else signf(walk)
	if direction != 0.0 and is_on_floor():
		facing = face if face != 0 else int(direction)
		if _drop_ahead(direction) > (species.desperate_drop if desperate else species.max_drop):
			direction = 0.0
			blocked = true
		elif test_move(global_transform, Vector2(direction * WALL_LOOKAHEAD, -2.0)):
			# A wall just ahead: hop it if it's a step, otherwise stop short of it.
			if _can_hop(direction) and pace >= 0.5:
				velocity.y = -species.jump_speed
				for leg in parts:
					if leg is LegPart:
						leg.spend(species.jump_cost)
			else:
				direction = 0.0
				blocked = true
	var target := direction * absf(walk) * species.walk_speed * pace
	if is_on_floor():
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


## Flying: the wings carry it toward the velocity the brain steers for, as strongly as
## the share of its wings still beating. With none, it falls.
func _fly(delta: float) -> void:
	var beating := 0
	for wing in parts:
		if wing is WingPart and wing.beating():
			beating += 1
	var lift := float(beating) / _wings_grown
	velocity = velocity.move_toward(fly_velocity * lift, species.acceleration * delta)
	velocity.y += _gravity * delta * (1.0 - lift)
	if absf(fly_velocity.x) > 2.0:
		facing = int(signf(fly_velocity.x))
	move_and_slide()


## Swimming: in water it moves where the brain steers, staying under the surface; out
## of it, it falls, flops about and slowly suffocates.
func _swim(delta: float) -> void:
	var liquids := world.liquids
	var middle := global_position + Vector2(0.0, -ride_height)
	if liquids.is_wet(middle):
		var wanted := fly_velocity
		if wanted.y < 0.0 and not liquids.is_wet(middle + Vector2(0.0, -box_size.y - 2.0)):
			wanted.y = 0.0 # The surface.
		velocity = velocity.move_toward(wanted, species.acceleration * delta)
	else:
		velocity.y += _gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, species.acceleration * delta)
		if is_on_floor() and randf() < delta * 1.5: # Flops.
			velocity = Vector2(randf_range(-40.0, 40.0), -80.0)
		for body_part in parts:
			body_part.spend(species.suffocation * body_part.blood_capacity * delta)
	if absf(fly_velocity.x) > 2.0:
		facing = int(signf(fly_velocity.x))
	move_and_slide()


## How well its legs can carry it, from 0 to 1: each leg it grew counts for its share
## while it's attached, a smaller one while it's out of blood, and none once it's gone.
func _leg_pace() -> float:
	if _legs_grown == 0:
		return 0.0
	var pace := 0.0
	for leg in parts:
		if leg is LegPart:
			pace += 1.0 if leg.has_energy() else EXHAUSTED_PACE
	return pace / _legs_grown


## A part and every attached part that hangs off it, parents first.
func _attached_below(top: BodyPart) -> Array[BodyPart]:
	var found: Array[BodyPart] = [top]
	var i := 0
	while i < found.size():
		for child in found[i].children:
			if child.attached:
				found.append(child)
		i += 1
	return found


## Parts tumbling loose, as a piece. Pieces belong to the creature (which they draw
## through) but move on their own.
func _add_piece(loose: Array[BodyPart], center: Vector2) -> void:
	var piece := CreaturePiece.new(loose, center, velocity, self)
	piece.top_level = true
	add_child(piece)


## Roughly where a part is.
func _middle_of(body_part: BodyPart) -> Vector2:
	if body_part is TorsoPart:
		return body_part.center
	if body_part is LegPart:
		return body_part.knee
	if body_part is HeadPart:
		return (body_part.base + body_part.center) * 0.5
	return body_part.extent().get_center()


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


## Rolls every part of the body plan from the seed and connects them, fills it with
## blood, then sizes the collision box to the body and legs.
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
			grown.contents[&"blood"] = grown.blood_capacity * species.start_blood
			parts.append(grown)
			if grown is LegPart:
				_legs_grown += 1
			elif grown is WingPart:
				_wings_grown += 1
	_grown = parts.duplicate()
	# The body's length runs over every segment hanging off the middle one.
	var body: TorsoPart = parts[0] if not parts.is_empty() and parts[0] is TorsoPart else null
	var body_size := body.size if body else Vector2(8.0, 8.0)
	var front := body_size.x * 0.5
	var back := body_size.x * 0.5
	for segment in parts:
		if segment is TorsoPart and segment.parent == body and body:
			var offset: float = segment.offset_from(body).x
			front = maxf(front, offset + segment.size.x * 0.5)
			back = maxf(back, -offset + segment.size.x * 0.5)
	var leg := part_of(LegPart) as LegPart
	ride_height = body_size.y * 0.5 + (leg.length * (1.0 - LEG_TUCK) if leg else 0.0)
	box_size = Vector2((front + back) * 0.75, ride_height + body_size.y * 0.35)
	var shape := RectangleShape2D.new()
	shape.size = box_size
	_collision.shape = shape
	_collision.position = Vector2(0.0, -box_size.y * 0.5)
	add_child(_collision)
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
