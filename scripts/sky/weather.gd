class_name Weather
extends Node
## The weather: some days are sunny and some rainy, picked from the world seed and the
## day number, so the same day always has the same weather. On a rainy day a spell of
## rain comes and goes, easing in and out. Rain waters the ground (see Liquids), mutes
## the world's colours and greys the sky, and brings wind, which every shader that sways
## reads from the wind_strength global.

const GROUP := &"weather"
## Share of days that are rainy.
const RAINY_CHANCE := 0.4
## How long rain takes to build or die away, in days.
const EASE := 0.04
## Rain streaks on screen at full rain.
const DROPS := 220
const DROP_COLOR := Color(0.75, 0.82, 0.95, 0.45)

@export var sky: SkyLayer

## How hard it's raining now, 0-1.
var rain := 0.0
## How windy it is now (1 is a breezy day).
var wind := 1.0

var _seed := 0
var _layer := CanvasLayer.new()
var _drops := Node2D.new()
var _wind_noise := FastNoiseLite.new()


func _ready() -> void:
	add_to_group(GROUP)
	_seed = sky.world.world_seed if sky and sky.world else 0
	_wind_noise.seed = _seed + 5
	_wind_noise.frequency = 3.0
	_layer.layer = 1 # Over the world, under the HUD.
	add_child(_layer)
	_drops.draw.connect(_draw_rain)
	_layer.add_child(_drops)


func _process(_delta: float) -> void:
	var days: float = sky._days if sky else 0.0
	rain = rain_at(days)
	wind = 0.7 + 0.5 * _wind_noise.get_noise_1d(days) + 1.6 * rain
	RenderingServer.global_shader_parameter_set(&"wind_strength", wind)
	_drops.visible = rain > 0.01
	if _drops.visible:
		_drops.queue_redraw()


## How hard it's raining at a time (in days since the world began).
func rain_at(days: float) -> float:
	var day := floori(days)
	var spell := _spell(day)
	if spell.is_empty():
		return 0.0
	var into := days - day
	var start: float = spell.start
	var finish: float = spell.start + spell.length
	var amount := minf(smoothstep(start, start + EASE, into), 1.0 - smoothstep(finish - EASE, finish, into))
	return amount * spell.strength


## How much the world's colours are muted (by cloud and rain), 0-1.
func mute() -> float:
	return smoothstep(0.0, 0.6, rain)


## Whether it's sunny (not raining), for drying things out: 0-1.
func dryness() -> float:
	return 1.0 - rain


## A rainy day's spell of rain: {start, length (fractions of the day), strength}, or {}
## on a sunny day.
func _spell(day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, day])
	if rng.randf() >= RAINY_CHANCE:
		return {}
	var length := rng.randf_range(0.25, 0.6)
	return {start = rng.randf_range(0.0, 1.0 - length), length = length, strength = rng.randf_range(0.5, 1.0)}


## Streaks of rain falling across the screen, slanted by the wind.
func _draw_rain() -> void:
	var screen := _drops.get_viewport_rect().size
	var time := Time.get_ticks_msec() / 1000.0
	var slant := Vector2(wind * 0.18, 1.0).normalized()
	var length := 14.0
	var count := roundi(DROPS * rain)
	var color := DROP_COLOR
	color.a *= 0.5 + 0.5 * rain
	for i in count:
		var seed_x := fmod(i * 97.31, 1.0)
		var speed := 600.0 + fmod(i * 13.7, 1.0) * 300.0
		var fall := fmod(time * speed + i * 211.0, screen.y + 200.0) - 100.0
		var at := Vector2(fposmod(seed_x * screen.x + fall * slant.x / slant.y, screen.x), fall)
		_drops.draw_line(at, at + slant * length, color, 1.0)
