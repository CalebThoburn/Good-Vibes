class_name CreaturePiece
extends RigidBody2D
## Parts torn off a creature (or a dead one fallen apart), tumbling loose. They're dead
## weight now: carried along as the piece moves and drawn as they were, leaking what
## they hold, until they fade away. A piece smaller than a block can be sucked up by a
## vacuum, as what it's made of and what's left in it (see items).

const LIFETIME := 60.0
const FADE_TIME := 3.0
## Share of what the parts hold that leaks out per second.
const LEAK := 0.1

var parts: Array[BodyPart] = []

var _creature: Creature
var _art: CreatureArt
var _last := Transform2D.IDENTITY
var _age := 0.0
var _drip := 0.0


func _init(p_parts: Array[BodyPart], center: Vector2, velocity: Vector2, owner_creature: Creature) -> void:
	parts = p_parts
	_creature = owner_creature
	position = center
	linear_velocity = velocity + Vector2(randf_range(-30.0, 30.0), -40.0)
	angular_velocity = randf_range(-6.0, 6.0)
	collision_layer = BlockWorld.CREATURE_LAYER # Where vacuums look for small loose things.
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.MACHINE_LAYER
	var bounds := _bounds()
	mass = maxf(bounds.get_area() * 0.02, 0.3)
	var shape := RectangleShape2D.new()
	shape.size = bounds.size.max(Vector2.ONE * 2.0) * 0.8
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = bounds.get_center() - center
	add_child(collision)
	_art = CreatureArt.new(owner_creature)
	_art.drawn = parts
	_art.z_index = -2
	add_child(_art)


func _ready() -> void:
	_last = global_transform


## Whether it's smaller than a block, so a vacuum can take it in.
func small() -> bool:
	var size := _bounds().size
	return maxf(size.x, size.y) < BlockGrid.CELL_SIZE


## What it comes to as items: what the parts are made of, and whole units of what they
## still hold.
func items() -> Dictionary[StringName, int]:
	var found: Dictionary[StringName, int] = {}
	for part in parts:
		for item_id in part.makeup:
			found[item_id] = found.get(item_id, 0) + part.makeup[item_id]
		for item_id in part.contents:
			var whole := floori(part.contents[item_id])
			if whole > 0:
				found[item_id] = found.get(item_id, 0) + whole
	return found


func _physics_process(delta: float) -> void:
	_age += delta
	var motion := global_transform * _last.affine_inverse()
	_last = global_transform
	for part in parts:
		part.move_by(motion)
		for item_id in part.contents.keys():
			var leaked: float = part.contents[item_id] * minf(LEAK * delta, 1.0)
			part.contents[item_id] -= leaked
			_creature.spill(item_id, leaked, global_position)
	_art.queue_redraw()
	_drip -= delta
	if _drip <= 0.0 and _age < LIFETIME * 0.2:
		_drip = 0.3
		Blood.spray(self, global_position, 1, Vector2.DOWN, 10.0)
	_art.modulate.a = clampf((LIFETIME - _age) / FADE_TIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()


## The parts' outline in global space.
func _bounds() -> Rect2:
	var bounds := parts[0].extent()
	for part in parts:
		bounds = bounds.merge(part.extent())
	return bounds
