class_name SunShade
extends CanvasLayer
## Shading from the sun and moon. A hidden viewport renders the world's silhouette (no
## sky, no effects); a shader multiplied over the world then darkens each pixel by how
## much of that silhouette lies between it and the light. That gives both depth (pixels
## get darker further into the ground) and cast shadows (under overhangs and trees), which
## swing round as the sun crosses the sky.

## Canvas items on this visibility layer (bit 2) don't cast shade: strings, air, cursors.
const NO_SHADE_LAYER := 2
## March step toward the light, in world pixels, and how many steps.
const STEP := 2.0
const STEPS := 48
## How far past each screen edge the silhouette is rendered, in world pixels.
const MARGIN := STEP * STEPS
## Angle between the middle ray toward the light and the two either side of it. Wider
## means softer shadows from thin things.
const RAY_SPREAD := 0.22

@export var sky: SkyLayer

var _silhouette := SubViewport.new()
var _overlay := ColorRect.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	_silhouette.transparent_bg = true
	_silhouette.world_2d = get_viewport().world_2d # Same world, seen again.
	_silhouette.canvas_cull_mask = ~NO_SHADE_LAYER
	_silhouette.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_silhouette)
	process_priority = 100 # After the camera has moved this frame, so the views match.

	_material.shader = preload("res://shaders/sun_shade.gdshader")
	_material.set_shader_parameter(&"occupancy", _silhouette.get_texture())
	_material.set_shader_parameter(&"steps", STEPS)
	_overlay.material = _material
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


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
	_material.set_shader_parameter(&"screen_origin", margin / size)
	_material.set_shader_parameter(&"screen_scale", screen / size)
	var pixel_uv := camera.zoom / size
	_material.set_shader_parameter(&"pixel_uv", pixel_uv)
	# Where world pixel boundaries fall, so shading lines up with the pixels it darkens.
	var phase := view.origin / size
	_material.set_shader_parameter(&"grid_phase", Vector2(fposmod(phase.x, pixel_uv.x), fposmod(phase.y, pixel_uv.y)))
	var to_uv := STEP * camera.zoom / size
	_material.set_shader_parameter(&"light_step", to_light * to_uv)
	_material.set_shader_parameter(&"light_step_left", to_light.rotated(-RAY_SPREAD) * to_uv)
	_material.set_shader_parameter(&"light_step_right", to_light.rotated(RAY_SPREAD) * to_uv)
	_material.set_shader_parameter(&"density", lerpf(0.045, 0.018, brightness))
	_material.set_shader_parameter(&"ambient", lerpf(0.3, 0.6, brightness))
