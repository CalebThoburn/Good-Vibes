extends CreatureAction
## Goes up to something and bites it: a leaf is eaten (grazed, or sipped for water,
## whichever the creature lives on), a loose item of its food is eaten, water is drunk
## by creatures that live on it, and a creature or the player is hurt. Other things just
## get a mouthful of nothing.

## Seconds the mouth works at it before the bite lands.
@export var chew_time := 0.5
## Damage a bite does to a creature or the player.
@export var damage := 0.5
## Water taken per sip from a plant.
@export var sip := 0.05


func begin(mind: Mind, _thing: Thing) -> void:
	mind.state = {chew = 0.0}


func step(mind: Mind, thing: Thing, delta: float) -> int:
	var creature := mind.creature
	var point := thing.point()
	var head := creature.part_of(HeadPart) as HeadPart
	if head == null:
		return FAILED
	var flying := creature.flies()
	var in_reach := creature.global_position.distance_to(point) < 4.0 if flying \
			else head.can_reach(point) and creature.facing == int(signf(point.x - creature.global_position.x))
	if not in_reach:
		mind.state.chew = 0.0
		head.reach_for(Vector2.INF)
		var approached := mind.approach(point, 0.0 if flying else head.reach_ahead(), delta)
		return FAILED if approached == FAILED else RUNNING
	creature.walk = 0.0
	creature.fly_velocity = Vector2.ZERO
	head.reach_for(point)
	if not flying and head.mouth().distance_to(point) > 2.5:
		return RUNNING
	mind.state.chew += delta
	if mind.state.chew < chew_time:
		return RUNNING
	head.reach_for(Vector2.INF)
	_bite(creature, thing, point)
	return DONE


func _bite(creature: Creature, thing: Thing, point: Vector2) -> void:
	var belly := creature.part_of(StomachPart) as StomachPart
	if thing.leaf and belly:
		var plant: Plant = thing.node
		if belly.food_item == &"water":
			belly.eat(plant.sip(sip))
		elif belly.food_item == &"grass" and plant.species.form == PlantSpecies.Form.CREEPER:
			belly.eat(plant.graze(thing.leaf))
	elif thing.liquids and belly and String(thing.kind) == "liquid:" + belly.food_item:
		var index := thing.liquids.kind_index(belly.food_item)
		belly.eat(thing.liquids.take(thing.cell, index, sip * Liquids.UNIT) / Liquids.UNIT)
	elif thing.node is LooseItem and belly and thing.node.item_id == belly.food_item:
		belly.eat(1.0)
		thing.node.count -= 1
		if thing.node.count <= 0:
			thing.node.queue_free()
	elif thing.node is Creature:
		var bitten: BodyPart = thing.node.part_at(point)
		if bitten == null and not thing.node.parts.is_empty():
			bitten = thing.node.parts[0]
		if bitten:
			thing.node.hurt(bitten, damage, point)
	elif thing.node is Player:
		thing.node.hurt(damage, point)
