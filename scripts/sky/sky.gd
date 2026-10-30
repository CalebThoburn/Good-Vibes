class_name SkyLayer
extends CanvasLayer
## The sky behind the world, after FEZ: a day-night cycle with a smooth gradient, a
## single plane of square stars, a square sun and moon, and three layers of blocky clouds
## drifting with gentle parallax. Also tints the world (through a CanvasModulate) to match
## the time of day.
##
## Drawn in screen space at the camera's pixel scale, so stars, sun and moon are on the
## block pixel grid. Clouds glide freely instead of snapping to it.

## Times are fractions of a day: 0 is midnight, 0.5 is noon. The second half of the day
## mirrors the first, so the colors run back the way they came into the night.
const SKY_KEYS: Array[float] = [0.0, 0.12, 0.18, 0.215, 0.25, 0.28, 0.32, 0.37, 0.45]
const SKY_TOPS: Array[Color] = [
	Color(0.02, 0.01, 0.05), # black
	Color(0.13, 0.04, 0.27), # deep purple
	Color(0.42, 0.07, 0.45), # magenta
	Color(0.78, 0.36, 0.62), # pink
	Color(0.72, 0.18, 0.3), # red
	Color(0.9, 0.48, 0.28), # orange
	Color(0.96, 0.84, 0.44), # yellow
	Color(0.42, 0.78, 0.58), # green
	Color(0.32, 0.56, 0.95), # blue
]
const SKY_HORIZONS: Array[Color] = [
	Color(0.07, 0.03, 0.13),
	Color(0.27, 0.08, 0.42),
	Color(0.86, 0.22, 0.62),
	Color(1.0, 0.62, 0.72),
	Color(0.96, 0.32, 0.27),
	Color(1.0, 0.66, 0.32),
	Color(1.0, 0.95, 0.62),
	Color(0.76, 0.95, 0.72),
	Color(0.62, 0.82, 1.0),
]
## How the world is lit at the same times.
const WORLD_LIGHT: Array[Color] = [
	Color(0.3, 0.28, 0.5),
	Color(0.38, 0.3, 0.58),
	Color(0.62, 0.4, 0.66),
	Color(0.86, 0.62, 0.72),
	Color(0.92, 0.62, 0.6),
	Color(0.98, 0.78, 0.66),
	Color(1.0, 0.95, 0.82),
	Color(0.94, 1.0, 0.94),
	Color(1.0, 1.0, 1.0),
]

## Far to near: how much each cloud layer follows the camera, its drift speed (world
## px/s), cloud size, cloud count, how much it takes on the sky's color, and opacity.
const CLOUD_LAYERS: Array[Dictionary] = [
	{parallax = 0.02, drift = 0.6, size = 1.2, count = 9, haze = 0.55, alpha = 0.7},
	{parallax = 0.05, drift = 1.2, size = 1.6, count = 7, haze = 0.35, alpha = 0.85},
	{parallax = 0.09, drift = 2.0, size = 2.1, count = 5, haze = 0.15, alpha = 0.95},
]
## Clouds and stars repeat across this width, in world pixels.
const CLOUD_SPAN := 2400.0
## The star field, in world pixels. It's fixed to the screen, so only the part that fits
## shows; bigger than any screen so the edges never come up short.
const STAR_SPAN := Vector2(1600.0, 700.0)
const STAR_COUNT := 900
const SUN_SIZE := 22
## The sun and moon travel a circle around this point (fractions of the screen), with
## this radius (a fraction of the screen height).
const ORBIT_CENTER := Vector2(0.5, 0.8)
const ORBIT_RADIUS := 0.64
## Days from new moon to new moon. Each day the moon rises later by 1 / this of a day.
const LUNAR_MONTH := 8.0
## Lowest angle (radians above the horizon) the sun or moon lights from, so shadows
## never stretch forever.
const LOWEST_LIGHT := 0.35
const MOON_SIZE := 14

## Length of a full day, in seconds.
@export var day_length := 600.0
## Time of day the world starts at (0 midnight, 0.25 sunrise, 0.5 noon).
@export_range(0.0, 1.0) var start_time := 0.3
## How much faster time runs while the time_skip action is held.
@export var skip_speed := 40.0
@export var world_light: CanvasModulate
@export var world: BlockWorld

