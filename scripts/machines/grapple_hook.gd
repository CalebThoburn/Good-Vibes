class_name GrappleHook
extends Node2D
## A string fired from a launcher. It flies until it hooks something (blocks, machines,
## or the player) or runs out of string, in which case it winds back. Once hooked it reels
## in and holds tight for as long as the launcher keeps getting a signal, then lets go.
##
## The rope pulls both ends with the same force, so each moves in inverse proportion to
## its mass: a light block comes to the machine, terrain drags the machine to it, and
## similar masses meet in the middle.

enum State { FLYING, HOOKED, RETURNING }

const FLY_SPEED := 700.0
const REEL_SPEED := 260.0
## The rope reels in to this length and holds there.
const MIN_LENGTH := 14.0
## How hard the rope corrects stretch, and the fastest it will close it (px/s).
const STIFFNESS := 0.4
const MAX_CORRECTION_SPEED := 600.0
const STRING_COLOR := Color(0.92, 0.9, 0.82)

var machine: Machine
var cell: Vector2i
var direction: Vector2i
var max_length: float
## The machine tick the launcher last signalled this grapple on.
var last_signal_tick := 0

var _state := State.FLYING
var _tip := Vector2.ZERO # Global; the free end while flying or returning.
var _target: CollisionObject2D # What the hook is stuck in; it moves the hook point.
var _target_body: PhysicsBody2D # What the rope pulls on. Differs for a held machine.
var _target_point := Vector2.ZERO # In the target's local space.
var _length := 0.0


func _init(p_machine: Machine, p_cell: Vector2i, p_direction: Vector2i, p_max_length: float) -> void:
	machine = p_machine
	cell = p_cell
	direction = p_direction
	max_length = p_max_length
	top_level = true
	z_index = 1


func _ready() -> void:
	_tip = _anchor()


## Lets go and winds the string back in.
func release() -> void:
	if _state == State.HOOKED:
		_tip = _target_end()
	_state = State.RETURNING
	_target = null


func _physics_process(delta: float) -> void:
	if not machine.is_running():
		queue_free()
		return
	match _state:
		State.FLYING:
			_fly(delta)
		State.HOOKED:
			_reel(delta)
		State.RETURNING:
			_tip = _tip.move_toward(_anchor(), FLY_SPEED * delta)
			if _tip.is_equal_approx(_anchor()):
				queue_free()
	queue_redraw()


func _draw() -> void:
	var end := _target_end() if _state == State.HOOKED else _tip
	draw_line(_anchor(), end, STRING_COLOR, 1.0)
	draw_rect(Rect2(end - Vector2.ONE * 1.5, Vector2.ONE * 3.0), STRING_COLOR.darkened(0.3))


func _anchor() -> Vector2:
	return machine.muzzle(cell, direction)


func _target_end() -> Vector2:
	return _target.to_global(_target_point) if is_instance_valid(_target) else _tip


func _fly(delta: float) -> void:
	var next := _tip + machine.aim(direction) * FLY_SPEED * delta
	var query := PhysicsRayQueryParameters2D.create(_tip, next,
			BlockWorld.BLOCK_LAYER | BlockWorld.PLAYER_LAYER | BlockWorld.MACHINE_LAYER, machine.self_colliders)
	query.collide_with_areas = true # Held machines are areas.
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and _body_of(hit.collider):
		_target = hit.collider
		_target_body = _body_of(hit.collider)
		_target_point = _target.to_local(hit.position)
		_length = _anchor().distance_to(hit.position)
		_state = State.HOOKED
		return
	_tip = next
	if _anchor().distance_to(_tip) >= max_length:
		_state = State.RETURNING


func _reel(delta: float) -> void:
	var signalled := machine.tick_count <= last_signal_tick
	if not signalled or not is_instance_valid(_target) or not is_instance_valid(_target_body):
		release()
		return
	_length = maxf(_length - REEL_SPEED * delta, MIN_LENGTH)
	var a := _anchor()
	var b := _target_end()
	var distance := a.distance_to(b)
	if distance <= _length:
		return # Slack: a rope only pulls.

	# Find the impulse that makes the ends close the stretch, shared by inverse mass.
	var holder := machine.holder
	var inverse_a := _inverse_mass(holder)
	var inverse_b := _inverse_mass(_target_body)
	if inverse_a + inverse_b == 0.0:
		return
	var normal := (b - a) / distance
	var closing_speed := minf((distance - _length) * STIFFNESS / delta, MAX_CORRECTION_SPEED)
	var relative_speed := (_velocity_of(_target_body) - _velocity_of(holder)).dot(normal)
	var impulse := (-closing_speed - relative_speed) / (inverse_a + inverse_b)
	if impulse >= 0.0:
		return
	_apply_impulse(_target_body, normal * impulse, b)
	_apply_impulse(holder, -normal * impulse, a)


## The body to pull for a hooked collider: itself, or a held machine's holder. Null for
## anything that can't be pulled.
static func _body_of(collider: Object) -> PhysicsBody2D:
	if collider is PhysicsBody2D:
		return collider
	if collider is Area2D and collider.get_parent() is MachineView:
		var held: Machine = collider.get_parent().machine
		return held.holder if held else null
	return null


## Zero for things that don't move (terrain). Characters need a `mass` property.
static func _inverse_mass(body: PhysicsBody2D) -> float:
	if body is RigidBody2D and not body.freeze:
		return 1.0 / body.mass
	if body is CharacterBody2D and "mass" in body:
		return 1.0 / body.mass
	return 0.0


static func _velocity_of(body: PhysicsBody2D) -> Vector2:
	if body is RigidBody2D:
		return body.linear_velocity
	if body is CharacterBody2D:
		return body.velocity
	return Vector2.ZERO


static func _apply_impulse(body: PhysicsBody2D, impulse: Vector2, global_point: Vector2) -> void:
	if body is RigidBody2D:
		body.apply_impulse(impulse, global_point - body.global_position)
	elif body.has_method(&"apply_impulse"):
		body.apply_impulse(impulse)
	elif body is CharacterBody2D:
		body.velocity += impulse * _inverse_mass(body)
