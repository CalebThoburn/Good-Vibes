class_name MachinePhysics
## Pushing and pulling on whatever a machine effect touches: rigid bodies, the player
## (a CharacterBody2D with `mass` and `apply_impulse()`), and immovable terrain.


## The body to push or pull for a collider: itself, or the holder of a held machine
## (whose hitbox is an area). Null for anything that can't be moved.
static func body_of(collider: Object) -> PhysicsBody2D:
	if collider is PhysicsBody2D:
		return collider
	if collider is Area2D and collider.get_parent() is MachineView:
		var held: Machine = collider.get_parent().machine
		return held.holder if held else null
	return null


## Zero for things that don't move (terrain). Characters need a `mass` property.
static func inverse_mass(body: PhysicsBody2D) -> float:
	if body is RigidBody2D and not body.freeze:
		return 1.0 / body.mass
	if body is CharacterBody2D and "mass" in body:
		return 1.0 / body.mass
	return 0.0


static func velocity_of(body: PhysicsBody2D) -> Vector2:
	if body is RigidBody2D:
		return body.linear_velocity
	if body is CharacterBody2D:
		return body.velocity
	return Vector2.ZERO


static func apply_impulse(body: PhysicsBody2D, impulse: Vector2, global_point: Vector2) -> void:
	if body is RigidBody2D:
		body.apply_impulse(impulse, global_point - body.global_position)
	elif body.has_method(&"apply_impulse"):
		body.apply_impulse(impulse)
	elif body is CharacterBody2D:
		body.velocity += impulse * inverse_mass(body)
