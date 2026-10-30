class_name Inventory
extends RefCounted
## What the player carries: loose tidbits and items, the design on the workbench, and
## finished machines (one of which may be equipped).

signal changed

const MACHINE_SLOTS := 8

var tidbits: Dictionary[StringName, int] = {}
var items: Dictionary[StringName, int] = {}
var machines: Array[MachineDesign] = []
var workbench := MachineDesign.new()
var equipped: MachineDesign


func count_of(id: StringName) -> int:
	return tidbits.get(id, 0)


func add_tidbits(id: StringName, amount := 1) -> void:
	tidbits[id] = count_of(id) + amount
	changed.emit()


func item_count(id: StringName) -> int:
	return items.get(id, 0)


func add_items(id: StringName, amount := 1) -> void:
	items[id] = item_count(id) + amount
	changed.emit()


#region Workbench

func place_tidbit(cell: Vector2i, type: TidbitType) -> bool:
	if count_of(type.id) <= 0 or not MachineDesign.contains(cell) or workbench.tidbits.has(cell):
		return false
	tidbits[type.id] -= 1
	workbench.place(cell, type)
	changed.emit()
	return true


## Takes a tidbit off the workbench and back into the inventory, with everything
## attached to it or held by it. Fails if the machines it holds won't fit.
func return_tidbit(cell: Vector2i) -> bool:
	var held_machines := workbench.machines_in(cell).duplicate()
	if machines.size() + held_machines.size() > MACHINE_SLOTS:
		return false
	var contents: Array[Dictionary] = [workbench.items_on(cell).duplicate(), workbench.stored_on(cell).duplicate()]
	var type := workbench.remove(cell)
	if type:
		tidbits[type.id] = count_of(type.id) + 1
	for counts in contents:
		for item_id: StringName in counts:
			items[item_id] = item_count(item_id) + counts[item_id]
	machines.append_array(held_machines)
	changed.emit()
	return true


## Attaches up to `amount` of an item to a workbench tidbit. Returns how many it attached.
func attach_item(cell: Vector2i, item_id: StringName, amount: int) -> int:
	amount = mini(amount, mini(item_count(item_id), workbench.item_room(cell, item_id)))
	if amount <= 0:
		return 0
	items[item_id] -= amount
	workbench.add_item(cell, item_id, amount)
	changed.emit()
	return amount


## Takes up to `amount` of an item off a workbench tidbit and back into the inventory.
func detach_item(cell: Vector2i, item_id: StringName, amount: int) -> void:
	amount = mini(amount, workbench.item_count(cell, item_id))
	if amount <= 0:
		return
	workbench.remove_item(cell, item_id, amount)
	add_items(item_id, amount)


## Takes up to `amount` of an item a workbench tidbit holds into the inventory.
func unstore_item(cell: Vector2i, item_id: StringName, amount: int) -> void:
	amount = mini(amount, workbench.stored_count(cell, item_id))
	if amount <= 0:
		return
	workbench.unstore(cell, item_id, amount)
	add_items(item_id, amount)


## Takes a machine a workbench tidbit holds into the machine bar, if there's room.
func unstore_machine(cell: Vector2i, machine: MachineDesign) -> bool:
	if not workbench.machines_in(cell).has(machine) or not add_machine(machine):
		return false
	workbench.unstore(cell, machine)
	return true


func move_tidbit(from: Vector2i, to: Vector2i) -> bool:
	if from == to or not MachineDesign.contains(to) or workbench.tidbits.has(to):
		return false
	workbench.move(from, to)
	changed.emit()
	return true


## Rotates a workbench tidbit, or switches its setting if it has settings.
func turn_tidbit(cell: Vector2i) -> void:
	if workbench.get_tidbit(cell).settings.is_empty():
		workbench.rotate(cell)
	else:
		workbench.cycle_setting(cell)
	changed.emit()


func toggle_link(kind: MachineDesign.Link, a: Vector3i, b: Vector3i) -> void:
	workbench.toggle_link(kind, a, b)
	changed.emit()


## Returns every tidbit to the inventory. False if some held machines didn't fit.
func clear_workbench() -> bool:
	var all_returned := true
	for cell in workbench.tidbits.keys():
		all_returned = return_tidbit(cell) and all_returned
	return all_returned


## Turns the workbench design into a finished machine.
func build() -> bool:
	if workbench.is_empty() or not add_machine(workbench):
		return false
	workbench = MachineDesign.new()
	changed.emit()
	return true


## Moves a finished machine back onto the (empty) workbench for editing.
func edit_machine(machine: MachineDesign) -> bool:
	if not workbench.is_empty():
		return false
	remove_machine(machine)
	workbench = machine
	changed.emit()
	return true

#endregion


#region Machines

func add_machine(machine: MachineDesign) -> bool:
	if machines.size() >= MACHINE_SLOTS:
		return false
	machines.append(machine)
	changed.emit()
	return true


func remove_machine(machine: MachineDesign) -> void:
	machines.erase(machine)
	if equipped == machine:
		equipped = null
	changed.emit()


## Equips a machine, or unequips with null. Fails if the machine has no handle.
func equip(machine: MachineDesign) -> bool:
	if machine and not machine.can_equip():
		return false
	equipped = machine
	changed.emit()
	return true

#endregion
