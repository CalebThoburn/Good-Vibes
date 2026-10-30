class_name MachineDrawer
## Draws machine designs: small and plain in the world, with ports and links in the UI.

const FRAME_COLOR := Color(0.16, 0.15, 0.17)
const PROBLEM_COLOR := Color(1.0, 0.25, 0.2)
const WIRE_COLOR := Color(1.0, 0.82, 0.2)
const PIPE_COLOR := Color(0.3, 0.6, 1.0)


static func link_color(kind: MachineDesign.Link) -> Color:
	return WIRE_COLOR if kind == MachineDesign.Link.WIRE else PIPE_COLOR


## In machine space: MachineDesign.SIZE * TIDBIT_PIXELS square, centered on the origin.
static func draw_world(canvas: CanvasItem, design: MachineDesign) -> void:
	var size := MachineDesign.SIZE * MachineDesign.TIDBIT_PIXELS
	var origin := -Vector2.ONE * size * 0.5
	canvas.draw_rect(Rect2(origin, Vector2.ONE * size), FRAME_COLOR)
	draw_tidbits(canvas, design, origin, MachineDesign.TIDBIT_PIXELS)


static func draw_tidbits(canvas: CanvasItem, design: MachineDesign, origin: Vector2, cell_size: float) -> void:
	for cell in design.tidbits:
		var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		design.tidbits[cell].draw(canvas, rect, design.get_rotation(cell))


## Tidbits plus problem outlines, links, and connectors.
static func draw_detailed(canvas: CanvasItem, design: MachineDesign, origin: Vector2, cell_size: float) -> void:
	draw_tidbits(canvas, design, origin, cell_size)
	for cell in design.tidbits:
		if not design.tidbits[cell].get_problem(design, cell).is_empty():
			var rect := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
			canvas.draw_rect(rect.grow(-1.0), PROBLEM_COLOR, false, maxf(cell_size * 0.05, 1.0))
		_draw_item_badges(canvas, design, cell, origin, cell_size)

	var width := maxf(cell_size * 0.06, 1.0)
	var radius := maxf(cell_size * 0.09, 1.5)
	for kind: MachineDesign.Link in MachineDesign.Link.values():
		var color := link_color(kind)
		var list := design.links(kind)
		for i in range(0, list.size(), 2):
			canvas.draw_line(origin + design.connector_point(kind, list[i]) * cell_size,
					origin + design.connector_point(kind, list[i + 1]) * cell_size, color, width)
		for connector in design.connectors(kind):
			var point := origin + design.connector_point(kind, connector) * cell_size
			canvas.draw_circle(point, radius, Color.BLACK)
			canvas.draw_circle(point, radius * 0.65, color)


## Where the badge for the index-th item attached to a cell sits.
static func item_badge_rect(cell: Vector2i, index: int, origin: Vector2, cell_size: float) -> Rect2:
	var badge := cell_size * 0.36
	return Rect2(origin + Vector2(cell) * cell_size + Vector2(index * badge, cell_size - badge),
			Vector2.ONE * badge)


static func _draw_item_badges(canvas: CanvasItem, design: MachineDesign, cell: Vector2i, origin: Vector2, cell_size: float) -> void:
	var attached := design.items_on(cell)
	var font := ThemeDB.fallback_font
	for i in attached.size():
		var item_id: StringName = attached.keys()[i]
		var rect := item_badge_rect(cell, i, origin, cell_size)
		canvas.draw_rect(rect, Color(0, 0, 0, 0.55))
		Items.get_type(item_id).draw(canvas, rect)
		if cell_size >= 40.0: # Too small to read in the machine bar.
			var baseline := Vector2(rect.position.x, rect.end.y - 1.0)
			var count := str(attached[item_id])
			canvas.draw_string_outline(font, baseline, count, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, 10, 3, Color.BLACK)
			canvas.draw_string(font, baseline, count, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x, 10)


## A drag preview centered on the cursor. `draw_fn` is called with the canvas to draw on.
static func make_preview(size: Vector2, draw_fn: Callable) -> Control:
	var canvas := Control.new()
	canvas.size = size
	canvas.position = -size * 0.5
	canvas.modulate.a = 0.85
	canvas.draw.connect(draw_fn.bind(canvas))
	var holder := Control.new()
	holder.add_child(canvas)
	return holder