var _canvas := Node2D.new()
var _sky_tops := Gradient.new()
var _sky_horizons := Gradient.new()
var _world_lights := Gradient.new()
# Per layer: an Array of {image texture, position (world px), size}.
var _clouds: Array[Array] = []
# Each: {position, phase, rate}.
var _stars: Array[Dictionary] = []
var _anchor := Vector2.INF # Where the player starts; cloud heights are laid out around it.
var _clock := 0.0
## Time of day (0 midnight, 0.25 sunrise, 0.5 noon). Setting it keeps the day count.
var time_of_day: float:
	get:
		return fposmod(_days, 1.0)
	set(value):
		_days = floorf(_days) + value

## Days since the world began. Time of day and the moon's phase come from this.
var _days := 0.0


func _ready() -> void:
	layer = -1
	add_child(_canvas)
	_canvas.draw.connect(_draw_sky)
	var offsets := PackedFloat32Array()
	for key in SKY_KEYS:
		offsets.append(key * 2.0) # Keys cover half a day; gradients cover 0-1.
	for pair in [[_sky_tops, SKY_TOPS], [_sky_horizons, SKY_HORIZONS], [_world_lights, WORLD_LIGHT]]:
		pair[0].offsets = offsets
		pair[0].colors = PackedColorArray(pair[1])
	_generate(world.world_seed if world else 0)
	_days = start_time


func _process(delta: float) -> void:
	var speed := skip_speed if Input.is_action_pressed(&"time_skip") else 1.0
	_days += delta * speed / day_length
	_clock += delta * speed
	if world_light:
		world_light.color = _world_lights.sample(_half_day())
	_canvas.queue_redraw()


## 0 at midnight rising to 1 at noon, the same on the way back down.
func _half_day() -> float:
	return (time_of_day if time_of_day <= 0.5 else 1.0 - time_of_day) * 2.0


## Where the sun is on its circle: 0 at noon (straight up), ±PI at midnight.
func sun_angle() -> float:
	return (time_of_day - 0.5) * TAU


## The moon trails the sun by its phase, so it rises later every day: with the sun at
## new moon, opposite it at full.
func moon_angle() -> float:
	return sun_angle() - moon_phase() * TAU


## 0 new, 0.5 full, back to 1.
func moon_phase() -> float:
	return fposmod(_days / LUNAR_MONTH + 0.5, 1.0)


## How much of the moon is lit, 0-1.
func moon_illumination() -> float:
	return (1.0 - cos(moon_phase() * TAU)) * 0.5


## How high the sun is: 1 at noon, 0 at or below the horizon.
func daylight() -> float:
	return clampf(cos(sun_angle()), 0.0, 1.0)


## How strong the moonlight is: its height times how much of it is lit.
func moonlight() -> float:
	return clampf(cos(moon_angle()), 0.0, 1.0) * moon_illumination()


## Toward whichever of the sun or moon is lighting the world, in screen space (y down),
## never lower than LOWEST_LIGHT above the horizon.
func light_direction() -> Vector2:
	var angle := sun_angle() if daylight() > 0.0 or moonlight() == 0.0 else moon_angle()
	var direction := Vector2(sin(angle), -cos(angle))
	if -direction.y < sin(LOWEST_LIGHT):
		direction = Vector2(signf(direction.x) * cos(LOWEST_LIGHT), -sin(LOWEST_LIGHT))
	return direction


## 1 in full night, 0 in full day.
func night() -> float:
	return 1.0 - smoothstep(0.24, 0.5, _half_day())


func _generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for layer_info in CLOUD_LAYERS:
		var clouds := []
		for i in layer_info.count:
			var image := CloudShapes.make(rng, layer_info.size)
			var x: float = CLOUD_SPAN * (i + rng.randf_range(-0.3, 0.3)) / layer_info.count
			# The top of the cloud, above the player's start: high in the sky, just under the
			# top of the screen (which is about 160 px up at the default zoom).
			var y := -rng.randf_range(125.0, 170.0)
			clouds.append({texture = ImageTexture.create_from_image(image), position = Vector2(x, y), size = image.get_size()})
		_clouds.append(clouds)
	for i in STAR_COUNT:
		_stars.append({position = Vector2(rng.randf() * STAR_SPAN.x, rng.randf() * STAR_SPAN.y),
				phase = rng.randf() * TAU, rate = rng.randf_range(0.6, 2.0)})


