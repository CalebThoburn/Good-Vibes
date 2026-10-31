class_name CreatureArt
extends Node2D
## Draws a creature's parts as pixel art, back layer first. It sits at the world origin
## and draws in world pixels, rounded, so every pixel lines up with the blocks however
## the parts move. Parts draw themselves through the helpers here.

var creature: Creature
## Parts to draw instead of the creature's own (for a torn-off piece).
var drawn: Array[BodyPart] = []


func _init(p_creature: Creature) -> void:
	creature = p_creature
	top_level = true
	material = SunShade.lit_material()


func _draw() -> void:
	var parts := (drawn if not drawn.is_empty() else creature.parts).duplicate()
	parts.sort_custom(func(a: BodyPart, b: BodyPart) -> bool: return a.layer() < b.layer())
	for part: BodyPart in parts:
		part.draw(self)


func pixel(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at.floor(), Vector2.ONE), color)


## A line `width` pixels thick.
func line(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var steps := maxi(ceili(maxf(absf(to.x - from.x), absf(to.y - from.y))), 1)
	var size := Vector2.ONE * maxf(roundf(width), 1.0)
	for i in steps + 1:
		var at := from.lerp(to, float(i) / steps)
		draw_rect(Rect2((at - size * 0.5).round(), size), color)


## A filled circle.
func disc(center: Vector2, radius: float, color: Color) -> void:
	var rows := ceili(radius)
	for row in range(-rows, rows):
		var y := row + 0.5
		if absf(y) > radius:
			continue
		var half := sqrt(radius * radius - y * y)
		var left := roundf(center.x - half)
		var right := roundf(center.x + half)
		if right > left:
			draw_rect(Rect2(left, floorf(center.y) + row, right - left, 1.0), color)


func sprite(texture: Texture2D, top_left: Vector2) -> void:
	draw_texture(texture, top_left.round())
