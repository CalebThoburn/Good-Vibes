class_name Mind
extends CreatureBrain
## A creature's mind, which learns what its actions lead to and picks what to do by it.
##
## It notices the nearest thing of each kind around it (Thing: plants, blocks, creatures,
## items, machines, pools of water or blood, the player), and the circumstances:
## what's around, what it did last, what it's heard, whether it's night. For every action
## its species has (CreatureSpecies.actions) and everything that action can be done to,
## it asks its OutcomeModel what's likely to happen to its needs, and weighs that by how
## much it needs each right now: hunger, energy (blood), health, and rest (the bile only
## sleep makes, which the stomach needs to turn food into blood). Curiosity adds to
## anything it knows little about, so it tries new things, things on new targets, and
## old things in new circumstances. Once an action's done, it watches a moment longer,
## then learns from how its needs actually changed.
##
## That's how it can be trained: if, say, it gets hurt every time it eats grass without a
## stone block nearby, it learns to eat only when one is there.
##
## Some things are reflexes rather than choices: it runs from whatever's nearest right
## after it's hurt, and from anything it's learned means harm once it comes close; glowing
## creatures flash in the dark.

## Seconds it watches what comes of an action before learning from it.
const SETTLE_TIME := 1.0
## Run from anything this close that it's learned to fear this much.
const DANGER_REACH := 70.0
const DANGER_FEAR := 0.02
## Run from whatever's nearest when hurt this recently, seconds.
const HURT_FLEE_TIME := 1.5
## Seconds it remembers hearing a call.
const HEAR_TIME := 6.0
## Random wobble in how it weighs options, so it isn't wholly predictable.
const WHIM := 0.02
## How much each need counts (health counts more, the more hurt it is).
const FOOD_WEIGHT := 1.0
const ENERGY_WEIGHT := 1.0
const HEALTH_WEIGHT := 2.0
const HURT_HEALTH_WEIGHT := 6.0
const REST_WEIGHT := 1.0
## Seconds between flashes for creatures that glow, in the dark.
const FLASH_GAP := Vector2(1.5, 4.5)
const FLASH_TIME := 0.5

var model := OutcomeModel.new()
var rng := RandomNumberGenerator.new()
## The current action's working state (actions keep theirs here).
var state := {}
## What it's doing, in words.
var doing := "looking around"

var _action: CreatureAction
var _target: Thing
var _key := ""
var _features: Array[StringName] = []
var _before := PackedFloat32Array()
var _elapsed := 0.0
var _settle := -1.0
var _last := "" # The key of what it did last.
var _heard := {} # feature -> seconds left
var _damage := 0.0
var _hurt_age := INF
var _flash_wait := 0.0
var _roam_way := 1.0
var _blocked_age := INF


func _init(p_creature: Creature) -> void:
	super(p_creature)
	rng.seed = creature.seed_value + 1
	_roam_way = 1.0 if rng.randf() < 0.5 else -1.0


func think(delta: float) -> void:
	for feature: StringName in _heard.keys():
		_heard[feature] -= delta
		if _heard[feature] <= 0.0:
			_heard.erase(feature)
	_hurt_age += delta
	_blocked_age += delta
	var damage := _total_damage()
	if damage > _damage + 0.001:
		_hurt_age = 0.0
	_damage = damage
	_flash(delta)
	creature.desperate = need_food() > 0.6
	if _action:
		_carry_on(delta)
		return
	if _settle >= 0.0:
		_settle -= delta
		if _settle >= 0.0 and _hurt_age > 0.0:
			creature.walk = 0.0
			creature.fly_velocity = Vector2.ZERO
			return
		_learn()
	_choose()


## Hears a call from a creature of a species.
func hear(species_id: StringName) -> void:
	_heard[StringName("heard:" + species_id)] = HEAR_TIME


#region Needs
# Each 0 (empty) to 1 (full).

