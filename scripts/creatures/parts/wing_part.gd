class_name WingPart
extends BodyPart
## A wing off the top of the body. While attached and the creature has the blood for it,
## it beats and holds the creature up, paying for every second of flight; a creature
## that's lost its wings (or the blood to beat them) falls. Drawn as a pale blur that
## flicks up and down.

@export var length := 3.0
## Blood per second of flight.
@export var flight_cost := 0.001
## Beats per second.
@export var beat_rate := 18.0

var root := Vector2.ZERO
var tip := Vector2.ZERO

var _phase := 0.0


func fits(candidate: BodyPart) -> bool:
	return candidate is TorsoPart


func roll(rng: RandomNumberGenerator) -> void:
	super(rng)
	length = vary(length, rng)
	_phase = rng.randf() * TAU


## Whether it's beating, holding the creature up.
func beating() -> bool:
	return attached and has_energy() and not creature.dead


func update(delta: float) -> void:
	root = parent.attach_point(socket, side)
	if beating():
		_phase += delta * beat_rate * TAU
		spend(flight_cost * delta)
	var lift := sin(_phase) if beating() else -0.3
	tip = root + Vector2(-creature.facing * length * 0.7, -length * (0.4 + lift * 0.6))


func draw(art: CreatureArt) -> void:
	art.line(root, tip, 1.0, shade(color))


func layer() -> float:
	return 1.5 if side == Side.NEAR else -0.5


func hit_distance(point: Vector2) -> float:
	return segment_distance(point, root, tip) - 1.0


func extent() -> Rect2:
	return Rect2(root, Vector2.ZERO).expand(tip).grow(0.5)


func move_by(motion: Transform2D) -> void:
	root = motion * root
	tip = motion * tip
