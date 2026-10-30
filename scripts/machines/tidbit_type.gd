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
## Upgrades that can be attached on the workbench, and how many of each.
@export var accepted_items: Dictionary[StringName, int] = {}
## How many things (items or machines) it can hold, delivered by pipe or suction.
@export var storage := 0
## Modes the player switches between with R on the workbench (instead of rotating), shown
## on the tidbit. Empty for tidbits that rotate.
@export var settings: PackedStringArray = []


## Whether this tidbit will hold a thing: an item id or a MachineDesign.
func can_store(_thing: Variant) -> bool:
	return false


## Whether a machine with this tidbit can be equipped.
func allows_equip() -> bool:
	return false


## Handles one input, a tick after it arrived. `input` is a port index, or
## Machine.activation_input(channel) when the player presses an activation key.
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


func draw(canvas: CanvasItem, rect: Rect2, rotation_steps: int, setting := 0) -> void:
	canvas.draw_rect(rect.grow(-rect.size.x * 0.05), color)
	# Glyphs are drawn in a unit square centered on the cell, facing right.
	canvas.draw_set_transform(rect.get_center(), rotation_steps * PI / 2.0, rect.size)
	_draw_glyph(canvas)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if not settings.is_empty() and rect.size.x >= 48.0: # Workbench size; too cluttered smaller.
		var font := ThemeDB.fallback_font
		var font_size := roundi(rect.size.x * 0.22)
		var baseline := Vector2(rect.position.x, rect.end.y - rect.size.y * 0.08)
		canvas.draw_string_outline(font, baseline, settings[setting], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, 3, Color.BLACK)
		canvas.draw_string(font, baseline, settings[setting], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size)


func _draw_glyph(_canvas: CanvasItem) -> void:
	pass