func fullness() -> float:
	var belly := creature.part_of(StomachPart) as StomachPart
	return belly.fullness() if belly else 1.0


func energy() -> float:
	return creature.blood() / maxf(creature.max_blood(), 0.0001)


## 1 unhurt, falling with damage taken and parts lost.
func health() -> float:
	var toughness := 0.0
	for part in creature.all_grown():
		toughness += part.toughness
	return 1.0 - _total_damage() / maxf(toughness, 0.0001)


## How much bile it has for digesting.
func rest() -> float:
	var belly := creature.part_of(StomachPart) as StomachPart
	return belly.bile() / belly.bile_capacity if belly else 1.0


func need_food() -> float:
	return 1.0 - fullness()


## Its needs as one outcome-sized list (see OutcomeModel).
func needs_now() -> PackedFloat32Array:
	return PackedFloat32Array([fullness(), energy(), health(), rest()])

#endregion


#region Moving

## Moves toward a point (for walkers, to stand `near` short of it, facing it, backing
## up if it's underfoot; with `away`, facing the way it goes). Returns RUNNING, DONE once
## there, or FAILED if it can't get there.
func approach(point: Vector2, near: float, delta: float, away := false) -> int:
	if creature.flies():
		var to := point - creature.global_position
		if to.length() <= maxf(near, 2.0):
			creature.fly_velocity = Vector2.ZERO
			return CreatureAction.DONE
		var ground := NAN if creature.swims() else creature.ground_below(creature.global_position, 6.0)
		creature.fly_velocity = to.normalized() * creature.species.walk_speed * minf(to.length() / 12.0, 1.0)
		if not is_nan(ground) and to.y > -2.0 and to.length() > 10.0:
			creature.fly_velocity.y = minf(creature.fly_velocity.y, -10.0) # Keep off the ground.
		return CreatureAction.RUNNING
	var side := signf(point.x - creature.global_position.x)
	if side == 0.0:
		side = creature.facing
	var stand := point.x - side * near
	var to_stand := stand - creature.global_position.x
	if absf(to_stand) <= 2.0:
		creature.walk = 0.0
		return CreatureAction.DONE
	creature.face = int(signf(to_stand)) if away else int(side)
	var backing := to_stand * side < 0.0 and not away
	creature.walk = signf(to_stand) * (0.6 if backing else 1.0)
	if creature.blocked:
		creature.walk = 0.0
		return CreatureAction.FAILED
	return CreatureAction.RUNNING


## Which way to roam: the same way it last went, unless that way's blocked.
func roam_direction() -> float:
	if _blocked_age < 30.0:
		return _roam_way
	if rng.randf() < 0.3:
		_roam_way = -_roam_way
	return _roam_way


## Notes that its roaming was blocked, so it turns round.
func blocked_way() -> void:
	_roam_way = -_roam_way
	_blocked_age = 0.0

#endregion


#region Deciding

func _carry_on(delta: float) -> void:
	_elapsed += delta
	var result := CreatureAction.FAILED
	if _target == null or _target.valid():
		result = _action.step(self, _target, delta)
	if _elapsed > _action.max_time:
		result = CreatureAction.FAILED
	var flinch := _hurt_age == 0.0 and _action.id != &"flee"
	if result != CreatureAction.RUNNING or flinch:
		_action.end(self)
		_action = null
		creature.walk = 0.0
		creature.face = 0
		creature.fly_velocity = Vector2.ZERO
		_settle = SETTLE_TIME


## Learns from what the last action led to.
func _learn() -> void:
	_settle = -1.0
	if _key.is_empty():
		return
	var outcome := needs_now()
	for i in OutcomeModel.SIZE:
		outcome[i] -= _before[i]
	model.learn(_key, _features, outcome, _hunch(_key))
	_last = _key


