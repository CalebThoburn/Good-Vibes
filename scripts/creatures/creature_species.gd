class_name CreatureSpecies
extends Resource
## A kind of creature: the body plan its parts grow from, the brain that drives it, and
## how it lives. Put .tres files in res://data/creatures/ and Fauna picks them up.

@export var id: StringName
@export var display_name: String
## Every part, parents before the parts that hang off them.
@export var body_plan: Array[BodyPart] = []
## A CreatureBrain script.
@export var brain: Script
## How many the world starts with.
@export var population := 6

@export_group("Movement")
## Walking speed, px/s.
@export var walk_speed := 22.0
@export var acceleration := 120.0
## Speed of a hop up a step, px/s.
@export var jump_speed := 215.0
## Highest drop it will walk off, px.
@export var max_drop := 34.0
## Highest drop it will risk when it's desperate (hungry, nothing to eat in sight), px.
@export var desperate_drop := 66.0

@export_group("Energy")
@export var max_energy := 10.0
@export var start_energy := 6.0
## Energy used per second just staying alive.
@export var metabolism := 0.008
## Energy per leg step.
@export var step_cost := 0.003
## Energy per pixel the head moves.
@export var head_cost := 0.0003
## Energy per hop.
@export var jump_cost := 0.05
@export var max_health := 1.0
## Health lost per second with no energy left.
@export var starve_rate := 1.0 / 90.0
## Health regained per second while well fed.
@export var heal_rate := 1.0 / 60.0

@export_group("Feeding")
## Plant species it eats (their leaves).
@export var food: Array[StringName] = [&"grass"]
## How far it looks for food, px.
@export var sight := 180.0
