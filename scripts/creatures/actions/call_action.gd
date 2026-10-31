extends CreatureAction
## Calls out (a sheep's baa; a firefly flashes instead). Every creature that hears it
## notices for a while, which they can learn to read something into.

## How far it carries, px.
@export var reach := 200.0
## Seconds it lasts.
@export var duration := 1.0


func begin(mind: Mind, _thing: Thing) -> void:
	var creature := mind.creature
	mind.state = {left = duration}
	creature.calling = duration
	if creature.has_node(^"Glow"):
		creature.glow = 1.0
	for other: Creature in creature.get_tree().get_nodes_in_group(Creature.GROUP):
		if other != creature and other.global_position.distance_to(creature.global_position) < reach:
			var mind_of := other.brain() as Mind
			if mind_of:
				mind_of.hear(creature.species.id)


func step(mind: Mind, _thing: Thing, delta: float) -> int:
	mind.creature.walk = 0.0
	mind.creature.fly_velocity = Vector2.ZERO
	mind.state.left -= delta
	return DONE if mind.state.left <= 0.0 else RUNNING
