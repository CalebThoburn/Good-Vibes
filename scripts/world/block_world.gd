class_name BlockWorld
extends Node2D
## Owns the static terrain grid, every loose BlockBody and placed MachineBody, and
## answers block queries across all of them.

const BLOCK_LAYER := 1
const PLAYER_LAYER := 2
const MACHINE_LAYER := 4

@export var width := 256
@export var height := 128
@export var world_seed := 1337

@export_group("Terrain")
@export var surface_level := 40
@export var surface_amplitude := 12.0
@export var dirt_depth := 5
## Adds a small pillar-and-slab structure next to spawn for trying out collapses.
@export var build_test_structure := true

var terrain: BlockGrid

var _bodies: Node2D
var _surface_noise := FastNoiseLite.new()


func _ready() -> void:
	var terrain_body := StaticBody2D.new()
	terrain_body.name = "Terrain"
	terrain_body.collision_layer = BLOCK_LAYER
	terrain_body.collision_mask = 0
	add_child(terrain_body)

	terrain = BlockGrid.new()
	terrain.name = "Grid"
	terrain.anchored = true
	terrain.anchor_row = height - 1
	terrain.world = self
	terrain_body.add_child(terrain)

	_bodies = Node2D.new()
	_bodies.name = "Bodies"
	add_child(_bodies)

	_generate()


func surface_y(x: int) -> int:
	return surface_level + roundi(_surface_noise.get_noise_1d(x) * surface_amplitude)


func spawn_position() -> Vector2:
	var x := width / 2
	return terrain.to_global(Vector2(x + 0.5, surface_y(x)) * BlockGrid.CELL_SIZE - Vector2(0, 16))


## Anything that falls below this is gone.
func kill_y() -> float:
	return terrain.to_global(Vector2(0, height + 64) * BlockGrid.CELL_SIZE).y


## Returns {grid, cell} for the block at a global point, or {} if there is none.
func block_at(global_point: Vector2) -> Dictionary:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_point
	query.collision_mask = BLOCK_LAYER
	for result in get_world_2d().direct_space_state.intersect_point(query, 8):
		var grid := result.collider.get_node_or_null(^"Grid") as BlockGrid
		if grid == null:
			continue
		var cell := grid.global_to_cell(global_point)
		if grid.has_block(cell):
			return {grid = grid, cell = cell}
	return {}


## Returns the placed machine at a global point, or null.
func machine_at(global_point: Vector2) -> MachineBody:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_point
	query.collision_mask = MACHINE_LAYER
	for result in get_world_2d().direct_space_state.intersect_point(query, 1):
		return result.collider as MachineBody
	return null


func can_place_machine(global_point: Vector2) -> bool:
	return _is_area_free(global_point, Vector2.ONE * MachineDesign.SIZE * MachineDesign.TIDBIT_PIXELS)


func spawn_machine(design: MachineDesign, global_point: Vector2) -> MachineBody:
	var body := MachineBody.new()
	body.position = _bodies.to_local(global_point)
	_bodies.add_child(body)
	body.setup(design, self)
	return body


## Creates a loose body from blocks given in the coordinates of a grid at grid_transform.
## Pass the body they broke off from so the new one keeps its motion.
func spawn_body(blocks: Dictionary[Vector2i, int], grid_transform: Transform2D, source: RigidBody2D = null) -> BlockBody:
	# Re-center the cells on the body's origin so its position means something.
	var bounds := Rect2i(blocks.keys()[0], Vector2i.ONE)
	for cell in blocks:
		bounds = bounds.merge(Rect2i(cell, Vector2i.ONE))
	var offset := bounds.get_center()

	var body := BlockBody.new()
	body.transform = _bodies.global_transform.affine_inverse() * grid_transform \
			* Transform2D(0.0, Vector2(offset) * BlockGrid.CELL_SIZE)
	body.grid.world = self
	for cell in blocks:
		body.grid.set_block(cell - offset, blocks[cell])
	body.update_mass_properties()
	_bodies.add_child(body)

	if source:
		# Velocity of the source at the new body's center of mass.
		var arm := body.global_transform * body.center_of_mass - source.global_transform * source.center_of_mass
		body.linear_velocity = source.linear_velocity + Vector2(-arm.y, arm.x) * source.angular_velocity
		body.angular_velocity = source.angular_velocity
	return body


## Whether an axis-aligned box (shrunk slightly so touching neighbors don't count) is empty.
func _is_area_free(global_center: Vector2, size: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = size * 0.9
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_center)
	query.collision_mask = BLOCK_LAYER | PLAYER_LAYER | MACHINE_LAYER
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _generate() -> void:
	_surface_noise.seed = world_seed
	_surface_noise.frequency = 0.02
	var depth_noise := FastNoiseLite.new()
	depth_noise.seed = world_seed + 1
	depth_noise.frequency = 0.08

	var dirt := Blocks.id_of(&"dirt")
	var stone := Blocks.id_of(&"stone")
	for x in width:
		var surface := surface_y(x)
		var stone_top := surface + dirt_depth + roundi(depth_noise.get_noise_1d(x) * 2.0)
		for y in range(surface, height):
			terrain.set_block(Vector2i(x, y), dirt if y < stone_top else stone)

	if build_test_structure:
		_build_test_structure(width / 2 + 8)


## A two-wide stone pillar holding up a slab. Mine through the pillar to drop it.
func _build_test_structure(left: int) -> void:
	var stone := Blocks.id_of(&"stone")
	var top := mini(surface_y(left), surface_y(left + 1)) - 7
	for x in [left, left + 1]:
		for y in range(top, surface_y(x)):
			terrain.set_block(Vector2i(x, y), stone)
	for x in range(left - 4, left + 6):
		terrain.set_block(Vector2i(x, top - 1), stone)
