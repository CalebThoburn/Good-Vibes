class_name CreatureBrain
extends RefCounted
## Decides what a creature does: which way it walks (Creature.walk) and where its parts
## reach. Subclasses are set per species (CreatureSpecies.brain).

var creature: Creature


func _init(p_creature: Creature) -> void:
	creature = p_creature


func think(_delta: float) -> void:
	pass
