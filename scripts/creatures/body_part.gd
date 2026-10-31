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
##
## A part is made of things (makeup: meat, wool) and holds things (contents): blood in
## every part, food and dung in a stomach, water in a firefly's. Blood is what powers
## it: the creature keeps it flowing evenly through every attached part, and each part
## pays its upkeep and the cost of what it does out of the blood it holds.
##
## It can take damage (hit_distance says where it is), and once it's taken its toughness
## it tears off, with everything hanging off it. A torn-off part takes no orders and
## gets no blood. The part it hung from is left with a wound that leaks whatever that
## part holds. A part smaller than a block (extent) can be sucked up by a vacuum once
## it's loose, as what it's made of and what it holds.

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
## Damage it takes to tear off (or for the part the body is built on, to kill).
@export var toughness := 3.0
## Blood it holds when the creature's full of it.
@export var blood_capacity := 1.0
## Blood it uses per second just staying alive.
@export var upkeep := 0.001
## How bad a wound it leaves when it's torn off: the share of what the part it hung
## from holds that leaks out per second, before the wound clots.
@export var bleeding := 0.01
## What it's made of, as item counts (meat, wool).
@export var makeup: Dictionary[StringName, int] = {}

var creature: Creature
var parent: BodyPart
var children: Array[BodyPart] = []
var side: int = Side.MIDDLE
var damage := 0.0
var attached := true
## What it holds, by item id (blood, grass, water, dung), in item units.
var contents: Dictionary[StringName, float] = {}
## The wound where a part was torn off it: share of its contents leaked per second.
var wound := 0.0
## Where on it the wound is (the torn-off part's socket).
var wound_socket := Vector2.ZERO


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


## How far a global point is from the part's drawn shape, px (0 or less: on it). Parts
## that can't be hit (inside the body) are INF.
func hit_distance(_point: Vector2) -> float:
	return INF


## Carries a torn-off part's shape along as the piece it's on tumbles (`motion` takes
## where it was to where it is now).
func move_by(_motion: Transform2D) -> void:
	pass


## The part's outline in global space, roughly (for whether it's smaller than a block).
func extent() -> Rect2:
	return Rect2(creature.global_position, Vector2.ZERO)


func blood() -> float:
	return contents.get(&"blood", 0.0)


## Pays blood (its energy) from what it holds. Returns whether it had all of it.
func spend(amount: float) -> bool:
	var had := blood()
	contents[&"blood"] = maxf(had - amount, 0.0)
	return had >= amount


## Whether it has the blood to work properly.
func has_energy() -> bool:
	return blood() > blood_capacity * 0.05


## Draw order: lower is further back.
func layer() -> float:
	return float(side)


## State worth keeping between runs (the shape comes back from the seed).
func to_data() -> Dictionary:
	return {}


func load_data(_data: Dictionary) -> void:
	pass


## Distance from a point to a line segment.
static func segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))


## A size from the plan, varied for this creature.
func vary(value: float, rng: RandomNumberGenerator) -> float:
	return value * rng.randf_range(1.0 - size_variation, 1.0 + size_variation)


## A colour as it shows on this part's side of the body.
func shade(base: Color) -> Color:
	return base.darkened(1.0 - FAR_SHADE) if side == Side.FAR else base


## Forward along the creature's facing.
func forward() -> Vector2:
	return Vector2(creature.facing, 0.0)
