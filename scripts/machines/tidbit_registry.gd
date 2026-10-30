extends Node
## Autoload "Tidbits": every TidbitType in TIDBITS_DIR.

const TIDBITS_DIR := "res://data/tidbits/"

var _types: Array[TidbitType] = []
var _by_id: Dictionary[StringName, TidbitType] = {}


func _enter_tree() -> void:
	var files := Array(ResourceLoader.list_directory(TIDBITS_DIR))
	files.sort()
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var type := load(TIDBITS_DIR + file) as TidbitType
		if type == null:
			push_warning("%s is not a TidbitType" % file)
			continue
		_types.append(type)
		_by_id[type.id] = type


func all() -> Array[TidbitType]:
	return _types


func get_type(id: StringName) -> TidbitType:
	assert(_by_id.has(id), "Unknown tidbit: %s" % id)
	return _by_id.get(id)
