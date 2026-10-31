extends CreatureAction
## Wanders off somewhere new: a creature with nothing better to do, or looking for
## something it can't see, roams.

## How far it goes, px.
@export var distance := Vector2(50.0, 160.0)


func begin(mind: Mind, _thing: Thing) -> void:
	var creature := mind.creature
	var way := mind.roam_direction()
	var goal := creature.global_position + Vector2(way * mind.rng.randf_range(distance.x, distance.y), 0.0)
	if creature.swims(): # Somewhere else in the water.
		var liquids := creature.world.liquids
		var cell := liquids.nearest(goal + Vector2(0.0, mind.rng.randf_range(-20.0, 20.0)), 0, 6, 0.6)
		goal = liquids.cell_center(cell) if cell != Vector2i.MAX else creature.global_position
	elif creature.flies():
		goal.y += mind.rng.randf_range(-40.0, 20.0)
	mind.state = {goal = goal}


func step(mind: Mind, _thing: Thing, delta: float) -> int:
	var result := mind.approach(mind.state.goal, 4.0, delta)
	if result == FAILED:
		mind.blocked_way()
	return result
