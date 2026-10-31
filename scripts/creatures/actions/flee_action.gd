extends CreatureAction
## Runs (or flies) away from something until it's well clear of it.

## How far away counts as clear, px.
@export var clear := 140.0


func step(mind: Mind, thing: Thing, delta: float) -> int:
	var creature := mind.creature
	var away := creature.global_position - thing.point()
	if away.length() > clear:
		return DONE
	var direction := Vector2(signf(away.x) if away.x != 0.0 else 1.0, -0.5 if creature.flies() else 0.0)
	return mind.approach(creature.global_position + direction.normalized() * 60.0, 0.0, delta, true)
