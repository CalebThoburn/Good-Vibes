class_name Fauna
extends Node2D
## Every creature in the world, and the species they come from.

const SPECIES_DIR := "res://data/creatures/"
## How far from the middle of the world creatures start, in blocks.
const SPAWN_SPREAD := 90
## Fliers start this far above the ground, px.
const FLIER_HEIGHT := 24.0

static var _species: Dictionary[StringName, CreatureSpecies] = {}

var world: BlockWorld
var species: Dictionary[StringName, CreatureSpecies] = {}

var _rng := RandomNumberGenerator.new()


## Every species, by id.
static func all_species() -> Dictionary[StringName, CreatureSpecies]:
	if _species.is_empty():
		for file in ResourceLoader.list_directory(SPECIES_DIR):
			if file.ends_with(".tres"):
				var kind := load(SPECIES_DIR + file) as CreatureSpecies
				if kind:
					_species[kind.id] = kind
	return _species


static func species_named(id: StringName) -> CreatureSpecies:
	return all_species()[id]


func _ready() -> void:
	species = all_species()


func creatures() -> Array[Creature]:
	var found: Array[Creature] = []
	for node in get_children():
		if node is Creature and not node.is_queued_for_deletion():
			found.append(node)
	return found


## Scatters each species' starting population over the ground around the middle.
## Fliers start in the air, by a tree if there's one near; swimmers in the lakes.
func populate(seed_value: int) -> void:
	_rng.seed = seed_value
	for kind: CreatureSpecies in species.values():
		var flies: bool = kind.body_plan.any(func(part: BodyPart) -> bool: return part is WingPart)
		if kind.swims:
			_populate_water(kind)
			continue
		for i in kind.population:
			var x := world.width / 2 + _rng.randi_range(-SPAWN_SPREAD, SPAWN_SPREAD)
			if flies:
				x = _near_tree(x)
			var ground := world.terrain.to_global(Vector2(x + 0.5, world.surface_y(x)) * BlockGrid.CELL_SIZE)
			spawn(kind, ground + Vector2(0.0, -FLIER_HEIGHT if flies else -2.0), _rng.randi())


func spawn(kind: CreatureSpecies, global_point: Vector2, seed_value: int) -> Creature:
	var creature := Creature.new()
	creature.position = to_local(global_point)
	creature.setup(kind, world, seed_value)
	add_child(creature)
	return creature


## Living creatures as data (dead ones are just pieces, and aren't kept).
func to_data() -> Array:
	return creatures().filter(func(creature: Creature) -> bool: return not creature.dead) \
			.map(func(creature: Creature) -> Dictionary: return creature.to_data())


## Replaces every creature with saved ones.
func load_data(saved: Array) -> void:
	for creature in creatures():
		creature.queue_free()
	for data: Dictionary in saved:
		if species.has(data.species):
			spawn(species[data.species], data.position, data.seed).load_data(data)


## Swimmers start in the lakes, in water with more water or the lake bed under it.
func _populate_water(kind: CreatureSpecies) -> void:
	var liquids := world.liquids
	var deep: Array[Vector2i] = []
	for cell in liquids.free:
		var below := cell + Vector2i.DOWN
		if liquids.free[cell].x >= 0.9 and (world.terrain.has_block(below) or liquids.free.has(below)):
			deep.append(cell)
	deep.sort()
	if deep.is_empty():
		return
	for i in kind.population:
		var cell := deep[_rng.randi() % deep.size()]
		spawn(kind, liquids.cell_center(cell) + Vector2(0.0, 4.0), _rng.randi())


## The column of the tree nearest to column x, or x if there's none.
func _near_tree(x: int) -> int:
	var best := x
	var best_distance := INF
	for plant in world.flora.plants:
		if plant.species.form == PlantSpecies.Form.TREE and absi(plant.anchor_cell.x - x) < best_distance:
			best_distance = absi(plant.anchor_cell.x - x)
			best = plant.anchor_cell.x
	return best
