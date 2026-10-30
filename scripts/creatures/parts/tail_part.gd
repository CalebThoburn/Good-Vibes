class_name TailPart
extends BodyPart
## A short tail hanging off the back of the body: a stub of coat that flicks while the
## creature walks or eats.

@export var length := 3.0
@export var width := 3.0
## The part whose colour the tail takes. Empty: the tail's own colour.
@export var coat_from: StringName = &"torso"

var _coat := Color.WHITE
var _phase := 0.0


func fits(candidate: BodyPart) -> bool:
	return candidate is TorsoPart


func roll(rng: RandomNumberGenerator) -> void:
	super(rng)
	length = vary(length, rng)
	_phase = rng.randf() * TAU


func setup() -> void:
	var coat_part := creature.part(coat_from) if not coat_from.is_empty() else null
	_coat = (coat_part.color if coat_part else color).darkened(0.08)


func update(delta: float) -> void:
	var busy := absf(creature.velocity.x) > 1.0 or creature.walk != 0.0
	_phase += delta * (9.0 if busy and not creature.dead else 1.5)


func draw(art: CreatureArt) -> void:
	var root := parent.attach_point(socket, side)
	var tip := root + Vector2(-creature.facing * (1.0 + sin(_phase) * 0.6), length)
	art.line(root, tip, width, _coat)
	art.line(tip + Vector2(0.0, 1.0), tip + Vector2(0.0, 1.0), width - 1.0, _coat.darkened(0.2))


func layer() -> float:
	return 0.5
