extends CreatureBrain
## A grazer (sheep): when its stomach runs low it looks for the nearest leaves it eats,
## walks up to them (backing up for ones underfoot), lowers its head and bites them off
## one by one until it's full.
## Otherwise it wanders a little and stands about, looking around.

enum State { IDLE, WANDER, GRAZE }

## Starts grazing below this fullness, and keeps going until it's above SATED.
const HUNGRY := 0.45
const SATED := 0.95
## Seconds the mouth is at a leaf before it's bitten off.
const CHEW_TIME := 0.5
## Seconds between looks for food.
const SEARCH_INTERVAL := 1.0
## Leaves it goes for, from this far above its feet (a step up)...
const REACH_UP := 24.0
## ...to this far below them (lower is down a hole), px.
const REACH_DOWN := 6.0
## How long it gives up on a plant it couldn't get to, seconds.
const GIVE_UP_TIME := 30.0
## Seconds it strains for a leaf before giving up on it.
const REACH_TIME := 3.0
## Seconds it allows for getting to a leaf, on top of the walk there.
const MEAL_SLACK := 6.0

var _state := State.IDLE
var _timer := 0.0
var _goal_x := 0.0
var _meal := {} # {plant, part}
var _chew := 0.0
var _reaching := 0.0
var _meal_time := 0.0 # Seconds left to get the leaf it's after.
var _search_wait := 0.0
var _avoid := {} # Plant -> seconds left
## Which way it searches for food when there's none in sight; it turns back when blocked.
var _search_direction := 1.0
var _rng := RandomNumberGenerator.new()


func _init(p_creature: Creature) -> void:
	super(p_creature)
	_rng.seed = creature.seed_value + 1
	_timer = _rng.randf_range(0.5, 3.0)


func think(delta: float) -> void:
	var stomach := creature.part_of(StomachPart) as StomachPart
	var head := creature.part_of(HeadPart) as HeadPart
	if stomach == null or head == null:
		return
	for plant: Variant in _avoid.keys():
		_avoid[plant] -= delta
		if _avoid[plant] <= 0.0 or not is_instance_valid(plant):
			_avoid.erase(plant)
	var hungry := stomach.fullness() < (SATED if _state == State.GRAZE else HUNGRY)
	if hungry and _graze(delta, stomach, head):
		_state = State.GRAZE
		creature.desperate = false
		return
	creature.face = 0
	if _state == State.GRAZE:
		_state = State.IDLE
		_timer = _rng.randf_range(1.0, 4.0)
		head.reach_for(Vector2.INF)
	_roam(delta, head, hungry)


## Heads for food and eats it. Returns false if there's none to be had.
func _graze(delta: float, stomach: StomachPart, head: HeadPart) -> bool:
	if not _meal_left():
		_meal = {}
		_chew = 0.0
		_reaching = 0.0
		_search_wait -= delta
		if _search_wait > 0.0:
			return _state == State.GRAZE # Keep standing over the grass between looks.
		_search_wait = SEARCH_INTERVAL
		_meal = _find_meal()
		if _meal.is_empty():
			creature.walk = 0.0
			return false
		var away := absf(_bite_point().x - creature.global_position.x)
		_meal_time = MEAL_SLACK + away / creature.species.walk_speed * 2.0
	var plant: Plant = _meal.plant
	var bite := _bite_point()
	# Every try at a leaf is bounded, so nothing in the way can hold it up for long.
	_meal_time -= delta
	if _meal_time <= 0.0:
		_avoid[plant] = GIVE_UP_TIME
		_meal = {}
		creature.walk = 0.0
		return true
	# Stand a head's reach from the leaf, facing it, backing up if it's underfoot.
	var side := signf(bite.x - creature.global_position.x)
	if side == 0.0:
		side = creature.facing
	creature.face = int(side)
	var to_stand := bite.x - side * head.reach_ahead() - creature.global_position.x
	if head.can_reach(bite) and creature.facing == int(side):
		creature.walk = 0.0
		head.reach_for(bite)
		_reaching += delta
		if _reaching > REACH_TIME:
			_avoid[plant] = GIVE_UP_TIME
			_meal = {}
		elif head.mouth().distance_to(bite) < 2.5:
			_chew += delta
			if _chew >= CHEW_TIME:
				var eaten := plant.graze(_meal.part)
				if eaten > 0.0:
					stomach.eat(eaten)
				else: # Grazed down as far as it goes.
					_avoid[plant] = GIVE_UP_TIME
				_meal = {}
				_chew = 0.0
				_reaching = 0.0
				_search_wait = 0.0
	else:
		_chew = 0.0
		head.reach_for(Vector2.INF)
		var backing := to_stand * side < 0.0
		creature.walk = signf(to_stand) * (0.6 if backing else 1.0) if absf(to_stand) > 1.5 else 0.0
		if creature.walk == 0.0: # Where it should reach from, but can't: edge closer.
			_reaching += delta
			creature.walk = side * 0.4
		if creature.blocked or _reaching > REACH_TIME:
			_avoid[plant] = GIVE_UP_TIME
			_meal = {}
			_reaching = 0.0
	return true


