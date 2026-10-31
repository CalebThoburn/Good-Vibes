class_name MachineSlot
extends Control
## One slot of the finished-machines bar. Drag the machine onto yourself to equip it,
## into the world to place it, or onto the workbench to edit it. Machines held by a
## workbench tidbit can be dropped here to take them out. A slot can carry a creature
## instead: drag it into the world to let it out, or onto a workbench tidbit that can
## hold it.

const SIZE := 52.0
const EQUIPPED_COLOR := Color(1.0, 0.85, 0.3)

var inventory: Inventory
var index := 0

var _shown: MachineDesign # Redrawn when it changes, e.g. a vacuum filling up.


## Starts dragging a machine. Set `from_cell` when it's held by a workbench tidbit.
static func drag_machine(source: Control, machine: MachineDesign, from_cell := MachineDesign.NO_CELL) -> Variant:
	source.set_drag_preview(MachineDrawer.make_preview(Vector2.ONE * SIZE, func(canvas: Control) -> void:
		MachineDrawer.draw_detailed(canvas, machine, Vector2.ZERO, SIZE / MachineDesign.SIZE)))
	var data := {kind = &"machine", machine = machine}
	if from_cell != MachineDesign.NO_CELL:
		data.from_cell = from_cell
	return data


## Starts dragging a creature. Set `from_cell` when it's held by a workbench tidbit.
static func drag_creature(source: Control, creature: StoredCreature, from_cell := MachineDesign.NO_CELL) -> Variant:
	source.set_drag_preview(MachineDrawer.make_preview(Vector2.ONE * SIZE * 0.6, func(canvas: Control) -> void:
		MachineDrawer.draw_creature(canvas, Rect2(Vector2.ZERO, canvas.size), creature)))
	var data := {kind = &"creature", creature = creature}
	if from_cell != MachineDesign.NO_CELL:
		data.from_cell = from_cell
	return data


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIZE


func _ready() -> void:
	inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func get_machine() -> MachineDesign:
	return inventory.machines[index] if index < inventory.machines.size() else null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CraftingGrid.BACKGROUND_COLOR)
	var creature := inventory.slot(index) as StoredCreature
	if creature:
		MachineDrawer.draw_creature(self, Rect2(Vector2.ZERO, size).grow(-6.0), creature)
		return
	var machine := get_machine()
	if machine == null:
		return
	var inset := 4.0
	var cell := (size.x - inset * 2.0) / MachineDesign.SIZE
	draw_rect(Rect2(Vector2.ONE * inset, Vector2.ONE * cell * MachineDesign.SIZE), MachineDrawer.FRAME_COLOR)
	MachineDrawer.draw_detailed(self, machine, Vector2.ONE * inset, cell)
	if machine == inventory.equipped:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), EQUIPPED_COLOR, false, 2.0)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var creature := inventory.slot(index) as StoredCreature
	if creature:
		return drag_creature(self, creature)
	var machine := get_machine()
	return drag_machine(self, machine) if machine else null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") in [&"machine", &"creature"] and data.has("from_cell")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data.kind == &"creature":
		inventory.unstore_creature(data.from_cell, data.creature)
	else:
		inventory.unstore_machine(data.from_cell, data.machine)


func _on_inventory_changed() -> void:
	var machine := get_machine()
	var creature := inventory.slot(index) as StoredCreature
	if creature:
		tooltip_text = "%s, alive. Drag into the world to let it out, or onto a tidbit that holds things." \
				% creature.display_name()
		queue_redraw()
		return
	if _shown != machine:
		if _shown:
			_shown.changed.disconnect(queue_redraw)
		if machine:
			machine.changed.connect(queue_redraw)
		_shown = machine
	if machine == null:
		tooltip_text = ""
	elif machine == inventory.equipped:
		tooltip_text = "Equipped. Drag onto yourself to unequip, into the world to place, or onto the workbench to edit."
	else:
		tooltip_text = "Drag onto yourself to equip, into the world to place, or onto the workbench to edit."
	queue_redraw()
