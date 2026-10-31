class_name CraftingGrid
extends Control
## The workbench grid. Drag tidbits in and around, R rotates the hovered tidbit (or
## switches its setting, for tidbits like triggers), and
## right-clicking two ports (or two valves) links them. Linking them again unlinks them.
## Items dropped on a tidbit attach to it if they're an upgrade for it, or are loaded
## into its storage if it holds them (wood into a lantern, blocks into a launcher).
## Badges show attached upgrades and, tinted, whatever the tidbit holds; drag a badge to
## take it off or move it to another tidbit.

const CELL := 56.0
const CONNECTOR_PICK_RADIUS := 10.0
const NOT_LINKING := -1
const BACKGROUND_COLOR := Color(0.1, 0.1, 0.12)
const LINE_COLOR := Color(1, 1, 1, 0.08)

var inventory: Inventory:
	set(value):
		inventory = value
		inventory.changed.connect(_on_inventory_changed)
var design: MachineDesign:
	get:
		return inventory.workbench

var _hover_cell := MachineDesign.NO_CELL
var _link_kind := NOT_LINKING
var _link_start := Vector3i.ZERO


func _init() -> void:
	custom_minimum_size = Vector2.ONE * CELL * MachineDesign.SIZE
	tooltip_text = " " # Enables _get_tooltip().


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	for i in range(1, MachineDesign.SIZE):
		draw_line(Vector2(i * CELL, 0), Vector2(i * CELL, size.y), LINE_COLOR)
		draw_line(Vector2(0, i * CELL), Vector2(size.x, i * CELL), LINE_COLOR)
	if _hover_cell != MachineDesign.NO_CELL:
		draw_rect(_cell_rect(_hover_cell), Color(1, 1, 1, 0.06))
	MachineDrawer.draw_detailed(self, design, Vector2.ZERO, CELL)
	if _link_kind != NOT_LINKING:
		draw_line(design.connector_point(_link_kind, _link_start) * CELL, get_local_mouse_position(),
				MachineDrawer.link_color(_link_kind), 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_cell = _cell_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_click_connector(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	# Rotating works by hovering, without the grid needing focus.
	if event.is_action_pressed(&"rotate") and is_visible_in_tree() and design.tidbits.has(_hover_cell):
		inventory.turn_tidbit(_hover_cell)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = MachineDesign.NO_CELL
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		_link_kind = NOT_LINKING


func _get_tooltip(at_position: Vector2) -> String:
	var cell := _cell_at(at_position)
	var type := design.get_tidbit(cell)
	if type == null:
		return ""
	var lines := PackedStringArray([type.display_name, type.description])
	for item_id: StringName in design.items_on(cell):
		lines.append("%s ×%d" % [Items.get_type(item_id).display_name, design.item_count(cell, item_id)])
	if type.storage > 0:
		var held := PackedStringArray()
		for item_id: StringName in design.stored_on(cell):
			held.append("%s ×%d" % [Items.get_type(item_id).display_name, design.stored_count(cell, item_id)])
		if not design.machines_in(cell).is_empty():
			held.append("Machine ×%d" % design.machines_in(cell).size())
		for creature: StoredCreature in design.creatures_in(cell):
			held.append("%s (alive)" % creature.display_name())
		lines.append("Holds (%d/%d): %s" % [type.storage - design.store_room(cell), type.storage,
				", ".join(held) if held else "nothing"])
	var status := type.get_status(design, cell)
	if status:
		lines.append(status)
	var problem := type.get_problem(design, cell)
	if problem:
		lines.append("⚠ " + problem)
	return "\n".join(lines)


func _get_drag_data(at_position: Vector2) -> Variant:
	var cell := _cell_at(at_position)
	var badge := _badge_at(at_position)
	match badge.get("kind"):
		&"attached":
			return ItemSlot.drag_item(self, Items.get_type(badge.id), design.item_count(cell, badge.id), cell)
		&"stored":
			return ItemSlot.drag_item(self, Items.get_type(badge.id), design.stored_count(cell, badge.id), cell, true)
		&"machine":
			return MachineSlot.drag_machine(self, badge.machine, cell)
		&"creature":
			return MachineSlot.drag_creature(self, badge.creature, cell)
	var type := design.get_tidbit(cell)
	if type == null:
		return null
	var rotation_steps := design.get_rotation(cell)
	var setting := design.get_setting(cell)
	set_drag_preview(MachineDrawer.make_preview(Vector2.ONE * CELL, func(canvas: Control) -> void:
		type.draw(canvas, Rect2(Vector2.ZERO, canvas.size), rotation_steps, setting)))
	return {kind = &"tidbit", type = type, from_cell = cell}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var cell := _cell_at(at_position)
	match data.get("kind"):
		&"tidbit":
			return cell != MachineDesign.NO_CELL and not design.tidbits.has(cell)
		&"machine":
			return design.is_empty() and not data.has("from_cell")
		&"item":
			return cell != data.get("from_cell") and inventory.takes_item(cell, data.item.id)
		&"creature":
			var type := design.get_tidbit(cell)
			return cell != data.get("from_cell") and type != null and design.store_room(cell) > 0 \
					and type.can_store(data.creature)
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data.kind == &"machine":
		inventory.edit_machine(data.machine)
	elif data.kind == &"creature":
		if data.has("from_cell"): # From one tidbit to another.
			design.unstore(data.from_cell, data.creature)
			design.store(_cell_at(at_position), data.creature)
			inventory.changed.emit()
		else:
			inventory.store_creature(_cell_at(at_position), data.creature)
	elif data.kind == &"item":
		if data.has("from_cell"): # Off the tidbit it was on first; anything that won't fit stays in the inventory.
			if data.stored:
				inventory.unstore_item(data.from_cell, data.item.id, data.amount)
			else:
				inventory.detach_item(data.from_cell, data.item.id, data.amount)
		inventory.put_item(_cell_at(at_position), data.item.id, data.amount)
	elif data.has("from_cell"):
		inventory.move_tidbit(data.from_cell, _cell_at(at_position))
	else:
		inventory.place_tidbit(_cell_at(at_position), data.type)


func _click_connector(at_position: Vector2) -> void:
	var hit := _connector_at(at_position)
	if hit.is_empty():
		_link_kind = NOT_LINKING
	elif _link_kind == hit[0]:
		var kind := _link_kind
		_link_kind = NOT_LINKING
		inventory.toggle_link(kind, _link_start, hit[1])
	else:
		_link_kind = hit[0]
		_link_start = hit[1]
	queue_redraw()


## [kind, connector] of the port or valve near a point, or [] if there is none.
func _connector_at(at_position: Vector2) -> Array:
	for kind: MachineDesign.Link in MachineDesign.Link.values():
		for connector in design.connectors(kind):
			if (design.connector_point(kind, connector) * CELL).distance_to(at_position) <= CONNECTOR_PICK_RADIUS:
				return [kind, connector]
	return []


## The badge (see MachineDrawer.badges) under a point, or {} if there is none.
func _badge_at(at_position: Vector2) -> Dictionary:
	var cell := _cell_at(at_position)
	var all := MachineDrawer.badges(design, cell)
	for i in all.size():
		if MachineDrawer.badge_rect(cell, i, Vector2.ZERO, CELL).has_point(at_position):
			return all[i]
	return {}


func _cell_at(at_position: Vector2) -> Vector2i:
	var cell := Vector2i((at_position / CELL).floor())
	return cell if MachineDesign.contains(cell) else MachineDesign.NO_CELL


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL)


func _on_inventory_changed() -> void:
	# The half-made link may point at a tidbit that moved or left.
	_link_kind = NOT_LINKING
	queue_redraw()
