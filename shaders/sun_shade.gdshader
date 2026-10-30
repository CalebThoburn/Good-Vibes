// Darkens the world by how much solid stuff lies between each pixel and the sun (or
// moon), traced along three slightly spread rays so thin things cast soft shadows.
// Multiplied over the world. `occupancy` is the world's silhouette (alpha),
// rendered a margin bigger than the screen so shadows can come from just off-screen.
shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform sampler2D occupancy : filter_nearest, repeat_disable;
// Where the screen sits inside the occupancy texture, in its UV.
uniform vec2 screen_origin;
uniform vec2 screen_scale;
// One world pixel, in occupancy UV, and where the world's pixel grid starts.
uniform vec2 pixel_uv;
uniform vec2 grid_phase;
// One march step toward the light, in occupancy UV, along the middle ray and the two
// spread either side of it.
uniform vec2 light_step;
uniform vec2 light_step_left;
uniform vec2 light_step_right;
uniform int steps = 48;
// How quickly light fades per occupied step.
uniform float density = 0.06;
// The darkest anything gets.
uniform float ambient = 0.2;

// Light reaching `uv` along one ray: fades with every occupied step.
float trace(vec2 uv, vec2 step) {
	float blocked = 0.0;
	for (int i = 1; i <= steps; i++) {
		vec2 point = uv + step * float(i);
		if (point.x < 0.0 || point.x > 1.0 || point.y < 0.0 || point.y > 1.0) {
			break; // Beyond what we can see: assume open sky.
		}
		blocked += texture(occupancy, point).a;
	}
	return exp(-density * blocked);
}

void fragment() {
	// Snap to the center of the world pixel underneath, so shading matches its pixels.
	vec2 uv = screen_origin + SCREEN_UV * screen_scale;
	uv = (floor((uv - grid_phase) / pixel_uv) + 0.5) * pixel_uv + grid_phase;
	if (texture(occupancy, uv).a < 0.5) {
		COLOR = vec4(1.0); // Sky: left alone.
	} else {
		float light = (trace(uv, light_step) + trace(uv, light_step_left) + trace(uv, light_step_right)) / 3.0;
		COLOR = vec4(vec3(mix(ambient, 1.0, light)), 1.0);
	}
}
