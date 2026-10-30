class_name TidbitType
extends Resource
## One kind of tidbit, the parts machines are built from. Each kind is a script extending
## this one plus a .tres in res://data/tidbits/, which the Tidbits registry picks up.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color := Color.WHITE
## Signal ports, as positions inside the tidbit's cell (0-1) while it faces right.
@export var ports: Array[Vector2] = []
## Pipe valves, laid out the same way as ports.
@export var valves: Array[Vector2] = []
## Items this tidbit can hold, and how many of each.
@export var accepted_items: Dictionary[StringName, int] = {}


## Whether a machine with this tidbit can be equipped.
func allows_equip() -> bool:
	return false


## Handles one input, a tick after it arrived. `input` is a port index, or
## Machine.ACTIVATE when the player activates the machine.
func on_input(_machine: Machine, _cell: Vector2i, _input: int) -> void:
	pass


## Runs every tick after inputs are handled, for tidbits that act on their own (keep
## any state in machine.states).
func on_tick(_machine: Machine, _cell: Vector2i) -> void:
	pass


## Why this tidbit won't work where it is, or "" if it's fine.
func get_problem(_design: MachineDesign, _cell: Vector2i) -> String:
	return ""


## Extra info for the tooltip, such as what attached items are doing, or "".
func get_status(_design: MachineDesign, _cell: Vector2i) -> String:
	return ""


func draw(canvas: CanvasItem, rect: Rect2, rotation_steps: int) -> void:
	canvas.draw_rect(rect.grow(-rect.size.x * 0.05), color)
	# Glyphs are drawn in a unit square centered on the cell, facing right.
	canvas.draw_set_transform(rect.get_center(), rotation_steps * PI / 2.0, rect.size)
	_draw_glyph(canvas)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_glyph(_canvas: CanvasItem) -> void:
	pass
