class_name Blood
## Sprays and drips of blood: little red bits that fly and fall, then fade.

const COLOR := Color(0.55, 0.05, 0.06)


## A spurt of `amount` drops from a global point, flung roughly along `direction`.
static func spray(parent: Node, point: Vector2, amount: int, direction := Vector2.UP, speed := 60.0) -> void:
	var particles := CPUParticles2D.new()
	particles.top_level = true
	particles.position = point
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.amount = clampi(amount, 1, 64)
	particles.lifetime = 0.9
	particles.direction = direction
	particles.spread = 50.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0.0, 400.0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = COLOR
	particles.material = SunShade.lit_material()
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.emitting = true
