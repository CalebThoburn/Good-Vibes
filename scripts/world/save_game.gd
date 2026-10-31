class_name SaveGame
extends Node
## Keeps the world between runs: the terrain, loose blocks, placed machines, water and
## blood, plants, creatures, the player's inventory and position, and the time of day. Saves every AUTOSAVE_INTERVAL,
## when the game closes, and on the save action (F5); loads at start if there's a save.
## The new_world action (F8) deletes the save and starts afresh.

const PATH := "user://save.dat"
## Bumped when the format changes in a way old saves can't be read with.
const VERSION := 3
const AUTOSAVE_INTERVAL := 30.0

@export var world: BlockWorld
@export var player: Player
@export var sky: SkyLayer

var _autosave_wait := AUTOSAVE_INTERVAL


static func exists() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = file.get_var() if file else null
	return data is Dictionary and data.get("version") == VERSION


func _ready() -> void:
	if exists():
		_load()
		player.notify("Loaded the saved world (F8 for a new one)")


func _process(delta: float) -> void:
	_autosave_wait -= delta
	if _autosave_wait <= 0.0:
		save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"save_game"):
		save()
		player.notify("Saved")
	elif event.is_action_pressed(&"new_world"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		_autosave_wait = INF # Don't save the old world back over it on the way out.
		get_tree().reload_current_scene()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _autosave_wait != INF:
		save()


func save() -> void:
	_autosave_wait = AUTOSAVE_INTERVAL
	var bodies := []
	for body in world.loose_bodies():
		var entry := {transform = body.global_transform, velocity = body.linear_velocity, spin = body.angular_velocity}
		if body is BlockBody:
			entry.blocks = _blocks_to_data(body.grid.cells)
		else:
			entry.machine = body.view.machine.design.to_data()
		bodies.append(entry)
	var data := {
		version = VERSION,
		terrain = _blocks_to_data(world.terrain.cells),
		bodies = bodies,
		plants = world.flora.to_data(),
		creatures = world.fauna.to_data(),
		liquids = world.liquids.to_data(),
		inventory = player.inventory.to_data(),
		player = {position = player.global_position, velocity = player.velocity},
		days = sky._days,
	}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)


func _load() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: Dictionary = file.get_var()
	var terrain := _blocks_from_data(data.terrain)
	for cell in terrain:
		world.terrain.set_block(cell, terrain[cell])
	for entry: Dictionary in data.bodies:
		var body: RigidBody2D
		if entry.has("blocks"):
			body = world.spawn_body(_blocks_from_data(entry.blocks), entry.transform)
		else:
			body = world.spawn_machine(MachineDesign.from_data(entry.machine), entry.transform.origin)
			body.rotation = entry.transform.get_rotation()
		body.linear_velocity = entry.velocity
		body.angular_velocity = entry.spin
	world.liquids.load_data(data.liquids)
	world.flora.load_data(data.plants)
	if data.has("creatures"):
		world.fauna.load_data(data.creatures)
	else: # Saved before there were creatures.
		world.fauna.populate(world.world_seed)
	player.inventory.load_data(data.inventory)
	player.global_position = data.player.position
	player.velocity = data.player.velocity
	sky._days = data.days


## Blocks by name rather than number, so saves survive new block types.
static func _blocks_to_data(cells: Dictionary) -> Dictionary:
	var palette: Array[StringName] = []
	var packed := PackedInt32Array()
	for cell: Vector2i in cells:
		var id := Blocks.get_type(cells[cell]).id
		var index := palette.find(id)
		if index < 0:
			index = palette.size()
			palette.append(id)
		packed.append_array([cell.x, cell.y, index])
	return {palette = palette, cells = packed}


static func _blocks_from_data(data: Dictionary) -> Dictionary[Vector2i, int]:
	var numeric: Array = data.palette.map(func(id: StringName) -> int: return Blocks.id_of(id))
	var cells: Dictionary[Vector2i, int] = {}
	for i in range(0, data.cells.size(), 3):
		cells[Vector2i(data.cells[i], data.cells[i + 1])] = numeric[data.cells[i + 2]]
	return cells