func _draw_sky() -> void:
	var camera := get_viewport().get_camera_2d()
	var screen := get_viewport().get_visible_rect().size
	var pixel := camera.zoom.x if camera else 1.0 # Screen pixels per world pixel.
	var view := camera.get_screen_center_position() if camera else Vector2.ZERO
	if _anchor == Vector2.INF: # The world is generated by the first frame.
		_anchor = world.spawn_position() if world else view
	var half_day := _half_day()
	var top := _sky_tops.sample(half_day)
	var horizon := _sky_horizons.sample(half_day)

	# A smooth blend from the top of the screen down to the horizon.
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(screen.x, 0.0), screen, Vector2(0.0, screen.y)]),
			PackedColorArray([top, top, horizon, horizon]))

	var darkness := night()
	if darkness > 0.01:
		_draw_stars(screen, pixel, darkness)
	_draw_celestial(screen, pixel)

	for i in _clouds.size():
		var layer_info: Dictionary = CLOUD_LAYERS[i]
		var day_tint := horizon.lerp(Color.WHITE, 1.0 - layer_info.haze)
		var night_tint := top.lerp(horizon, 0.5).lightened(0.12)
		var tint := day_tint.lerp(night_tint, darkness)
		tint.a = layer_info.alpha
		var shift := Vector2(_clock * layer_info.drift - view.x * layer_info.parallax,
				(_anchor.y - view.y) * layer_info.parallax)
		for cloud: Dictionary in _clouds[i]:
			var world_x := fposmod(cloud.position.x + shift.x, CLOUD_SPAN) - CLOUD_SPAN * 0.5
			var at := Vector2(world_x, cloud.position.y + shift.y) * pixel + screen * 0.5
			var size: Vector2 = Vector2(cloud.size) * pixel
			for wrap in [0.0, CLOUD_SPAN * pixel, -CLOUD_SPAN * pixel]: # Copies cover the seam.
				var spot := at + Vector2(wrap, 0.0)
				if spot.x < screen.x and spot.x + size.x > 0.0:
					_canvas.draw_texture_rect(cloud.texture, Rect2(spot, size), false, tint)


## One flat plane of single-pixel stars, fixed to the screen, twinkling.
func _draw_stars(screen: Vector2, pixel: float, darkness: float) -> void:
	for star in _stars:
		var at: Vector2 = (star.position * pixel).snapped(Vector2.ONE * pixel)
		if at.x > screen.x or at.y > screen.y:
			continue
		var twinkle := 0.6 + 0.4 * sin(_clock * star.rate + star.phase)
		_canvas.draw_rect(Rect2(at, Vector2.ONE * pixel), Color(1.0, 0.97, 0.88, darkness * twinkle))


## The sun and moon, gliding round their circle. The moon shows its phase, lit from the
## sun's side, with the dark part faintly visible.
func _draw_celestial(screen: Vector2, pixel: float) -> void:
	var center := screen * ORBIT_CENTER
	var radius := screen.y * ORBIT_RADIUS
	var day := daylight()

	var moon_at := center + Vector2(sin(moon_angle()), -cos(moon_angle())) * radius
	var moon_size := MOON_SIZE * pixel
	if moon_at.y < center.y + moon_size:
		var corner := moon_at - Vector2.ONE * moon_size * 0.5
		var fade := lerpf(1.0, 0.55, day) # Paler by day.
		var lit := moon_illumination()
		_canvas.draw_rect(Rect2(corner, Vector2.ONE * moon_size), Color(0.85, 0.85, 1.0, 0.12 * fade))
		var lit_width := snappedf(moon_size * lit, pixel)
		var waxing := moon_phase() < 0.5 # Lit on the right while waxing, the left while waning.
		var lit_x := corner.x + moon_size - lit_width if waxing else corner.x
		_canvas.draw_rect(Rect2(Vector2(lit_x, corner.y), Vector2(lit_width, moon_size)), Color(0.92, 0.92, 1.0, fade))

	var sun_at := center + Vector2(sin(sun_angle()), -cos(sun_angle())) * radius
	var sun_size := SUN_SIZE * pixel
	if sun_at.y < center.y + sun_size:
		var corner := sun_at - Vector2.ONE * sun_size * 0.5
		for glow in [[6.0, 0.15], [3.0, 0.3]]:
			var grow: float = glow[0] * pixel
			_canvas.draw_rect(Rect2(corner - Vector2.ONE * grow, Vector2.ONE * (sun_size + grow * 2.0)), Color(1.0, 0.95, 0.7, glow[1]))
		_canvas.draw_rect(Rect2(corner, Vector2.ONE * sun_size), Color(1.0, 0.93, 0.6))
		_canvas.draw_rect(Rect2(corner + Vector2.ONE * pixel * 3.0, Vector2.ONE * (sun_size - pixel * 6.0)), Color(1.0, 0.98, 0.85))
