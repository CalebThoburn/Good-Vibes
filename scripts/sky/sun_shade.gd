class_name SunShade
extends Node
## Shading from the sun and moon, and lanterns' light. A hidden viewport renders the
## world's silhouette (no sky, no effects), and every world object's shader (see
## lit_material) darkens its own pixels by how much of that silhouette lies between them
## and the light. That gives both depth (pixels get darker further into the ground) and
## cast shadows (under overhangs and trees), which swing round as the sun crosses the sky.
## Burning lanterns (LanternGlow) add warm light on top. Because each object lights its
## own pixels, the light can't drift out of line with them as things move.

## Canvas items on this visibility layer (bit 2) don't cast shade: strings, air, cursors.
const NO_SHADE_LAYER := 2
## March step toward the light, in world pixels. The shader takes 48 steps.
const STEP := 2.0
const STEPS := 48
## How far past each screen edge the silhouette is rendered, in world pixels.
const MARGIN := STEP * STEPS
## Angle between the middle ray toward the light and the two either side of it. Wider
## means softer shadows from thin things.
const RAY_SPREAD := 0.22
## Most lanterns lighting the world at once.
const MAX_LAMPS := 32

static var _lit: ShaderMaterial

@export var sky: SkyLayer

var _silhouette := SubViewport.new()
# Lanterns' positions, reach and brightness, one texel each, for the shaders.
var _lamp_image := Image.create_empty(MAX_LAMPS, 1, false, Image.FORMAT_RGBAF)
var _lamps := ImageTexture.create_from_image(_lamp_image)


## The material world objects use to be lit by the sun and moon.
static func lit_material() -> ShaderMaterial:
	if _lit == null:
		_lit = ShaderMaterial.new()
		_lit.shader = preload("res://shaders/lit.gdshader")
	return _lit


func _ready() -> void:
	_silhouette.transparent_bg = true
	_silhouette.world_2d = get_viewport().world_2d # Same world, seen again.
	_silhouette.canvas_cull_mask = ~NO_SHADE_LAYER
	_silhouette.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_silhouette)
	process_priority = 100 # After the camera has moved this frame, so the views match.
	RenderingServer.global_shader_parameter_set(&"sun_occupancy", _silhouette.get_texture().get_rid())
	RenderingServer.global_shader_parameter_set(&"sun_lamps", _lamps.get_rid())


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"sun_density", 0.0) # Unlit without us.


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var margin := MARGIN * camera.zoom
	var size := screen + margin * 2.0
	_silhouette.size = Vector2i(size.ceil())
	# Exactly the main view, shifted by the margin.
	var view := Transform2D(0.0, margin) * get_viewport().get_canvas_transform()
	_silhouette.canvas_transform = view

	var to_light := sky.light_direction() if sky else Vector2.UP
	# The brighter it is (the sun high, or a bright moon), the more light reaches down.
	var brightness := maxf(sky.daylight(), sky.moonlight() * 0.3) if sky else 1.0
	var scale := view.get_scale() / size
	var to_uv := STEP * camera.zoom / size
	RenderingServer.global_shader_parameter_set(&"sun_world_to_uv", Vector4(scale.x, scale.y, view.origin.x / size.x, view.origin.y / size.y))
	RenderingServer.global_shader_parameter_set(&"sun_step", to_light * to_uv)
	RenderingServer.global_shader_parameter_set(&"sun_step_left", to_light.rotated(-RAY_SPREAD) * to_uv)
	RenderingServer.global_shader_parameter_set(&"sun_step_right", to_light.rotated(RAY_SPREAD) * to_uv)
	RenderingServer.global_shader_parameter_set(&"sun_density", lerpf(0.045, 0.018, brightness))
	RenderingServer.global_shader_parameter_set(&"sun_ambient", lerpf(0.3, 0.6, brightness))
	RenderingServer.global_shader_parameter_set(&"sun_screen_size", get_viewport().get_texture().get_size() * 1.0)
	RenderingServer.global_shader_parameter_set(&"sun_tint", sky.world_light.color if sky and sky.world_light else Color.WHITE)
	_update_lamps()


func _update_lamps() -> void:
	var count := 0
	for glow: LanternGlow in get_tree().get_nodes_in_group(LanternGlow.GROUP):
		if count == MAX_LAMPS:
			break
		_lamp_image.set_pixel(count, 0, Color(glow.global_position.x, glow.global_position.y, glow.radius, glow.strength()))
		count += 1
	if count > 0:
		_lamps.update(_lamp_image)
	RenderingServer.global_shader_parameter_set(&"sun_lamp_count", count)
