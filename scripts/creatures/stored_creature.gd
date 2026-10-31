class_name StoredCreature
extends Resource
## A live creature held inside a machine. Only creatures smaller than a block fit (a
## vacuum takes them in alive). It goes on living in there: it burns through its blood,
## eats or drinks its food when that's stored alongside it, and if its blood runs out it
## dies, leaving what it was made of in its place. Launched out, it carries on in the
## world as it was.

## Eats when its blood falls below this share.
const HUNGRY := 0.7

@export var species: StringName
## As saved by Creature.to_data.
@export var data: Dictionary = {}
@export var blood := 0.0
@export var max_blood := 0.0
## Blood used per second.
@export var upkeep := 0.0
@export var food_item: StringName
@export var blood_per_food := 0.0
## What its body comes to as items when it dies.
@export var makeup: Dictionary[StringName, int] = {}


## Takes a live creature out of the world and into this. The creature is freed.
static func capture(creature: Creature) -> StoredCreature:
	var stored := StoredCreature.new()
	stored.species = creature.species.id
	stored.data = creature.to_data()
	stored.blood = creature.blood()
	stored.max_blood = creature.max_blood()
	for part in creature.parts:
		stored.upkeep += part.upkeep
		for item_id in part.makeup:
			stored.makeup[item_id] = stored.makeup.get(item_id, 0) + part.makeup[item_id]
		if part is WingPart: # Buzzing about in there.
			stored.upkeep += part.flight_cost
	var belly := creature.part_of(StomachPart) as StomachPart
	if belly:
		stored.food_item = belly.food_item
		stored.blood_per_food = belly.blood_per_food
	creature.queue_free()
	return stored


func display_name() -> String:
	return Fauna.species_named(species).display_name


## One machine tick of life in a tidbit's storage: eats if it can, and dies if its blood
## runs out, leaving its body's makeup (as much as fits) where it was.
func live(design: MachineDesign, cell: Vector2i, delta: float) -> void:
	blood -= upkeep * delta
	if blood < max_blood * HUNGRY and food_item and design.stored_count(cell, food_item) > 0:
		design.unstore(cell, food_item)
		blood = minf(blood + blood_per_food, max_blood)
	if blood > 0.0:
		return
	design.unstore(cell, self)
	for item_id in makeup:
		var fits := mini(makeup[item_id], design.store_room(cell))
		if fits > 0:
			design.store(cell, item_id, fits)


## Puts it back into the world at a global point, moving at `velocity`.
func release(world: BlockWorld, at: Vector2, velocity: Vector2) -> Creature:
	var kind := Fauna.species_named(species)
	var creature := world.fauna.spawn(kind, at, data.seed)
	creature.load_data(data)
	creature.global_position = at
	creature.velocity = velocity
	var fill := blood / maxf(creature.max_blood(), 0.0001)
	for part in creature.parts:
		part.contents[&"blood"] = part.blood_capacity * fill
	return creature


func to_data() -> Dictionary:
	return {species = species, data = data, blood = blood, max_blood = max_blood, upkeep = upkeep,
			food_item = food_item, blood_per_food = blood_per_food, makeup = makeup.duplicate()}


static func from_data(saved: Dictionary) -> StoredCreature:
	var stored := StoredCreature.new()
	for field in saved:
		if field == "makeup":
			stored.makeup.assign(saved.makeup)
		else:
			stored.set(field, saved[field])
	return stored
