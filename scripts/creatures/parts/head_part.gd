class_name HeadPart
extends BodyPart
## A head on a neck, hanging off the front of the body. It carries the brain, which runs
## the rest of the body: with the head gone, nothing tells the legs where to go. The
## brain points it somewhere (reach_for) and it swings there at its own speed, paying
## its own energy for every pixel it moves; with no energy left it can only move slowly. The head tips down as it goes
## lower, so it grazes face-down. It's drawn by turning its pixel pattern to the head's
## angle, sampling each screen pixel back into the pattern so it never breaks up.

@export var neck_length := 7.0
@export var neck_width := 4.0
## The skull, px (the snout comes on top of it).
@export var head_size := Vector2(6.0, 5.0)
@export var snout := 3.0
## Px/s the head swings at.
@export var speed := 40.0
@export var ear_color := Color(0.2, 0.17, 0.15)
@export var eye_color := Color(0.05, 0.04, 0.04)
## The part whose colour covers the neck and the top of the head (wool, for sheep).
## Empty: the head's own colour.
@export var coat_from: StringName = &"torso"

## Where the neck leaves the body, global.
var base := Vector2.ZERO
## The middle of the skull, global.
var center := Vector2.ZERO
## How far it's tipped from looking ahead, radians (positive: down).
var pitch := 0.0
## What runs the creature (CreatureSpecies.brain), while the head is on.
var brain: CreatureBrain

var _offset := Vector2.ZERO # From the base to the head, facing right.
var _target := Vector2.INF # Where the mouth should go; INF for resting.
var _pattern: Dictionary[Vector2i, Color] = {}
var _eye := Vector2i.ZERO
var _coat := Color.WHITE


func fits(candidate: BodyPart) -> bool:
	return candidate is TorsoPart


func roll(rng: RandomNumberGenerator) -> void:
	super(rng)
	neck_length = vary(neck_length, rng)
	head_size = Vector2(vary(head_size.x, rng), vary(head_size.y, rng)).round()


func setup() -> void:
	var coat_part := creature.part(coat_from) if not coat_from.is_empty() else null
	_coat = coat_part.color if coat_part else color
	_offset = _rest()
	_build_pattern()


## Points the mouth at a global point, or with Vector2.INF lets the head rest.
func reach_for(point: Vector2) -> void:
	_target = point


## The tip of the snout, global.
func mouth() -> Vector2:
	return center + _mouth_offset(pitch)


## How far ahead of the creature's middle the mouth reaches down comfortably, px.
func reach_ahead() -> float:
	return (base.x - creature.global_position.x) * creature.facing + head_size.x * 0.5


## Whether the mouth could get to a point from where the body stands now.
func can_reach(point: Vector2) -> bool:
	var from_base := point - base
	return from_base.x * creature.facing > -2.0 and from_base.length() <= neck_length + head_size.x * 0.5 + snout


func update(delta: float) -> void:
	base = parent.attach_point(socket, side)
	var wanted := _rest()
	if creature.dead:
		wanted = Vector2(neck_length * 0.6, neck_length * 0.9)
	elif _target != Vector2.INF:
		var aim := _target - _mouth_offset(pitch) - base
		wanted = Vector2(aim.x * creature.facing, aim.y).limit_length(neck_length)
	var swing := speed * delta * (1.0 if has_energy() or creature.dead else 0.3)
	var moved := _offset.move_toward(wanted, swing)
	if not creature.dead:
		spend(moved.distance_to(_offset) * creature.species.head_cost)
	_offset = moved
	pitch = clampf(atan2(_offset.y, absf(_offset.x) + 2.0) * 1.1 + 0.3, -0.3, 1.35)
	center = base + Vector2(_offset.x * creature.facing, _offset.y)


