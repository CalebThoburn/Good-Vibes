class_name MachineDesign
extends Resource
## The layout of a machine: which tidbit sits in each cell of its grid, which way each
## faces, and how their ports (wires) and valves (pipes) are linked.

enum Link { WIRE, PIPE }

const SIZE := 4
## Size of one tidbit when the machine is out in the world.
const TIDBIT_PIXELS := 4
const NO_CELL := Vector2i(-1, -1)
## Facing for each rotation step.
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

@export var tidbits: Dictionary[Vector2i, TidbitType] = {}
@export var rotations: Dictionary[Vector2i, int] = {}
## Items attached to each tidbit: cell -> {item id: count}.
@export var items: Dictionary[Vector2i, Dictionary] = {}
## Linked connectors in pairs [a0, b0, a1, b1, ...]. A connector is
## Vector3i(cell.x, cell.y, port or valve index).
@export var wires: Array[Vector3i] = []
@export var pipes: Array[Vector3i] = []


## Center of a cell in machine space: pixels, with the machine's center at the origin.
static func cell_position(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5) - Vector2.ONE * SIZE * 0.5) * TIDBIT_PIXELS


static func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE


func is_empty() -> bool:
	return tidbits.is_empty()


func get_tidbit(cell: Vector2i) -> TidbitType:
	return tidbits.get(cell)


func get_rotation(cell: Vector2i) -> int:
	return rotations.get(cell, 0)


func facing(cell: Vector2i) -> Vector2i:
	return DIRECTIONS[get_rotation(cell)]


func cells_to_edge(cell: Vector2i, direction: Vector2i) -> int:
	var steps := 0
	while contains(cell + direction * (steps + 1)):
		steps += 1
	return steps


## Whether no tidbit sits between a cell and the edge of the grid in a direction.
func is_clear_to_edge(cell: Vector2i, direction: Vector2i) -> bool:
	for step in range(1, cells_to_edge(cell, direction) + 1):
		if tidbits.has(cell + direction * step):
			return false
	return true


func can_equip() -> bool:
	return find_handle() != NO_CELL


func find_handle() -> Vector2i:
	for cell in tidbits:
		if tidbits[cell].allows_equip():
			return cell
	return NO_CELL


func place(cell: Vector2i, type: TidbitType, rotation_steps := 0) -> void:
	tidbits[cell] = type
	rotations[cell] = rotation_steps


func remove(cell: Vector2i) -> TidbitType:
	var type := get_tidbit(cell)
	tidbits.erase(cell)
	rotations.erase(cell)
	items.erase(cell)
	for list: Array[Vector3i] in [wires, pipes]:
		var i := list.size() - 2
		while i >= 0:
			if _cell_of(list[i]) == cell or _cell_of(list[i + 1]) == cell:
				list.remove_at(i + 1)
				list.remove_at(i)
			i -= 2
	return type


## Moves a tidbit to an empty cell, keeping its links.
func move(from: Vector2i, to: Vector2i) -> void:
	place(to, tidbits[from], get_rotation(from))
	if items.has(from):
		items[to] = items[from]
	tidbits.erase(from)
	rotations.erase(from)
	items.erase(from)
	for list: Array[Vector3i] in [wires, pipes]:
		for i in list.size():
			if _cell_of(list[i]) == from:
				list[i] = Vector3i(to.x, to.y, list[i].z)


func rotate(cell: Vector2i) -> void:
	rotations[cell] = (get_rotation(cell) + 1) % DIRECTIONS.size()


## Items attached to a tidbit, as {item id: count}. Don't modify the result.
func items_on(cell: Vector2i) -> Dictionary:
	return items.get(cell, {})


func item_count(cell: Vector2i, item_id: StringName) -> int:
	return items_on(cell).get(item_id, 0)


## How many more of an item a tidbit can take.
func item_room(cell: Vector2i, item_id: StringName) -> int:
	var type := get_tidbit(cell)
	return type.accepted_items.get(item_id, 0) - item_count(cell, item_id) if type else 0


func add_item(cell: Vector2i, item_id: StringName, amount: int) -> void:
	if not items.has(cell):
		items[cell] = {}
	items[cell][item_id] = item_count(cell, item_id) + amount


func remove_item(cell: Vector2i, item_id: StringName, amount: int) -> void:
	var left := item_count(cell, item_id) - amount
	if left > 0:
		items[cell][item_id] = left
		return
	items_on(cell).erase(item_id)
	if items_on(cell).is_empty():
		items.erase(cell)


func links(kind: Link) -> Array[Vector3i]:
	return wires if kind == Link.WIRE else pipes


## Every port (WIRE) or valve (PIPE) in the design.
func connectors(kind: Link) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell in tidbits:
		for i in _layout(kind, tidbits[cell]).size():
			result.append(Vector3i(cell.x, cell.y, i))
	return result


## Where a connector sits, in grid units (0 to SIZE on each axis).
func connector_point(kind: Link, connector: Vector3i) -> Vector2:
	var cell := _cell_of(connector)
	var local: Vector2 = _layout(kind, get_tidbit(cell))[connector.z]
	var half := Vector2(0.5, 0.5)
	return Vector2(cell) + half + (local - half).rotated(get_rotation(cell) * PI / 2.0)


func linked(kind: Link, connector: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var list := links(kind)
	for i in range(0, list.size(), 2):
		if list[i] == connector:
			result.append(list[i + 1])
		elif list[i + 1] == connector:
			result.append(list[i])
	return result


## Links two connectors, or unlinks them if they already are.
func toggle_link(kind: Link, a: Vector3i, b: Vector3i) -> void:
	if a == b:
		return
	var list := links(kind)
	for i in range(0, list.size(), 2):
		if (list[i] == a and list[i + 1] == b) or (list[i] == b and list[i + 1] == a):
			list.remove_at(i + 1)
			list.remove_at(i)
			return
	list.append(a)
	list.append(b)


func _layout(kind: Link, type: TidbitType) -> Array[Vector2]:
	return type.ports if kind == Link.WIRE else type.valves


func _cell_of(connector: Vector3i) -> Vector2i:
	return Vector2i(connector.x, connector.y)
