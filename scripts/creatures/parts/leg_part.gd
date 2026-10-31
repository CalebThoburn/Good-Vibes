class_name LegPart
extends BodyPart
## A leg of two bones hanging off the body. Its foot stays planted where it last stood
## while the body moves over it, and when the body has carried the hip too far past it
## the leg lifts and steps ahead, paid from its own energy (out of energy, it drags).
## Legs step in diagonal pairs (see Creature.may_step). Off the ground, the legs dangle.
## The knee is placed by solving the two bones between hip and foot, bending forward or
## back.

## Hip to foot, fully straight, px.
@export var length := 8.0
@export var thickness := 2.0
## How far the foot can fall behind (or get ahead) before the leg steps, px.
@export var stride := 5.0
## How high the foot lifts mid-step, px.
@export var lift := 2.5
## Seconds per step.
@export var step_time := 0.16
## 1 for a knee that bends forward, -1 for one that bends back (a hind leg's hock).
@export var knee_direction := 1.0
## Which half of the gait it steps with (0 or 1). The far leg of a pair steps with the
## other half, so the legs go in diagonal pairs.
@export var gait_group := 0
## How far down the leg the body's coat reaches, as a share of the upper bone.
@export_range(0.0, 1.0) var coat := 0.7
@export var hoof_color := Color(0.12, 0.1, 0.09)

var hip := Vector2.ZERO
var knee := Vector2.ZERO
var foot := Vector2.ZERO
var stepping := false
var planted := false

var _step_from := Vector2.ZERO
var _step_to := Vector2.ZERO
var _step_t := 0.0


func fits(candidate: BodyPart) -> bool:
	return candidate is TorsoPart


func roll(rng: RandomNumberGenerator) -> void:
	super(rng)
	length = vary(length, rng)
	if side == Side.FAR:
		gait_group = 1 - gait_group


func setup() -> void:
	planted = false


func update(delta: float) -> void:
	# The far leg shows a little ahead of the near one, as if seen slightly from the front.
	hip = parent.attach_point(socket, side) + forward() * (1.0 if side == Side.FAR else 0.0)
	var lead := clampf(creature.velocity.x * step_time * 1.5, -stride, stride)
	var rest_x := hip.x + lead
	var ground := creature.ground_below(Vector2(rest_x, hip.y), length * 1.6)
	if creature.dead or not creature.is_on_floor() or is_nan(ground):
		# Dangling (or a dead body's legs, folded).
		stepping = false
		planted = false
		var hang := hip + Vector2(-creature.facing * 1.5, length * (0.5 if creature.dead else 0.95))
		foot = foot.lerp(hang, minf(delta * 12.0, 1.0)) if foot != Vector2.ZERO else hang
	elif stepping:
		_step_t = minf(_step_t + delta / step_time, 1.0)
		_step_to.y = ground
		foot = _step_from.lerp(_step_to, _step_t) + Vector2.UP * sin(PI * _step_t) * lift
		if _step_t >= 1.0:
			stepping = false
			foot = _step_to
	elif not planted:
		foot = Vector2(rest_x, ground)
		planted = true
	else:
		var rest := Vector2(rest_x, ground)
		if (foot.distance_to(rest) > stride or foot.distance_to(hip) > length * 1.05) and creature.may_step(self):
			stepping = true
			_step_t = 0.0
			_step_from = foot
			_step_to = rest + Vector2(signf(creature.velocity.x) * stride * 0.4, 0.0)
			spend(creature.species.step_cost)
	_solve_knee()


func draw(art: CreatureArt) -> void:
	var leg_color := shade(color)
	var coat_color := shade(parent.color.darkened(0.1))
	art.line(knee, foot, thickness, leg_color)
	art.line(hip, knee, thickness, leg_color)
	art.line(hip, hip.lerp(knee, coat), thickness + 1.0, coat_color)
	art.draw_rect(Rect2((foot - Vector2(thickness * 0.5, 1.0)).round(), Vector2(thickness, 1.0)), shade(hoof_color))


func layer() -> float:
	return 1.0 if side == Side.NEAR else -1.0


func hit_distance(point: Vector2) -> float:
	return minf(segment_distance(point, hip, knee), segment_distance(point, knee, foot)) - thickness * 0.5


func extent() -> Rect2:
	return Rect2(hip, Vector2.ZERO).expand(knee).expand(foot).grow(thickness * 0.5)


func move_by(motion: Transform2D) -> void:
	hip = motion * hip
	knee = motion * knee
	foot = motion * foot


## Places the knee so both bones (half the leg each) reach from hip to foot.
func _solve_knee() -> void:
	var to_foot := foot - hip
	var reach := minf(to_foot.length(), length * 0.999)
	var along := to_foot.normalized() if not to_foot.is_zero_approx() else Vector2.DOWN
	var bone := length * 0.5
	var bend := sqrt(maxf(bone * bone - reach * reach * 0.25, 0.0))
	var out := along.orthogonal()
	if out.x * creature.facing * knee_direction < 0.0:
		out = -out
	knee = hip + along * reach * 0.5 + out * bend
	foot = hip + along * reach if to_foot.length() > length else foot
