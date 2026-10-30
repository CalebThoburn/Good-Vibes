// World objects lit by the sun and moon: drawn as usual, then darkened by the shade on
// each of their pixels (see sun_light.gdshaderinc).
shader_type canvas_item;

#include "res://shaders/sun_light.gdshaderinc"

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// COLOR already holds the texture times the item's color.
	COLOR.rgb *= sun_light(world, SCREEN_PIXEL_SIZE);
}
