// Leaves in the wind: ripples roll sideways through the canopy, so part of a leaf mass
// stretches while another bunches up. Each pixel moves only as far as its "give" allows
// (kept in the leaf texture's normal map): none where its leaf joins the branch, more
// further out, so leaves never come away from the wood. Lit by the sun and moon like
// other world objects.
shader_type canvas_item;

#include "res://shaders/sun_light.gdshaderinc"

// Pixels of sway at a leaf's loosest, at the peak of a gust.
uniform float sway = 1.3;
uniform float speed = 1.7;
// Ripple tightness (radians per world pixel: about a 48 px wavelength) and slight slant.
uniform float ripple = 0.13;
uniform float slant = 0.02;

varying vec2 world;
varying vec4 tint; // The item's color, e.g. the darker tint on a tree's back layer.

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	float give = texture(NORMAL_TEXTURE, UV).r;
	float gust = 0.55 + 0.45 * sin(TIME * 0.37 - world.x * 0.013);
	float shift = sin(TIME * speed - world.x * ripple - world.y * slant) * sway * gust * give;
	COLOR = texture(TEXTURE, UV - vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0)) * tint;
	COLOR.rgb *= sun_light(world, SCREEN_PIXEL_SIZE);
}
