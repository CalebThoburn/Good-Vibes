class_name BlockBody
extends RigidBody2D
## A loose section of blocks with its own grid. Spawned by BlockWorld.spawn_body().

## Mass of a block with density 1.
const MASS_PER_DENSITY := 10.0

var grid := BlockGrid.new()


func _init() -> void:
	collision_layer = BlockWorld.BLOCK_LAYER
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.PLAYER_LAYER | BlockWorld.MACHINE_LAYER
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	continuous_cd = CCD_MODE_CAST_SHAPE
	grid.name = "Grid"
	add_child(grid)
	grid.changed.connect(_on_grid_changed)
	grid.emptied.connect(queue_free)


func _physics_process(_delta: float) -> void:
	if grid.world and (global_transform * center_of_mass).y > grid.world.kill_y():
		queue_free()


## Mass and center of mass from the blocks' densities.
func update_mass_properties() -> void:
	var total := 0.0
	var moment := Vector2.ZERO
	for cell in grid.cells:
		var density := Blocks.get_type(grid.cells[cell]).density
		total += density
		moment += BlockGrid.cell_center(cell) * density
	if total > 0.0:
		mass = total * MASS_PER_DENSITY
		center_of_mass = moment / total


func _on_grid_changed() -> void:
	update_mass_properties()
	sleeping = false
