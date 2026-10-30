class_name CloudShapes
## Generates blocky pixel-art clouds: a flat-bottomed base with a few broad puffs
## stacked on top, each a plain rectangle, and a smaller puff on some of those. The
## union is shaded the way FEZ does it: a lit top edge, a flat body, and a shadowed
## underside. Images are grayscale so a cloud can be tinted to the sky.

const HIGHLIGHT := 1.0
const BODY := 0.93
const SHADOW := 0.78
## Rows of shadow along the underside.
const SHADOW_DEPTH := 2


## A cloud one texel per world pixel. `size` scales it (far layers use smaller clouds).
static func make(rng: RandomNumberGenerator, size: float) -> Image:
	var rects: Array[Rect2i] = []
	var width := roundi(rng.randf_range(28.0, 60.0) * size)
	var base := Rect2i(0, 0, width, maxi(roundi(rng.randf_range(5.0, 8.0) * size), 3))
	rects.append(base)
	for i in rng.randi_range(1, 3):
		var puff_width := maxi(roundi(width * rng.randf_range(0.35, 0.65)), 4)
		var puff_height := maxi(roundi(rng.randf_range(4.0, 11.0) * size), 3)
		# Sits on the base, overlapping it a little so the pieces join.
		var puff := Rect2i(rng.randi_range(0, width - puff_width), 2 - puff_height, puff_width, puff_height)
		rects.append(puff)
		if rng.randf() < 0.4:
			var top_width := maxi(roundi(puff_width * rng.randf_range(0.5, 0.75)), 3)
			var top_height := maxi(roundi(rng.randf_range(3.0, 6.0) * size), 2)
			rects.append(Rect2i(puff.position.x + rng.randi_range(0, puff_width - top_width),
					puff.position.y + 1 - top_height, top_width, top_height))
	if rng.randf() < 0.5: # A low step sticking out one side.
		var step_height := maxi(roundi(base.size.y * 0.5), 3)
		var step_width := maxi(roundi(width * rng.randf_range(0.2, 0.35)), 4)
		var step_x := -step_width + 2 if rng.randf() < 0.5 else width - 2
		rects.append(Rect2i(step_x, base.end.y - step_height, step_width, step_height))

	var bounds := rects[0]
	for rect in rects:
		bounds = bounds.merge(rect)
	var filled: Dictionary[Vector2i, bool] = {}
	for rect in rects:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				filled[Vector2i(x, y) - bounds.position] = true

	var image := Image.create_empty(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	for pixel in filled:
		var shade := BODY
		if not filled.has(pixel + Vector2i.UP):
			shade = HIGHLIGHT
		else:
			for depth in range(1, SHADOW_DEPTH + 1):
				if not filled.has(pixel + Vector2i.DOWN * depth):
					shade = SHADOW
					break
		image.set_pixelv(pixel, Color(shade, shade, shade))
	return image
