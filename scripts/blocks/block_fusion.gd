class_name BlockFusion
extends Node
## Loose block bodies that sit still against another mass (the terrain or another loose
## body) for a while fuse into it. Every CHECK_INTERVAL, each pair of touching blocks
## (one from each mass) has a chance to fuse that grows with both blocks' densities, so
## it happens after a random wait that's shorter for dense blocks and wide contacts. The
## body's blocks then snap onto the other mass's grid.

const CHECK_INTERVAL := 0.5
## Chance per second, per touching pair of blocks, per unit of density squared.
const FUSE_RATE := 0.004
## A body counts as sitting still below these speeds (px/s and radians/s).
const STILL_SPEED := 4.0
const STILL_SPIN := 0.1
## How far off a quarter turn from the other mass a body can sit and still line up.
const ALIGN_TOLERANCE := 0.15
const NEIGHBORS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var world: BlockWorld

var _wait := CHECK_INTERVAL
var _rng := RandomNumberGenerator.new()


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_INTERVAL
	var bodies: Array[BlockBody] = []
	for node in world.get_node("Bodies").get_children():
		if node is BlockBody and not node.is_queued_for_deletion():
			bodies.append(node)
	for body in bodies:
		if is_instance_valid(body) and not body.is_queued_for_deletion() and _is_still(body):
			_try_fuse(body, bodies)


## Rolls for `body` against each mass it sits against, and fuses into the first that
## comes up.
func _try_fuse(body: BlockBody, bodies: Array[BlockBody]) -> void:
	var targets: Array[BlockGrid] = [world.terrain]
	for other in bodies:
		# Smaller bodies fuse into bigger ones; resting ones only.
		if other != body and is_instance_valid(other) and not other.is_queued_for_deletion() \
				and other.grid.cells.size() >= body.grid.cells.size() and _is_still(other) \
				and other.global_position.distance_to(body.global_position) < 24.0 * BlockGrid.CELL_SIZE:
			targets.append(other.grid)
	for target in targets:
		var odds := _fuse_odds(body.grid, target)
		if odds > 0.0 and _rng.randf() < odds:
			_fuse(body, target)
			return


## The chance this check that a body's grid fuses into a target grid: from every pair of
## touching blocks. 0 if they don't line up or the body's blocks wouldn't fit.
func _fuse_odds(grid: BlockGrid, target: BlockGrid) -> float:
	var turn := wrapf(grid.global_rotation - target.global_rotation, -PI, PI)
	if absf(turn - snappedf(turn, PI / 2.0)) > ALIGN_TOLERANCE:
		return 0.0
	var chance_none := 1.0
	for cell in grid.cells:
		var landing := _landing(grid, cell, target)
		if target.has_block(landing):
			return 0.0 # Would overlap.
		var density := Blocks.get_type(grid.cells[cell]).density
		for dir in NEIGHBORS:
			if target.has_block(landing + dir):
				var pair := density * Blocks.get_type(target.get_block(landing + dir)).density
				chance_none *= 1.0 - minf(FUSE_RATE * pair * CHECK_INTERVAL, 1.0)
	return 1.0 - chance_none


## Where a block of `grid` lands on `target`'s grid when they fuse.
func _landing(grid: BlockGrid, cell: Vector2i, target: BlockGrid) -> Vector2i:
	return target.global_to_cell(grid.to_global(BlockGrid.cell_center(cell)))


func _fuse(body: BlockBody, target: BlockGrid) -> void:
	for cell in body.grid.cells:
		target.set_block(_landing(body.grid, cell, target), body.grid.cells[cell])
	body.queue_free()


func _is_still(body: BlockBody) -> bool:
	return body.linear_velocity.length() < STILL_SPEED and absf(body.angular_velocity) < STILL_SPIN