## Picks what to do next and starts it.
func _choose() -> void:
	var things := _notice()
	_features = _circumstances(things)
	var choice := _reflex(things)
	if choice.is_empty():
		choice = _best(things)
	if choice.is_empty():
		doing = "looking around"
		return
	_action = choice.action
	_target = choice.target
	_key = _key_for(_action, _target)
	_before = needs_now()
	_elapsed = 0.0
	state = {}
	doing = _action.verb + (" " + _target.kind.get_slice(":", _target.kind.get_slice_count(":") - 1) if _target else "")
	_action.begin(self, _target)


## Running from danger, which comes before any choice.
func _reflex(things: Array[Thing]) -> Dictionary:
	var flee := _action_named(&"flee")
	if flee == null:
		return {}
	var nearest: Thing = null
	var nearest_distance := INF
	for thing in things:
		var distance := thing.point().distance_to(creature.global_position)
		var mover := thing.kind == &"player" or String(thing.kind).begins_with("creature") or thing.kind == &"machine"
		var scary := mover and _hurt_age < HURT_FLEE_TIME \
				or (distance < DANGER_REACH and model.danger(thing.kind) > DANGER_FEAR)
		if scary and distance < nearest_distance:
			nearest = thing
			nearest_distance = distance
	return {action = flee, target = nearest} if nearest else {}


## The option that looks best for its needs, plus curiosity.
func _best(things: Array[Thing]) -> Dictionary:
	var weights := _need_weights()
	var best := {}
	var best_score := -INF
	for action in creature.species.actions:
		var options: Array = [null] if action.targets.is_empty() else things.filter(action.can_target)
		for target: Thing in options:
			var key := _key_for(action, target)
			var expected := model.predict(key, _features, _hunch(key))
			var score := rng.randf() * WHIM + creature.species.curiosity * model.novelty(key, _features)
			for i in OutcomeModel.SIZE:
				score += expected[i] * weights[i]
			if action.id == &"flee" and target:
				score += model.danger(target.kind) * weights[OutcomeModel.HEALTH]
			if score > best_score:
				best_score = score
				best = {action = action, target = target}
	return best


func _need_weights() -> PackedFloat32Array:
	return PackedFloat32Array([FOOD_WEIGHT * need_food(), ENERGY_WEIGHT * (1.0 - energy()),
			HEALTH_WEIGHT + HURT_HEALTH_WEIGHT * (1.0 - health()), REST_WEIGHT * (1.0 - rest())])


## The nearest thing of each kind it can see.
func _notice() -> Array[Thing]:
	var here := creature.global_position
	var sight := creature.species.sight
	var nearest := {} # kind -> [Thing, distance]
	var consider := func(thing: Thing) -> void:
		var distance := thing.point().distance_to(here)
		if distance <= sight and (not nearest.has(thing.kind) or distance < nearest[thing.kind][1]):
			nearest[thing.kind] = [thing, distance]
	for plant in creature.flora().plants:
		if absf(plant.global_position.x - here.x) > sight + 32.0 or plant.is_queued_for_deletion():
			continue
		var leaf := _nearest_leaf(plant, here)
		if leaf:
			var thing := Thing.new(StringName("plant:" + plant.species.id), plant)
			thing.leaf = leaf
			consider.call(thing)
	_notice_blocks(consider)
	for other: Creature in creature.get_tree().get_nodes_in_group(Creature.GROUP):
		if other != creature and not other.dead:
			consider.call(Thing.new(StringName("creature:" + other.species.id), other))
	for player in creature.get_tree().get_nodes_in_group(Player.GROUP):
		consider.call(Thing.new(&"player", player))
	for body in creature.world.loose_bodies():
		if body is MachineBody:
			consider.call(Thing.new(&"machine", body))
	for node in creature.world.get_children():
		if node is LooseItem and not node.is_queued_for_deletion():
			consider.call(Thing.new(StringName("item:" + node.item_id), node))
	var liquids := creature.world.liquids
	for kind in Liquids.KINDS.size():
		var cell := liquids.nearest(here, kind, mini(ceili(sight / BlockGrid.CELL_SIZE), 8), 0.2)
		if cell != Vector2i.MAX:
			var thing := Thing.new(StringName("liquid:" + Liquids.KINDS[kind]), liquids)
			thing.liquids = liquids
			thing.cell = cell
			consider.call(thing)
	var found: Array[Thing] = []
	for entry: Array in nearest.values():
		found.append(entry[0])
	return found


