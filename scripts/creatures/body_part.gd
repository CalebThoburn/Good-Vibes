class_name BodyPart
extends Resource
## One part of a creature, with the rules for how it connects to the rest of the body,
## how it moves and how it's drawn. A species' body plan (CreatureSpecies.body_plan)
## lists parts as templates; each creature gets its own copy of each, rolled with a
## little variation from the creature's seed (see roll), so no two come out the same.
##
## A part hangs off its parent part at a socket. The parent decides where on itself a
## socket lands (attach_point), and the child decides what it can hang off (fits).
## Paired parts (legs) grow twice: once on the near side, drawn in front of the body,
## and once on the far side, drawn behind it and a little darker.

enum Side { FAR = -1, MIDDLE = 0, NEAR = 1 }

## How much light far-side parts keep, as if in the body's shadow.
const FAR_SHADE := 0.72

## Name other parts use to hang off this one.
@export var name: StringName
## The part this one hangs off. Empty for the part the rest of the body is built on.
@export var parent_name: StringName
## Where on the parent it hangs: x from -1 (back) to 1 (front), y from -1 (top) to 1
## (bottom), across the parent's size.
@export var socket := Vector2.ZERO
## Grows on both sides of the body.
@export var paired := false
@export var color := Color.WHITE
## How far each creature's colour can stray (lighter or darker).
@export_range(0.0, 0.5) var color_variation := 0.05
## How far each creature's sizes can stray, as a share of the plan's sizes.
@export_range(0.0, 0.5) var size_variation := 0.1

var creature: Creature
var parent: BodyPart
var children: Array[BodyPart] = []
var side: int = Side.MIDDLE


## Whether this part can hang off `candidate` (null: be the part the body is built on).
func fits(candidate: BodyPart) -> bool:
	return candidate == null


## Rolls this creature's own version of the part. Parts with sizes vary them here.
func roll(rng: RandomNumberGenerator) -> void:
	var shift := rng.randf_range(-color_variation, color_variation)
	color = color.lightened(shift) if shift > 0.0 else color.darkened(-shift)


## Called once every part is attached.
func setup() -> void:
	pass


## Where a child's socket lands on this part, in global coordinates.
func attach_point(_socket: Vector2, _side: int) -> Vector2:
	return creature.global_position


func update(_delta: float) -> void:
	pass


func draw(_art: CreatureArt) -> void:
	pass


## Draw order: lower is further back.
func layer() -> float:
	return float(side)


## State worth keeping between runs (the shape comes back from the seed).
func to_data() -> Dictionary:
	return {}


func load_data(_data: Dictionary) -> void:
	pass


## A size from the plan, varied for this creature.
func vary(value: float, rng: RandomNumberGenerator) -> float:
	return value * rng.randf_range(1.0 - size_variation, 1.0 + size_variation)


## A colour as it shows on this part's side of the body.
func shade(base: Color) -> Color:
	return base.darkened(1.0 - FAR_SHADE) if side == Side.FAR else base


## Forward along the creature's facing.
func forward() -> Vector2:
	return Vector2(creature.facing, 0.0)
