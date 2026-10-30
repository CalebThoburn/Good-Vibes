extends Node
## Autoload "Blocks": every BlockType in BLOCKS_DIR, plus the shared TileSet that
## all block grids draw with.

const AIR := 0
const BLOCKS_DIR := "res://data/blocks/"
const TILE_SOURCE := 0

var tile_set: TileSet

var _types: Array[BlockType] = [null] # Index is the numeric id; 0 is air.
var _ids: Dictionary[StringName, int] = {}


func _enter_tree() -> void:
	_load_types()
	_build_tile_set()


func get_type(numeric_id: int) -> BlockType:
	return _types[numeric_id]


func id_of(block_id: StringName) -> int:
	assert(_ids.has(block_id), "Unknown block type: %s" % block_id)
	return _ids.get(block_id, AIR)


func atlas_coords(numeric_id: int) -> Vector2i:
	return Vector2i(numeric_id - 1, 0)


func _load_types() -> void:
	var files := Array(ResourceLoader.list_directory(BLOCKS_DIR))
	files.sort() # Deterministic ids.
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var type := load(BLOCKS_DIR + file) as BlockType
		if type == null:
			push_warning("%s is not a BlockType" % file)
			continue
		type.numeric_id = _types.size()
		_ids[type.id] = type.numeric_id
		_types.append(type)


func _build_tile_set() -> void:
	var size := BlockGrid.CELL_SIZE
	var atlas := Image.create_empty(size * (_types.size() - 1), size, false, Image.FORMAT_RGBA8)
	for numeric_id in range(1, _types.size()):
		var image := _block_image(_types[numeric_id], size)
		atlas.blit_rect(image, Rect2i(0, 0, size, size), atlas_coords(numeric_id) * size)

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(size, size)
	for numeric_id in range(1, _types.size()):
		source.create_tile(atlas_coords(numeric_id))

	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	tile_set.add_source(source, TILE_SOURCE)


## Placeholder texture: the block's color with per-pixel noise, unless it has its own.
func _block_image(type: BlockType, size: int) -> Image:
	if type.texture:
		var custom := type.texture.get_image()
		custom.convert(Image.FORMAT_RGBA8)
		if custom.get_size() != Vector2i(size, size):
			custom.resize(size, size, Image.INTERPOLATE_NEAREST)
		return custom

	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(type.id)
	for y in size:
		for x in size:
			var shade := rng.randf_range(-1.0, 1.0) * type.texture_noise
			image.set_pixel(x, y, type.color.lightened(shade) if shade > 0.0 else type.color.darkened(-shade))
	return image
