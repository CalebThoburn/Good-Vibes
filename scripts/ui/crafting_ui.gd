class_name CraftingUI
extends CanvasLayer
## The workbench screen, toggled with the craft action (E).

@export var player: Player

@onready var _grid: CraftingGrid = %Grid
@onready var _tidbits: Container = %Tidbits
@onready var _items: Container = %Items
@onready var _machines: Container = %Machines


func _ready() -> void:
	var inventory := player.inventory
	_grid.inventory = inventory
	$WorldDropZone.player = player
	%ItemShelf.inventory = inventory
	for type in Tidbits.all():
		var slot := TidbitSlot.new()
		slot.inventory = inventory
		slot.type = type
		_tidbits.add_child(slot)
	for type in Items.all():
		var slot := ItemSlot.new()
		slot.inventory = inventory
		slot.type = type
		_items.add_child(slot)
	for i in Inventory.MACHINE_SLOTS:
		var slot := MachineSlot.new()
		slot.inventory = inventory
		slot.index = i
		_machines.add_child(slot)
	%Build.pressed.connect(_on_build_pressed)
	%Clear.pressed.connect(_on_clear_pressed)
	_set_open(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"craft"):
		_set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	visible = open
	player.ui_open = open


func _on_build_pressed() -> void:
	var inventory := player.inventory
	if inventory.workbench.is_empty():
		player.notify("Put some tidbits on the workbench first")
	elif not inventory.build():
		player.notify("No free machine slots")


func _on_clear_pressed() -> void:
	if not player.inventory.clear_workbench():
		player.notify("No free machine slots for the machines some tidbits hold")
