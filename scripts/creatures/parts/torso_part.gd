class_name TorsoPart
extends BodyPart
## The body everything else hangs off: a coat (wool, for sheep) shaped as an oval with
## puffs round its edge, rolled per creature. Other parts attach to its edge: a socket's
## direction from the middle is followed out to the last pixel of coat, so legs come out
## from under the wool and the neck from its front, whatever shape it rolled.

@export var size := Vector2(22.0, 11.0)
## Puffs around the edge of the oval.
@export var puffs := 8
## Smallest and biggest puff radius, px.
@export var puff_radius := Vector2(2.5, 4.0)
## How much darker the underside is than the top.
@export_range(0.0, 1.0) var underside_shade := 0.3
## Per-pixel lumpiness of the coat.
@export_range(0.0, 0.3) var texture_noise := 0.06

## The middle of the body, global.
var center := Vector2.ZERO

# The coat's pixels, relative to the middle, facing right.
var _pixels: Dictionary[Vector2i, bool] = {}
var _bounds := Rect2i()
var _textures: Array[ImageTexture] = [] # Facing right, then left.
var _sockets: Dictionary[Vector2, Vector2] = {}


func roll(rng: RandomNumberGenerator) -> void:
	super(rng)
	size = Vector2(vary(size.x, rng), vary(size.y, rng)).round()
	var half := size * 0.5
	var circles: Array[Vector3] = [] # x, y, radius
	var count := maxi(puffs + rng.randi_range(-1, 1), 3)
	for i in count:
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var radius := rng.randf_range(puff_radius.x, puff_radius.y)
		if sin(angle) > 0.3:
			radius *= 0.7 # A flatter belly.
		circles.append(Vector3(cos(angle) * half.x * 0.85, sin(angle) * half.y * 0.8, radius))
	var reach := Vector2i((half + Vector2.ONE * puff_radius.y).ceil())
	for y in range(-reach.y, reach.y):
		for x in range(-reach.x, reach.x):
			var at := Vector2(x + 0.5, y + 0.5)
			var inside := (at / half).length_squared() <= 1.0
			for circle in circles:
				inside = inside or at.distance_to(Vector2(circle.x, circle.y)) <= circle.z
			if inside:
				_pixels[Vector2i(x, y)] = true
	_bounds = Rect2i(_pixels.keys()[0], Vector2i.ONE)
	for pixel in _pixels:
		_bounds = _bounds.expand(pixel).expand(pixel + Vector2i.ONE)
	_paint(rng, circles)


func update(_delta: float) -> void:
	center = creature.global_position + Vector2(0.0, -creature.ride_height)


func attach_point(socket_at: Vector2, _side: int) -> Vector2:
	if not _sockets.has(socket_at):
		_sockets[socket_at] = _edge(socket_at)
	var local: Vector2 = _sockets[socket_at]
	return center + Vector2(local.x * creature.facing, local.y)


func draw(art: CreatureArt) -> void:
	var flipped := creature.facing < 0
	var left := -_bounds.end.x if flipped else _bounds.position.x
	art.sprite(_textures[1 if flipped else 0], center.round() + Vector2(left, _bounds.position.y))


func layer() -> float:
	return 0.0


## The last pixel of coat out from the middle toward a socket.
func _edge(socket_at: Vector2) -> Vector2:
	var toward := socket_at * size * 0.5
	if toward.is_zero_approx():
		return Vector2.ZERO
	var last := Vector2.ZERO
	var steps := ceili(toward.length() * 2.0) + 16
	for i in steps:
		var at := toward * (float(i) / ceili(toward.length() * 2.0))
		if not _pixels.has(Vector2i(at.floor())):
			break
		last = at
	return last


## Bakes the coat into textures: lighter on top and on the upper side of each puff,
## darker underneath and along the bottom edge.
func _paint(rng: RandomNumberGenerator, circles: Array[Vector3]) -> void:
	var image := Image.create_empty(_bounds.size.x, _bounds.size.y, false, Image.FORMAT_RGBA8)
	var top := float(_bounds.position.y)
	for pixel in _pixels:
		var at := Vector2(pixel) + Vector2(0.5, 0.5)
		var depth := (at.y - top) / _bounds.size.y
		var shade_amount := underside_shade * depth
		var tint := color.lightened(0.12 * (1.0 - depth)).darkened(shade_amount)
		for circle in circles: # Curls catch the light on their upper side.
			var from_middle := at - Vector2(circle.x, circle.y)
			if from_middle.length() <= circle.z and from_middle.normalized().dot(Vector2(-0.5, -0.85)) > 0.45:
				tint = tint.lightened(0.08)
				break
		if not _pixels.has(pixel + Vector2i.DOWN):
			tint = tint.darkened(0.2)
		elif not _pixels.has(pixel + Vector2i.UP):
			tint = tint.lightened(0.1)
		tint = tint.lightened(rng.randf_range(-texture_noise, texture_noise))
		image.set_pixelv(pixel - _bounds.position, tint)
	_textures.append(ImageTexture.create_from_image(image))
	var mirrored := image.duplicate() as Image
	mirrored.flip_x()
	_textures.append(ImageTexture.create_from_image(mirrored))