## Terrain blocks with air above them (what it can see of the ground), and loose blocks.
func _notice_blocks(consider: Callable) -> void:
	var terrain := creature.world.terrain
	var center := terrain.global_to_cell(creature.global_position)
	var reach := mini(ceili(creature.species.sight / BlockGrid.CELL_SIZE), 8)
	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			var cell := Vector2i(x, y)
			if terrain.has_block(cell) and not terrain.has_block(cell + Vector2i.UP):
				var thing := Thing.new(StringName("block:" + Blocks.get_type(terrain.get_block(cell)).id), terrain)
				thing.grid = terrain
				thing.cell = cell
				consider.call(thing)
	for body in creature.world.loose_bodies():
		if body is BlockBody:
			for cell: Vector2i in body.grid.cells:
				var thing := Thing.new(StringName("block:" + Blocks.get_type(body.grid.cells[cell]).id), body)
				thing.grid = body.grid
				thing.cell = cell
				consider.call(thing)
				break


## The circumstances it notes: every kind of thing around, what it did last, calls it's
## heard, and whether it's night.
func _circumstances(things: Array[Thing]) -> Array[StringName]:
	var features: Array[StringName] = []
	for thing in things:
		features.append(thing.kind)
	if not _last.is_empty():
		features.append(StringName("did:" + _last))
	for feature: StringName in _heard:
		features.append(feature)
	var sky := creature.get_tree().get_first_node_in_group(SkyLayer.GROUP) as SkyLayer
	if sky:
		features.append(&"night" if sky.daylight() < 0.1 else &"day")
	return features


func _key_for(action: CreatureAction, target: Thing) -> String:
	return "%s|%s" % [action.id, target.kind if target else &""]


## What the species expects of an option it's never tried, as an outcome, if anything.
func _hunch(key: String) -> PackedFloat32Array:
	var instincts := creature.species.instincts
	if not instincts.has(key):
		return PackedFloat32Array()
	var hunch: Vector4 = instincts[key]
	return PackedFloat32Array([hunch.x, hunch.y, hunch.z, hunch.w])


func _action_named(id: StringName) -> CreatureAction:
	for action in creature.species.actions:
		if action.id == id:
			return action
	return null

#endregion


func _nearest_leaf(plant: Plant, here: Vector2) -> PlantPart:
	var best: PlantPart = null
	var best_distance := INF
	for part in plant.parts:
		if part.kind == PlantPart.Kind.LEAF:
			var distance := plant.to_global(part.end).distance_squared_to(here)
			if distance < best_distance:
				best_distance = distance
				best = part
	return best


func _total_damage() -> float:
	var total := 0.0
	for part in creature.all_grown():
		total += part.toughness if not part.attached else part.damage
	return total


## Creatures that glow flash every few seconds in the dark.
func _flash(delta: float) -> void:
	if not creature.has_node(^"Glow"):
		return
	creature.glow = maxf(creature.glow - delta / FLASH_TIME, 0.0)
	var sky := creature.get_tree().get_first_node_in_group(SkyLayer.GROUP) as SkyLayer
	if sky == null or sky.daylight() >= 0.1 or creature.sleeping:
		return
	_flash_wait -= delta
	if _flash_wait <= 0.0:
		_flash_wait = rng.randf_range(FLASH_GAP.x, FLASH_GAP.y)
		creature.glow = 1.0


func to_data() -> Dictionary:
	return {model = model.to_data(), last = _last}


func load_data(data: Dictionary) -> void:
	model.load_data(data.model)
	_last = data.last
