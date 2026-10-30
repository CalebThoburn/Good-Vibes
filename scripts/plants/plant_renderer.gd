class_name PlantRenderer
## Draws plants as blocky pixel art at the blocks' density (one texel per world pixel).
## Stems and roots are axis-aligned bars of speckled bark with a shaded edge. A tree's
## leaves are squares (its main leaf masses, lumpy clusters of squares), and all the
## leaves in one layer are drawn as a single shape shaded like the clouds (lit along the
## top, shaded underneath), so overlapping leaves merge into bunches. Inside, they carry
## a pattern of darker and lighter clumps, like Minecraft's leaves. Grass leaves are blades, and where grass climbs a step it fills the
## inside corner with a little curve.

## Pass as `depth` to draw parts at every depth.
const ANY_DEPTH := 99
const LEAF_VARIANTS := 3
## Leaves are drawn in this many steps between healthy and dying colors.
const DECLINE_LEVELS := 4
const BARK_TILE := 128
const SPECKLE := 0.12
## Radius of the curve grass fills step corners with, in pixels.
const FILLET := 5
const LEAF_TILE := 32

# Generated bark speckle, keyed by [species id, kind].
static var _bark_tiles: Dictionary = {}
# Generated leaf clump patterns (-1 dark, 0 plain, 1 light per pixel), keyed by species id.
static var _leaf_tiles: Dictionary = {}


## Renders stems or roots at one depth into an image, plus withered leaves if LEAF is in
## `kinds` (for debris). Returns [texture, top-left of the texture in plant space], or
## [null, ZERO] if there's nothing to draw.
static func render(species: PlantSpecies, parts: Array[PlantPart], kinds: Array[PlantPart.Kind],
		depth := ANY_DEPTH) -> Array:
	var drawn: Array[PlantPart] = []
	for part in parts:
		if kinds.has(part.kind) and (depth == ANY_DEPTH or part.depth == depth):
			drawn.append(part)
	var canvas := _canvas_for(species, drawn)
	if canvas.is_empty():
		return [null, Vector2.ZERO]
	var image: Image = canvas[0]
	var origin: Vector2i = canvas[1]
	for part in drawn:
		if part.kind != PlantPart.Kind.LEAF:
			_draw_bar(image, origin, species, part)
	var leaves := drawn.filter(func(part: PlantPart) -> bool: return part.kind == PlantPart.Kind.LEAF)
	_paint_leaves(image, origin, species, leaves, {}, true)
	return [ImageTexture.create_from_image(image), Vector2(origin)]


## Renders the leaves at one depth, with each leaf's decline level from `levels`.
## Returns [texture, top-left], or [null, ZERO] if there are none.
static func render_leaves(species: PlantSpecies, parts: Array[PlantPart], depth: int, levels: Dictionary) -> Array:
	var leaves: Array[PlantPart] = []
	for part in parts:
		if part.kind == PlantPart.Kind.LEAF and part.depth == depth:
			leaves.append(part)
	var canvas := _canvas_for(species, leaves)
	if canvas.is_empty():
		return [null, Vector2.ZERO]
	_paint_leaves(canvas[0], canvas[1], species, leaves, levels, false)
	return [ImageTexture.create_from_image(canvas[0]), Vector2(canvas[1])]


## The pixels a part covers, in plant space.
static func footprint(species: PlantSpecies, part: PlantPart) -> Rect2i:
	if part.kind == PlantPart.Kind.LEAF:
		var rects := _leaf_rects(species, part)
		var bounds := rects[0]
		for rect in rects:
			bounds = bounds.merge(rect)
		return bounds
	var rect := bar_rect(part)
	if _creeping(species) and part.kind == PlantPart.Kind.STEM and part.direction.y != 0:
		rect = rect.grow(FILLET) # Room for the corner curve.
	return rect


## The pixels a stem or root bar covers, in plant space.
static func bar_rect(part: PlantPart) -> Rect2i:
	var width := maxi(roundi(part.thickness), 1)
	var a := Vector2i(part.start.round())
	var b := Vector2i(part.end.round())
	var corner := a.min(b) - Vector2i.ONE * (width / 2)
	var span := (b - a).abs()
	return Rect2i(corner, Vector2i(span.x + width, span.y + width))


