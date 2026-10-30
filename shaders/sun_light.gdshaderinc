// Light for world objects, shared by their shaders. SunShade renders the world's
// silhouette and keeps these globals up to date; each object darkens its own pixels by
// how much of that silhouette lies between them and the sun or moon, then adds the warm
// light of any burning lanterns nearby.

global uniform sampler2D sun_occupancy : filter_nearest, repeat_disable;
// World position to silhouette UV: xy scale, zw offset.
global uniform vec4 sun_world_to_uv;
// One march step toward the light (in silhouette UV), along the middle ray and two
// spread either side of it for soft edges.
global uniform vec2 sun_step;
global uniform vec2 sun_step_left;
global uniform vec2 sun_step_right;
// How quickly light fades per occupied step, and the darkest anything gets.
global uniform float sun_density;
global uniform float sun_ambient;
// Size of the silhouette view in pixels. Anything drawn at this size is the silhouette
// itself being rendered, which mustn't read from the texture it's drawing into. (The main
// view's own size can't be relied on: it changes with the window and screen scaling.)
global uniform vec2 sun_silhouette_size;
// Lanterns: one texel each (x, y, radius, strength), sun_lamp_count of them.
global uniform sampler2D sun_lamps : filter_nearest;
global uniform int sun_lamp_count;
// The world's tint for the time of day, applied afterwards by a CanvasModulate. Light is
// worked out as it will look after that, then divided by it, so lamplight isn't dimmed
// at night.
global uniform vec4 sun_tint;

const vec3 LAMP_COLOR = vec3(1.0, 0.78, 0.45);
const float LAMP_BRIGHTNESS = 1.8;

const int SUN_STEPS = 48;

float sun_trace(vec2 uv, vec2 step) {
	float blocked = 0.0;
	for (int i = 1; i <= SUN_STEPS; i++) {
		vec2 point = uv + step * float(i);
		if (point.x < 0.0 || point.x > 1.0 || point.y < 0.0 || point.y > 1.0) {
			break; // Beyond what we can see: assume open sky.
		}
		blocked += texture(sun_occupancy, point).a;
	}
	return exp(-sun_density * blocked);
}

// Warm light from nearby lanterns at a world pixel.
vec3 lamp_light(vec2 pixel) {
	vec3 total = vec3(0.0);
	for (int i = 0; i < sun_lamp_count; i++) {
		vec4 lamp = texelFetch(sun_lamps, ivec2(i, 0), 0);
		float glow = clamp(1.0 - distance(pixel, lamp.xy) / lamp.z, 0.0, 1.0);
		total += LAMP_COLOR * LAMP_BRIGHTNESS * glow * glow * lamp.w; // A smooth fade from bright to nothing.
	}
	return total;
}

// How lit the world pixel at `world` is: the sun or moon's light (1 = full) plus any
// lamplight. Pass SCREEN_PIXEL_SIZE.
vec3 sun_light(vec2 world, vec2 screen_pixel_size) {
	vec2 drawing = 1.0 / screen_pixel_size;
	if (sun_density <= 0.0 || all(lessThan(abs(drawing - sun_silhouette_size), vec2(0.5)))) {
		return vec3(1.0);
	}
	// The center of the world pixel this fragment belongs to, so a pixel is lit as one.
	vec2 pixel = floor(world) + 0.5;
	vec2 uv = pixel * sun_world_to_uv.xy + sun_world_to_uv.zw;
	float light = (sun_trace(uv, sun_step) + sun_trace(uv, sun_step_left) + sun_trace(uv, sun_step_right)) / 3.0;
	// As it will look after the world's tint: sunlight (or moonlight), plus lamplight,
	// which counts for most where it's actually dark.
	vec3 daylit = mix(sun_ambient, 1.0, light) * sun_tint.rgb;
	float brightness = clamp(dot(daylit, vec3(0.3, 0.5, 0.2)), 0.0, 1.0);
	vec3 lit = min(daylit + lamp_light(pixel) * (1.0 - brightness * 0.8), vec3(1.2));
	return lit / max(sun_tint.rgb, vec3(0.05));
}
