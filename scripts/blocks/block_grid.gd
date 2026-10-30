class_name BlockGrid
extends Node2D
## A set of blocks aligned to one local grid.
##
## A grid must be the direct child of a CollisionObject2D (the terrain's StaticBody2D or
## a BlockBody), and it builds that body's collision shapes from its cells.
##
## Anchored grids (the world terrain) detach any section that loses its connection to
## the anchor row. Floating grids (BlockBody) split into separate bodies when a section
## is cut off. Detached sections keep their own grid, so they stay internally aligned
## while they tumble.

## Emitted after a batch of edits, once collision has been rebuilt.
signal changed
## Emitted when the last block is removed.
signal emptied

const CELL_SIZE := 16
const CHUNK_SIZE := 16 # Collision is rebuilt per chunk of CHUNK_SIZE x CHUNK_SIZE cells.
# Down comes last so support searches pop it first and reach the anchor row quickly.
const NEIGHBORS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

## Whether this grid is held in place (the world) rather than free-floating.
@export var anchored := false
## For anchored grids: cells at or below this row are fixed in place and unbreakable.
@export var anchor_row := 0
## For anchored grids: a section bigger than this is assumed to be supported, which
## keeps the search cheap. Bigger floating islands won't fall.
@export var support_search_limit := 4096

## Where detached sections are spawned.
var world: BlockWorld
## Cell -> numeric block id. Read freely, but edit through the methods below.
var cells: Dictionary[Vector2i, int] = {}

var _tiles := TileMapLayer.new()
var _chunk_owners: Dictionary[Vector2i, PackedInt32Array] = {}
var _dirty_chunks: Dictionary[Vector2i, bool] = {}
var _flush_queued := false


func _init() -> void:
	_tiles.name = "Tiles"
	_tiles.tile_set = Blocks.tile_set
	_tiles.collision_enabled = false # Collision is built from merged rectangles instead.
	add_child(_tiles)


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func global_to_cell(global_point: Vector2) -> Vector2i:
	return Vector2i((to_local(global_point) / CELL_SIZE).floor())


func has_block(cell: Vector2i) -> bool:
	return cells.has(cell)


func get_block(cell: Vector2i) -> int:
	return cells.get(cell, Blocks.AIR)


## Sets a cell without any structural checks. Use for generation and building bodies.
func set_block(cell: Vector2i, numeric_id: int) -> void:
	if numeric_id == Blocks.AIR:
		_erase_block(cell)
		return
	cells[cell] = numeric_id
	_tiles.set_cell(cell, Blocks.TILE_SOURCE, Blocks.atlas_coords(numeric_id))
	_mark_dirty(cell)


## Places a block, then drops it if nothing holds it up. Returns false if occupied.
func place_block(cell: Vector2i, numeric_id: int) -> bool:
	if cells.has(cell) or numeric_id == Blocks.AIR:
		return false
	set_block(cell, numeric_id)
	if anchored:
		_check_support([cell])
	return true


## Removes a block and detaches whatever it was holding together. Returns the removed
## id, or AIR if nothing was removed.
func remove_block(cell: Vector2i) -> int:
	var numeric_id := get_block(cell)
	if numeric_id == Blocks.AIR or (anchored and cell.y >= anchor_row):
		return Blocks.AIR
	_erase_block(cell)

	var neighbors: Array[Vector2i] = []
	for dir in NEIGHBORS:
		if cells.has(cell + dir):
			neighbors.append(cell + dir)
	if anchored:
		_check_support(neighbors)
	else:
		_check_split(neighbors)
	return numeric_id


func _erase_block(cell: Vector2i) -> void:
	if cells.erase(cell):
		_tiles.erase_cell(cell)
		_mark_dirty(cell)


#region Structure