## A leaf's size in pixels (a square's side, a blade's height): growing with age toward
## its cap, shrinking as it fails.
static func leaf_size(species: PlantSpecies, part: PlantPart) -> int:
	var growth := clampf(part.age / species.leaf_grow_time, 0.0, 1.0)
	var health := 1.0 - 0.45 * _decline(species, part)
	return maxi(roundi(lerpf(species.min_leaf_size, part.size_cap, growth) * health), 2)


## A leaf's decline level for drawing (0 = healthy).
static func leaf_level(species: PlantSpecies, part: PlantPart) -> int:
	return clampi(floori(_decline(species, part) * DECLINE_LEVELS), 0, DECLINE_LEVELS - 1)


static func _creeping(species: PlantSpecies) -> bool:
	return species.form == PlantSpecies.Form.CREEPER


static func _blade_width(part: PlantPart) -> int:
	return 2 if part.size_cap >= 7.0 else 1


## The rectangles a leaf is made of, in plant space: a blade, a square, or for a main
## leaf mass a big square with smaller lobes around it so its outline is lumpy.
static func _leaf_rects(species: PlantSpecies, part: PlantPart) -> Array[Rect2i]:
	var size := leaf_size(species, part)
	var center := Vector2i(part.end.round())
	if _creeping(species):
		var width := _blade_width(part)
		return [Rect2i(center.x - width / 2, center.y - size, width, size)]
	var rects: Array[Rect2i] = [Rect2i(center - Vector2i.ONE * (size / 2), Vector2i.ONE * size)]
	if part.core:
		var rng := RandomNumberGenerator.new()
		rng.seed = part.variant
		for i in 6:
			var lobe := roundi(size * rng.randf_range(0.4, 0.65))
			var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / 6.0
			var at := center + Vector2i((Vector2.from_angle(angle) * size * 0.45).round())
			rects.append(Rect2i(at - Vector2i.ONE * (lobe / 2), Vector2i.ONE * lobe))
	return rects


## A blank image covering the parts (with a little room for wind), as [image, top-left],
## or [] if there are no parts.
static func _canvas_for(species: PlantSpecies, parts: Array[PlantPart]) -> Array:
	if parts.is_empty():
		return []
	var bounds := footprint(species, parts[0])
	for part in parts:
		bounds = bounds.merge(footprint(species, part))
	bounds = bounds.grow(2)
	return [Image.create_empty(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8), bounds.position]


## Paints leaves. Squares are filled in their own colors, then the whole shape they make
## is shaded together: a lit top edge, a shaded bottom and right edge, and speckle.
static func _paint_leaves(image: Image, origin: Vector2i, species: PlantSpecies, leaves: Array,
		levels: Dictionary, withered: bool) -> void:
	for part: PlantPart in leaves:
		var level: int = DECLINE_LEVELS - 1 if withered else levels.get(part, 0)
		var color := species.leaf_color.lerp(species.dying_leaf_color, float(level) / (DECLINE_LEVELS - 1))
		for rect in _leaf_rects(species, part):
			rect.position -= origin
			if _creeping(species): # A blade: dark at the foot, lighter at the tip.
				image.fill_rect(rect, color)
				image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x, 1)), color.lightened(0.2))
				image.fill_rect(Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1), color.darkened(0.25))
			else:
				image.fill_rect(rect, color)
	if _creeping(species):
		return
	var size := image.get_size()
	var shaded := image.duplicate()
	var pattern := _leaf_tile(species)
	for y in size.y:
		for x in size.x:
			var color := image.get_pixel(x, y)
			if color.a == 0.0:
				continue
			# Clumps follow plant space, so they stay put as the art is redrawn.
			var clump: int = pattern[posmod(y + origin.y, LEAF_TILE) * LEAF_TILE + posmod(x + origin.x, LEAF_TILE)]
			var shade := color.darkened(0.2) if clump < 0 else color.lightened(0.12) if clump > 0 else color
			if y == 0 or image.get_pixel(x, y - 1).a == 0.0:
				shade = color.lightened(0.18)
			elif y == size.y - 1 or image.get_pixel(x, y + 1).a == 0.0 \
					or x == size.x - 1 or image.get_pixel(x + 1, y).a == 0.0:
				shade = color.darkened(0.3)
			shaded.set_pixel(x, y, shade)
	image.copy_from(shaded)


