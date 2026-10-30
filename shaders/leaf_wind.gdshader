// Leaves in the wind: gusts travel sideways through the canopy, nudging whole bunches of
// leaves a pixel or so with only a slight slant, so they lean together rather than
// shimmer row by row.
shader_type canvas_item;

// Pixels of lean at the peak of a gust.
uniform float sway = 1.0;
uniform float speed = 1.3;
// How fast the wind sweeps across (radians per world pixel), and the slight slant.
uniform float sweep = 0.025;
uniform float slant = 0.006;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float gust = 0.55 + 0.45 * sin(TIME * 0.37 - world.x * 0.013);
	float shift = sin(TIME * speed - world.x * sweep - world.y * slant) * sway * gust;
	COLOR = texture(TEXTURE, UV - vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0));
}
