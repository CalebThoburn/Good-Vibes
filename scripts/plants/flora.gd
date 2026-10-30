class_name Flora
extends Node2D
## Every plant in the world. Grows them with random ticks: each frame a few plants,
## picked at random, are stepped by TICK_TIME, so growth comes in uneven spurts rather
## than in lockstep. Also works out how much light reaches any point (sunlight from
## above, blocked by terrain and dimmed by leaves), and handles seeds, cut-off debris,
## and parts crumbling away.

const SPECIES_DIR := "res://data/plants/"
## Plant time a random tick advances a plant by, in seconds.
const TICK_TIME := 0.5
## Bigger steps for growing the world's plants before play starts, to load faster.
const PREWARM_STEP := 1.5
## Random ticks per plant per second, on average. Below 1 / TICK_TIME, plants live slower
## than real time.
const TICKS_PER_SECOND := 0.5
## Leaves are counted on a grid this fine for shading: one leaf clump per cell.
const SHADE_CELL := float(BlockGrid.CELL_SIZE)
## Share of light each leaf lets through.
const LEAF_TRANSMITTANCE := 0.6
## How far up light is traced, in shade cells.
const LIGHT_REACH := 12
## Sunlight comes from straight up and a little to either side.
const LIGHT_DIRECTIONS: Array[Vector2] = [Vector2(0.0, -1.0), Vector2(-0.42, -0.91), Vector2(0.42, -0.91)]
## Blocks between the plants scattered over a new world, per species (any others: 8-20).
const SCATTER_GAPS: Dictionary[StringName, Vector2i] = {&"oak": Vector2i(6, 16), &"grass": Vector2i(2, 5)}

## Speeds up plant life, for testing.
@export var time_scale := 1.0
## Seconds of growth simulated when the world is created.
@export var prewarm_time := 90.0

var world: BlockWorld
var species: Dictionary[StringName, PlantSpecies] = {}
var plants: Array[Plant] = []

# Leaves per shade cell, kept up to date by the plants.
var _shade: Dictionary[Vector2i, int] = {}
var _to_terrain := Transform2D.IDENTITY
var _ticks_owed := 0.0
var _rng := RandomNumberGenerator.new()


static func shade_cell(global_point: Vector2) -> Vector2i:
	return Vector2i((global_point / SHADE_CELL).floor())


func _ready() -> void:
	for file in ResourceLoader.list_directory(SPECIES_DIR):
		if file.ends_with(".tres"):
			var kind := load(SPECIES_DIR + file) as PlantSpecies
			if kind:
				species[kind.id] = kind


func _physics_process(delta: float) -> void:
	# A few plants a frame, so no single frame pays for all of them.
	_to_terrain = world.terrain.global_transform.affine_inverse()
	_ticks_owed += delta * time_scale * plants.size() * TICKS_PER_SECOND
	while _ticks_owed >= 1.0 and not plants.is_empty():
		_ticks_owed -= 1.0
		var plant := plants[_rng.randi() % plants.size()]
		if not plant.is_queued_for_deletion():
			plant.step(TICK_TIME)


## Scatters young plants of every species over the surface, then lets them grow for
## prewarm_time. From then on, plants react straight away when the terrain changes.
func populate(seed_value: int) -> void:
	_rng.seed = seed_value
	world.terrain.changed.connect(_on_terrain_changed)
	for kind in species.values():
		var gap: Vector2i = SCATTER_GAPS.get(kind.id, Vector2i(8, 20))
		var x := _rng.randi_range(3, 10)
		while x < world.width - 3 and count_of(kind) < kind.max_population:
			var cell := Vector2i(x, world.surface_y(x))
			if _is_soil_cell(cell, kind) and not world.terrain.has_block(cell + Vector2i.UP):
				spawn_plant(kind, cell)
			x += _rng.randi_range(gap.x, gap.y)
	for i in roundi(prewarm_time / PREWARM_STEP):
		step_all(PREWARM_STEP)


## Anything the ground has gone from under falls.
func _on_terrain_changed() -> void:
	_to_terrain = world.terrain.global_transform.affine_inverse()
	for plant in plants.duplicate():
		if not plant.is_queued_for_deletion():
			plant.check_support()


## Steps every plant once.
func step_all(dt: float) -> void:
	_to_terrain = world.terrain.global_transform.affine_inverse()
	for plant in plants.duplicate():
		if not plant.is_queued_for_deletion():
			plant.step(dt)


## Adds (or with -1, removes) leaves to the shade map.
func shade(cells: Array[Vector2i], amount: int) -> void:
	for cell in cells:
		var leaves: int = _shade.get(cell, 0) + amount
		if leaves > 0:
			_shade[cell] = leaves
		else:
			_shade.erase(cell)


## Light reaching a point, from 0 (dark) to 1 (open sky).
func light_at(global_point: Vector2) -> float:
	var total := 0.0
	for direction in LIGHT_DIRECTIONS:
		var light := 1.0
		for step in range(1, LIGHT_REACH + 1):
			var point := global_point + direction * step * SHADE_CELL
			if is_solid(point):
				light = 0.0
				break
			var leaves: int = _shade.get(shade_cell(point), 0)
			if leaves > 0:
				light *= pow(LEAF_TRANSMITTANCE, leaves)
				if light < 0.02:
					break
		total += light
	return total / LIGHT_DIRECTIONS.size()


