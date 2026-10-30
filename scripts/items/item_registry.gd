extends Node
## Autoload "Items": every ItemType in ITEMS_DIR, plus one for each block type.

const ITEMS_DIR := "res://data/items/"

var _types: Array[ItemType] = []
var _by_id: Dictionary[StringName, ItemType] = {}


func _enter_tree() -> void:
	var files := Array(ResourceLoader.list_directory(ITEMS_DIR))
	files.sort()
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var type := load(ITEMS_DIR + file) as ItemType
		if type == null:
			push_warning("%s is not an ItemType" % file)
			continue
		_register(type)
	for block_type in Blocks.all():
		if not _by_id.has(block_type.id):
			var item := ItemType.new()
			item.id = block_type.id
			item.display_name = block_type.display_name
			item.description = "A block. Machines can suck it up, pipe it around, and launch it."
			item.color = block_type.color
			item.block = block_type.id
			_register(item)


func _register(type: ItemType) -> void:
	_types.append(type)
	_by_id[type.id] = type


func all() -> Array[ItemType]:
	return _types


func get_type(id: StringName) -> ItemType:
	assert(_by_id.has(id), "Unknown item: %s" % id)
	return _by_id.get(id)
