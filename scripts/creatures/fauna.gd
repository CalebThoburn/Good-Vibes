class_name Fauna
extends Node2D
## Every creature in the world, and the species they come from.

const SPECIES_DIR := "res://data/creatures/"
## How far from the middle of the world creatures start, in blocks.
const SPAWN_SPREAD := 90

var world: BlockWorld
var species: Dictionary[StringName, CreatureSpecies] = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for file in ResourceLoader.list_directory(SPECIES_DIR):
		if file.ends_with(".tres"):
			var kind := load(SPECIES_DIR + file) as CreatureSpecies
			if kind:
				species[kind.id] = kind


func creatures() -> Array[Creature]:
	var found: Array[Creature] = []
	for node in get_children():
		if node is Creature and not node.is_queued_for_deletion():
			found.append(node)
	return found


## Scatters each species' starting population over the ground around the middle.
func populate(seed_value: int) -> void:
	_rng.seed = seed_value
	for kind in species.values():
		for i in kind.population:
			var x := world.width / 2 + _rng.randi_range(-SPAWN_SPREAD, SPAWN_SPREAD)
			var ground := world.terrain.to_global(Vector2(x + 0.5, world.surface_y(x)) * BlockGrid.CELL_SIZE)
			spawn(kind, ground + Vector2(0.0, -2.0), _rng.randi())


func spawn(kind: CreatureSpecies, global_point: Vector2, seed_value: int) -> Creature:
	var creature := Creature.new()
	creature.position = to_local(global_point)
	creature.setup(kind, world, seed_value)
	add_child(creature)
	return creature


func to_data() -> Array:
	return creatures().map(func(creature: Creature) -> Dictionary: return creature.to_data())


## Replaces every creature with saved ones.
func load_data(saved: Array) -> void:
	for creature in creatures():
		creature.queue_free()
	for data: Dictionary in saved:
		if species.has(data.species):
			spawn(species[data.species], data.position, data.seed).load_data(data)
