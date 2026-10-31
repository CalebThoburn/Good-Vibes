class_name CreatureSpecies
extends Resource
## A kind of creature: the body plan its parts grow from, the brain that drives it, and
## how it lives. Put .tres files in res://data/creatures/ and Fauna picks them up.

@export var id: StringName
@export var display_name: String
## Every part, parents before the parts that hang off them.
@export var body_plan: Array[BodyPart] = []
## A CreatureBrain script (Mind for creatures that learn).
@export var brain: Script
## What its creatures can do (CreatureAction).
@export var actions: Array[CreatureAction] = []
## How many the world starts with.
@export var population := 6

## How heavy it is when air pushes it about.
@export var mass := 40.0
## Lives in water: swims there, and out of it flops and suffocates.
@export var swims := false
## Share of its blood lost per second out of water, for swimmers.
@export var suffocation := 0.02

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

@export_group("Blood")
## How full of blood (its energy) it starts.
@export_range(0.0, 1.0) var start_blood := 0.6
## Blood per leg step (from that leg).
@export var step_cost := 0.003
## Blood per pixel the head moves (from the head).
@export var head_cost := 0.0003
## Blood per hop (from each leg).
@export var jump_cost := 0.012

@export_group("Mind")
## How strongly it's drawn to what it knows little about (see Mind).
@export var curiosity := 0.05
## What it expects of things it's never tried, by "action|target kind", as the change
## in its needs (food, energy, health, rest), each as a share of full.
@export var instincts: Dictionary[String, Vector4] = {}

@export_group("Sleep")
## Bile made per second asleep.
@export var bile_rate := 0.25
## Damage healed per second asleep, and the blood each point of it costs.
@export var heal_rate := 0.1
@export var heal_cost := 0.2

@export_group("Feeding")
## Plant species it eats (their leaves).
@export var food: Array[StringName] = [&"grass"]
## How far it looks for food, px.
@export var sight := 180.0