## Wanders and stands about. Hungry with nothing to eat in sight, it keeps moving on in
## one direction until it finds some or is blocked, and takes bigger drops to get there.
func _roam(delta: float, head: HeadPart, hungry: bool) -> void:
	_timer -= delta
	creature.desperate = hungry
	match _state:
		State.IDLE:
			creature.walk = 0.0
			if _timer <= 0.0 or hungry:
				if hungry: # Off to look for pasture.
					_state = State.WANDER
					_goal_x = creature.global_position.x + _rng.randf_range(120.0, 240.0) * _search_direction
					_timer = 20.0
				elif _rng.randf() < 0.6:
					_state = State.WANDER
					_goal_x = creature.global_position.x + _rng.randf_range(30.0, 110.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
					_timer = 15.0
					head.reach_for(Vector2.INF)
				else: # Look about.
					_timer = _rng.randf_range(2.0, 5.0)
					var look := Vector2(creature.facing * _rng.randf_range(8.0, 20.0), _rng.randf_range(-14.0, 4.0))
					head.reach_for(head.base + look if _rng.randf() < 0.7 else Vector2.INF)
		State.WANDER:
			var to_goal := _goal_x - creature.global_position.x
			creature.walk = signf(to_goal) * 0.7
			if creature.blocked:
				_search_direction = -signf(to_goal)
			if absf(to_goal) < 4.0 or _timer <= 0.0 or creature.blocked:
				_state = State.IDLE
				_timer = _rng.randf_range(2.0, 6.0)
				creature.walk = 0.0


## Whether the leaf it's after is still there.
func _meal_left() -> bool:
	if _meal.is_empty() or not is_instance_valid(_meal.plant):
		return false
	var plant: Plant = _meal.plant
	return not plant.is_queued_for_deletion() and plant.parts.has(_meal.part)


func _bite_point() -> Vector2:
	var plant: Plant = _meal.plant
	var part: PlantPart = _meal.part
	return plant.to_global(part.end) + Vector2(0.0, -2.0)


## The nearest leaf it eats around the level it stands on, favouring ones ahead of it
## and ones it needn't climb to.
func _find_meal() -> Dictionary:
	var best := {}
	var best_score := INF
	var here := creature.global_position
	for plant in creature.flora().plants:
		if not creature.species.food.has(plant.species.id) or _avoid.has(plant) or plant.is_queued_for_deletion() \
				or plant.parts.size() < 3:
			continue
		if absf(plant.global_position.x - here.x) > creature.species.sight + 64.0:
			continue
		for part in plant.parts:
			if part.kind != PlantPart.Kind.LEAF:
				continue
			var at := plant.to_global(part.end)
			var away := at.x - here.x
			var below := at.y - here.y
			if absf(away) > creature.species.sight or below < -REACH_UP or below > REACH_DOWN:
				continue
			var score := absf(away) + absf(below) * 2.0 + (24.0 if away * creature.facing < 0.0 else 0.0)
			if score < best_score:
				best_score = score
				best = {plant = plant, part = part}
	return best
