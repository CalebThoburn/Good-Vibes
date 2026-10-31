class_name CreatureGlow
extends Node2D
## The light a glowing creature (a firefly) gives off while it glows. SunShade gathers
## it into the lighting along with lanterns.

var creature: Creature
## How far the light reaches, px.
var radius := 36.0


func _init(p_creature: Creature) -> void:
	creature = p_creature
	add_to_group(LanternGlow.GROUP)


func _process(_delta: float) -> void:
	position = Vector2(0.0, -creature.ride_height)


## How bright it is now, 0-1.
func strength() -> float:
	return creature.glow * 0.8 if not creature.dead else 0.0
