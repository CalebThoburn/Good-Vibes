extends CreatureAction
## Goes up to something (walking, or flying for creatures with wings).

## How close counts as there, px.
@export var near := 10.0


func step(mind: Mind, thing: Thing, delta: float) -> int:
	return mind.approach(thing.point(), near, delta)
