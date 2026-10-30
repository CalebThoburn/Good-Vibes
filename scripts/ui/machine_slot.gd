class_name MachineSlot
extends Control
## One slot of the finished-machines bar. Drag the machine onto yourself to equip it,
## into the world to place it, or onto the workbench to edit it.

const SIZE := 52.0
const EQUIPPED_COLOR := Color(1.0, 0.85, 0.3)

var inventory: Inventory
var index := 0


func _init() -> void:
	custom_minimum_size = Vector2.ONE * SIZE


func _ready() -> void:
	inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func get_machine() -> MachineDesign:
	return inventory.machines[index] if index < inventory.machines.size() else null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CraftingGrid.BACKGROUND_COLOR)
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
	var machine := get_machine()
	if machine == null:
		return null
	set_drag_preview(MachineDrawer.make_preview(Vector2.ONE * SIZE, func(canvas: Control) -> void:
		MachineDrawer.draw_detailed(canvas, machine, Vector2.ZERO, SIZE / MachineDesign.SIZE)))
	return {kind = &"machine", machine = machine}


func _on_inventory_changed() -> void:
	var machine := get_machine()
	if machine == null:
		tooltip_text = ""
	elif machine == inventory.equipped:
		tooltip_text = "Equipped. Drag onto yourself to unequip, into the world to place, or onto the workbench to edit."
	else:
		tooltip_text = "Drag onto yourself to equip, into the world to place, or onto the workbench to edit."
	queue_redraw()