func is_solid(global_point: Vector2) -> bool:
	return world.terrain.has_block(_terrain_cell(global_point))


func is_soil(global_point: Vector2, kind: PlantSpecies) -> bool:
	return _is_soil_cell(_terrain_cell(global_point), kind)


## The plant part at a global point, as {plant, part}, or {} if there's none.
func part_at(global_point: Vector2) -> Dictionary:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_point
	query.collision_mask = BlockWorld.PLANT_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_point(query, 1):
		var hitbox: Area2D = result.collider
		var part: PlantPart = hitbox.shape_owner_get_owner(hitbox.shape_find_owner(result.shape))
		return {plant = hitbox.get_parent(), part = part}
	return {}


func spawn_plant(kind: PlantSpecies, cell: Vector2i) -> Plant:
	_to_terrain = world.terrain.global_transform.affine_inverse()
	var plant := Plant.new()
	plant.position = to_local(world.terrain.to_global(Vector2(cell.x + 0.5, cell.y) * BlockGrid.CELL_SIZE))
	add_child(plant)
	plant.setup(kind, self, cell, _rng.randi())
	plants.append(plant)
	return plant


func remove_plant(plant: Plant) -> void:
	plant.clear_shade()
	plants.erase(plant)
	plant.queue_free()


func count_of(kind: PlantSpecies) -> int:
	var count := 0
	for plant in plants:
		if plant.species == kind:
			count += 1
	return count


func drop_seed(kind: PlantSpecies, global_point: Vector2, velocity: Vector2) -> void:
	if count_of(kind) >= kind.max_population:
		return
	var plant_seed := PlantSeed.new(self, kind, velocity)
	plant_seed.position = to_local(global_point)
	add_child(plant_seed)


## Plants a seed that has landed, if the spot is good. Returns whether it sprouted.
func try_sprout(kind: PlantSpecies, global_point: Vector2, normal: Vector2) -> bool:
	if normal.y > -0.7 or count_of(kind) >= kind.max_population:
		return false # Only on top of a block.
	var cell := _terrain_cell(global_point - normal * 2.0)
	if not _is_soil_cell(cell, kind) or world.terrain.has_block(cell + Vector2i.UP) \
			or world.terrain.has_block(cell + Vector2i.UP * 2):
		return false
	var spot := world.terrain.to_global(Vector2(cell.x + 0.5, cell.y) * BlockGrid.CELL_SIZE)
	for plant in plants:
		if plant.species == kind and plant.global_position.distance_to(spot) < kind.min_spacing:
			return false
	spawn_plant(kind, cell)
	return true


## Sends cut or fallen parts tumbling as debris. Roots, and leaves with no wood to hang
## on to, just crumble.
func drop_debris(plant: Plant, parts: Array[PlantPart]) -> void:
	var wood: Array[PlantPart] = []
	var loose: Array[PlantPart] = []
	for part in parts:
		(loose if part.kind == PlantPart.Kind.ROOT else wood).append(part)
	if wood.any(func(part: PlantPart) -> bool: return part.kind == PlantPart.Kind.STEM):
		add_child(PlantDebris.new(self, plant.species, wood, plant.global_transform))
	else:
		loose.append_array(wood)
	crumble_parts(plant.species, plant.global_transform, loose)


## Parts falling apart into a puff of bits. `xform` takes the parts' space to global.
func crumble_parts(kind: PlantSpecies, xform: Transform2D, parts: Array[PlantPart]) -> void:
	var colors := {PlantPart.Kind.STEM: kind.bark_color, PlantPart.Kind.ROOT: kind.root_color,
			PlantPart.Kind.LEAF: kind.dying_leaf_color}
	var bits := {}
	for part in parts:
		if not bits.has(part.kind):
			bits[part.kind] = []
		bits[part.kind].append(to_local(xform * ((part.start + part.end) * 0.5)))
	for part_kind in bits:
		_crumble(PackedVector2Array(bits[part_kind]), colors[part_kind])


func _crumble(points: PackedVector2Array, color: Color) -> void:
	if points.is_empty():
		return
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.7
	particles.amount = clampi(points.size() * 3, 6, 96)
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	particles.emission_points = points
	particles.direction = Vector2.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 40.0
	particles.gravity = Vector2(0.0, 250.0)
	particles.color = color
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	particles.visibility_layer = SunShade.NO_SHADE_LAYER
	particles.z_index = Plant.Z_GRASS
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


func _terrain_cell(global_point: Vector2) -> Vector2i:
	return Vector2i((_to_terrain * global_point / BlockGrid.CELL_SIZE).floor())


func _is_soil_cell(cell: Vector2i, kind: PlantSpecies) -> bool:
	var block := world.terrain.get_block(cell)
	return block != Blocks.AIR and kind.soil.has(Blocks.get_type(block).id)
