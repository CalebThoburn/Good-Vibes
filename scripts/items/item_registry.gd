extends Node
## Autoload "Items": every ItemType in ITEMS_DIR.

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
		_types.append(type)
		_by_id[type.id] = type


func all() -> Array[ItemType]:
	return _types


func get_type(id: StringName) -> ItemType:
	assert(_by_id.has(id), "Unknown item: %s" % id)
	return _by_id.get(id)