## A bar of bark, with a darker edge on its shaded side once it's thick enough. Grass
## climbing or dropping a step also fills the inside corner at its foot with a curve.
static func _draw_bar(image: Image, origin: Vector2i, species: PlantSpecies, part: PlantPart) -> void:
	var rect := bar_rect(part)
	var color := species.bark_color if part.kind == PlantPart.Kind.STEM else species.root_color
	var tile := _bark_tile(species, part.kind)
	# Take the speckle from where the bar sits in plant space, so it stays put as the plant grows.
	var half := BARK_TILE / 2
	var source := Rect2i(Vector2i(posmod(rect.position.x, half), posmod(rect.position.y, half)), rect.size)
	image.blit_rect(tile, source, rect.position - origin)
	var width := maxi(roundi(part.thickness), 1)
	if width >= 3:
		var edge := Rect2i(rect.end.x - 1, rect.position.y, 1, rect.size.y) if part.direction.x == 0 \
				else Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1)
		image.fill_rect(Rect2i(edge.position - origin, edge.size), color.darkened(0.3))

	if _creeping(species) and part.kind == PlantPart.Kind.STEM and part.direction.y != 0 and part.run != Vector2i.ZERO:
		# The wall is ahead when climbing and behind when dropping; the curve faces away from it.
		var away := -part.run.x if part.direction == Vector2i.UP else part.run.x
		var foot := roundi(part.start.y if part.direction == Vector2i.UP else part.end.y) + width / 2
		for row in FILLET:
			var reach := FILLET - row
			var x := rect.position.x - reach if away < 0 else rect.end.x
			image.fill_rect(Rect2i(x - origin.x, foot - row - origin.y, reach, 1), color)


static func _bark_tile(species: PlantSpecies, kind: PlantPart.Kind) -> Image:
	var key := [species.id, kind]
	if _bark_tiles.has(key):
		return _bark_tiles[key]
	var color := species.bark_color if kind == PlantPart.Kind.STEM else species.root_color
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var tile := Image.create_empty(BARK_TILE, BARK_TILE, false, Image.FORMAT_RGBA8)
	for y in BARK_TILE:
		for x in BARK_TILE:
			var speckle := rng.randf_range(-SPECKLE, SPECKLE)
			tile.set_pixel(x, y, color.lightened(speckle) if speckle > 0.0 else color.darkened(-speckle))
	_bark_tiles[key] = tile
	return tile


## A repeating pattern of leaf clumps: small blobs of darker shadow and lighter
## highlight scattered over plain leaf, like Minecraft's leaves.
static func _leaf_tile(species: PlantSpecies) -> PackedInt32Array:
	if _leaf_tiles.has(species.id):
		return _leaf_tiles[species.id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([species.id, "leaves"])
	var tile := PackedInt32Array()
	tile.resize(LEAF_TILE * LEAF_TILE)
	var shapes: Array = [ # Small clump shapes, as pixel offsets.
		[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(0, 0), Vector2i(0, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)], [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
	]
	for value in [-1, 1]:
		for i in (70 if value < 0 else 35):
			var at := Vector2i(rng.randi() % LEAF_TILE, rng.randi() % LEAF_TILE)
			for offset: Vector2i in shapes[rng.randi() % shapes.size()]:
				var pixel := at + offset
				tile[posmod(pixel.y, LEAF_TILE) * LEAF_TILE + posmod(pixel.x, LEAF_TILE)] = value
	_leaf_tiles[species.id] = tile
	return tile


static func _decline(species: PlantSpecies, part: PlantPart) -> float:
	return clampf(maxf(part.starvation / species.starve_time, part.idle / species.shed_time), 0.0, 1.0)