func draw(art: CreatureArt) -> void:
	var neck_end := center - Vector2(creature.facing, 0.0).rotated(pitch * creature.facing) * head_size.x * 0.3
	var radius := neck_width * 0.5
	var steps := maxi(ceili(base.distance_to(neck_end)), 1)
	for i in steps + 1: # Underside first, a pixel lower, so the neck has a shaded throat.
		art.disc(base.lerp(neck_end, float(i) / steps) + Vector2.DOWN, radius, _coat.darkened(0.3))
	for i in steps + 1:
		art.disc(base.lerp(neck_end, float(i) / steps), radius, _coat.darkened(0.08))
	# Each screen pixel near the head, turned back into the pattern.
	var reach := ceili(head_size.x * 0.5 + snout + 2.0)
	var middle := center.round()
	var turn := pitch
	for y in range(-reach, reach):
		for x in range(-reach, reach):
			var local := (Vector2(x, y) + Vector2(0.5, 0.5))
			local.x *= creature.facing
			var source := Vector2i(local.rotated(-turn).floor())
			if _pattern.has(source):
				var pixel: Color = _pattern[source]
				if source == _eye and creature.sleeping:
					pixel = color.darkened(0.25) # Eyes shut.
				art.draw_rect(Rect2(middle + Vector2(x, y), Vector2.ONE), pixel)
	if creature.sleeping: # A "z" drifting up.
		var drift := fmod(Time.get_ticks_msec() / 1000.0, 2.0)
		var corner := (center + Vector2(creature.facing * 2.0, -head_size.y - 3.0 - drift * 3.0)).round()
		var z := Color(1.0, 1.0, 1.0, 1.0 - drift * 0.5)
		art.draw_rect(Rect2(corner, Vector2(3.0, 1.0)), z)
		art.draw_rect(Rect2(corner + Vector2(1.0, 1.0), Vector2.ONE), z)
		art.draw_rect(Rect2(corner + Vector2(0.0, 2.0), Vector2(3.0, 1.0)), z)
	if creature.calling > 0.0: # Lines bursting from the mouth.
		var mouth_at := mouth().round()
		for i in 3:
			var spread := Vector2(creature.facing * 2.0, (i - 1) * 2.0)
			art.draw_rect(Rect2(mouth_at + spread + Vector2(creature.facing * (1.0 - creature.calling) * 3.0, 0.0),
					Vector2(2.0, 1.0)), Color(1.0, 1.0, 1.0, creature.calling))


func layer() -> float:
	return 2.0


func hit_distance(point: Vector2) -> float:
	var neck_end := center - Vector2(creature.facing, 0.0).rotated(pitch * creature.facing) * head_size.x * 0.3
	return minf(point.distance_to(center) - head_size.x * 0.5 - 1.0,
			segment_distance(point, base, neck_end) - neck_width * 0.5)


func extent() -> Rect2:
	return Rect2(base, Vector2.ZERO).expand(center).grow(head_size.x * 0.5 + snout * 0.5)


func move_by(motion: Transform2D) -> void:
	base = motion * base
	center = motion * center
	pitch += motion.get_rotation() * creature.facing


func to_data() -> Dictionary:
	return {offset = _offset}


func load_data(data: Dictionary) -> void:
	_offset = data.offset


func _rest() -> Vector2:
	return Vector2(neck_length * 0.8, -neck_length * 0.4)


func _mouth_offset(angle: float) -> Vector2:
	return Vector2(creature.facing * (head_size.x * 0.5 + snout - 0.5), 0.5).rotated(angle * creature.facing)


## The head facing right and level: skull, snout, a coat cap, an ear and an eye.
func _build_pattern() -> void:
	var half := head_size * 0.5
	var left := -floori(half.x)
	var right := ceili(half.x)
	var top := -floori(half.y)
	var bottom := ceili(half.y)
	for y in range(top, bottom):
		for x in range(left, right):
			var corner := (x == left or x == right - 1) and (y == top or y == bottom - 1)
			if not corner:
				_pattern[Vector2i(x, y)] = color
	for y in range(top + 1, bottom): # The snout, narrower and lower.
		for x in range(right, right + roundi(snout)):
			if not (x == right + roundi(snout) - 1 and (y == top + 1 or y == bottom - 1)):
				_pattern[Vector2i(x, y)] = color.lightened(0.06)
	for y in range(top, bottom):
		_pattern[Vector2i(left, y)] = _pattern.get(Vector2i(left, y), color).darkened(0.15)
	for x in range(left, roundi(left + half.x * 0.9)): # Wool on the crown.
		_pattern[Vector2i(x, top)] = _coat.darkened(0.06)
	_pattern[Vector2i(left - 1, top + 1)] = ear_color # The ear, sticking out back.
	_pattern[Vector2i(left - 2, top + 1)] = ear_color.darkened(0.2)
	_eye = Vector2i(right - 2, top + 1)
	_pattern[_eye] = eye_color
	_pattern[Vector2i(right + roundi(snout) - 1, 0)] = color.darkened(0.35) # Nostril.
