extends CreatureAction
## Sleeps: lies still while the body heals its damage (paid in blood) and makes the bile
## its stomach needs to turn food into blood. It wakes once it's rested and healed, or
## when something hurts it.


func begin(mind: Mind, _thing: Thing) -> void:
	mind.creature.sleeping = true


func step(mind: Mind, _thing: Thing, _delta: float) -> int:
	var creature := mind.creature
	creature.walk = 0.0
	creature.fly_velocity = Vector2.ZERO
	var head := creature.part_of(HeadPart) as HeadPart
	if head:
		head.reach_for(head.base + Vector2(creature.facing * 6.0, 10.0)) # Head down.
	return DONE if mind.rest() >= 0.98 and mind.health() >= 0.99 else RUNNING


func end(mind: Mind) -> void:
	mind.creature.sleeping = false
	var head := mind.creature.part_of(HeadPart) as HeadPart
	if head:
		head.reach_for(Vector2.INF)
