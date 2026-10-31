class_name CreatureAction
extends Resource
## Something a creature can do, maybe to something (a Thing). A species lists the
## actions its creatures have (CreatureSpecies.actions); the Mind picks among them by
## what it expects each to lead to. Actions hold no state of their own (each creature's
## Mind keeps that), so one is shared by every creature of the species.

enum { RUNNING, DONE, FAILED }

@export var id: StringName
## Words for doing it, shown when the player looks at the creature ("eating").
@export var verb := ""
## Kinds of thing it can be done to, by prefix ("plant", "block", "creature", "player",
## "machine", "item"). Empty: it's done to nothing in particular.
@export var targets: Array[StringName] = []
## Seconds before it gives up.
@export var max_time := 20.0


## Whether it can be done to a thing (or, with null, to nothing).
func can_target(thing: Thing) -> bool:
	if thing == null:
		return targets.is_empty()
	for prefix in targets:
		if String(thing.kind).begins_with(prefix):
			return true
	return false


func begin(_mind: Mind, _thing: Thing) -> void:
	pass


## Carries it on for a moment. Returns RUNNING, DONE or FAILED.
func step(_mind: Mind, _thing: Thing, _delta: float) -> int:
	return DONE


func end(_mind: Mind) -> void:
	pass