## Detaches every section containing a seed that can't reach the anchor row.
func _check_support(seeds: Array[Vector2i]) -> void:
	var supported: Dictionary[Vector2i, bool] = {}
	for seed in seeds:
		if not cells.has(seed) or supported.has(seed):
			continue
		var section: Array[Vector2i] = [seed]
		var seen: Dictionary[Vector2i, bool] = {seed: true}
		var stack: Array[Vector2i] = [seed]
		var is_supported := false
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			# Touching a cell an earlier search proved supported means this one is too.
			if cell.y >= anchor_row or supported.has(cell) or section.size() > support_search_limit:
				is_supported = true
				break
			for dir in NEIGHBORS:
				var next := cell + dir
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					section.append(next)
					stack.append(next)
		if is_supported:
			for cell in section:
				supported[cell] = true
		else:
			_detach(section)


## Splits off every section except the largest into its own body.
func _check_split(seeds: Array[Vector2i]) -> void:
	if cells.is_empty():
		emptied.emit()
		return
	# The grid was connected before the removal, so the seeds' sections cover all of it.
	var sections: Array[Array] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for seed in seeds:
		if seen.has(seed):
			continue
		seen[seed] = true
		var section: Array[Vector2i] = [seed]
		var i := 0
		while i < section.size():
			for dir in NEIGHBORS:
				var next := section[i] + dir
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					section.append(next)
			i += 1
		sections.append(section)
	if sections.size() <= 1:
		return
	sections.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	for i in range(1, sections.size()):
		_detach(sections[i])


func _detach(section: Array[Vector2i]) -> void:
	var blocks: Dictionary[Vector2i, int] = {}
	for cell in section:
		blocks[cell] = cells[cell]
		_erase_block(cell)
	world.spawn_body(blocks, global_transform, get_parent() as RigidBody2D)

#endregion


#region Collision

func _mark_dirty(cell: Vector2i) -> void:
	_dirty_chunks[Vector2i(floori(cell.x / float(CHUNK_SIZE)), floori(cell.y / float(CHUNK_SIZE)))] = true
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	var body := get_parent() as CollisionObject2D
	for chunk in _dirty_chunks:
		_rebuild_chunk(body, chunk)
	_dirty_chunks.clear()
	changed.emit()


## Replaces a chunk's shapes with greedily merged rectangles.
func _rebuild_chunk(body: CollisionObject2D, chunk: Vector2i) -> void:
	for owner_id in _chunk_owners.get(chunk, PackedInt32Array()):
		body.remove_shape_owner(owner_id)

	var owners := PackedInt32Array()
	var origin := chunk * CHUNK_SIZE
	var end := origin + Vector2i(CHUNK_SIZE, CHUNK_SIZE)
	var covered: Dictionary[Vector2i, bool] = {}
	for y in range(origin.y, end.y):
		for x in range(origin.x, end.x):
			if not _is_uncovered(Vector2i(x, y), covered):
				continue
			var width := 1
			while x + width < end.x and _is_uncovered(Vector2i(x + width, y), covered):
				width += 1
			var height := 1
			while y + height < end.y and _is_row_uncovered(x, y + height, width, covered):
				height += 1
			for cy in range(y, y + height):
				for cx in range(x, x + width):
					covered[Vector2i(cx, cy)] = true
			owners.append(_add_rect(body, Rect2i(x, y, width, height)))

	if owners.is_empty():
		_chunk_owners.erase(chunk)
	else:
		_chunk_owners[chunk] = owners


func _is_uncovered(cell: Vector2i, covered: Dictionary[Vector2i, bool]) -> bool:
	return cells.has(cell) and not covered.has(cell)


func _is_row_uncovered(x: int, y: int, width: int, covered: Dictionary[Vector2i, bool]) -> bool:
	for cx in range(x, x + width):
		if not _is_uncovered(Vector2i(cx, y), covered):
			return false
	return true


func _add_rect(body: CollisionObject2D, rect: Rect2i) -> int:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect.size) * CELL_SIZE
	var center := (Vector2(rect.position) + Vector2(rect.size) * 0.5) * CELL_SIZE
	var owner_id := body.create_shape_owner(self)
	body.shape_owner_add_shape(owner_id, shape)
	body.shape_owner_set_transform(owner_id, transform * Transform2D(0.0, center))
	return owner_id

#endregion
