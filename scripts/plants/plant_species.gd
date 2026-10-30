class_name PlantSpecies
extends Resource
## How a kind of plant looks, grows, and what it needs. Each kind is a .tres in
## res://data/plants/. Amounts that come in pairs are Vector2(energy, nutrients), and
## rates are per second.

## Trees branch upward; creepers (grass) spread sideways over the ground.
enum Form { TREE, CREEPER }

@export var id: StringName
@export var display_name: String
@export var form := Form.TREE
## Most of this species alive at once.
@export var max_population := 30
## Seeds won't sprout closer than this to another of the same species, in pixels.
@export var min_spacing := 48.0
## Whether its leaves shade other plants.
@export var casts_shade := true

@export_group("Shape")
## Length a segment grows to, in pixels. Segments grow at right angles.
@export var segment_length := 16.0
## Random spread of segment lengths, as a fraction.
@export var segment_length_variation := 0.35
## New segments start at this fraction of their length...
@export var initial_length := 0.3
## ...and lengthen by this many pixels per second until they get there.
@export var elongation_rate := 1.0
@export var min_thickness := 2.0
## Stems thicken with the square root of the leaves they carry (the pipe model)...
@export var thickness_per_leaf := 0.5
## ...and with age, in pixels per second.
@export var thickening := 0.01
@export var max_thickness := 7.0
@export var root_thickness := 2.0
## Leaves grow from min_leaf_size over leaf_grow_time. Leaves on the branch ends stop at
## tip_leaf_size. A tree's main leaf masses (one, or up to three on big trees) grow with
## the tree, from core_leaf_size up to max_leaf_size.
@export var min_leaf_size := 3.0
@export var tip_leaf_size := 8.0
@export var core_leaf_size := 12.0
@export var max_leaf_size := 28.0
## Parts per main leaf mass: a tree gets another (up to three) for every this many.
@export var parts_per_core := 45
@export var leaf_grow_time := 40.0
## The leaf size that photosynthesis and leaf_upkeep are given for; leaves make and cost
## in proportion to their area.
@export var leaf_area_size := 8.0
## Chance a branch carrying on from a tip jogs sideways before going on. Side branches
## always turn a corner.
@export var jog_chance := 0.5
## Trees: leaves only grow above this fraction of the tree's height; lower ones are shed.
@export var crown_start := 0.4
## Trees: how much a stem stretches with the square root of the leaves it carries, so
## the trunk keeps growing from the bottom and lifts the crown. Capped at 2.5× its
## starting length.
@export var trunk_stretch := 0.15

@export_group("Creeping")
## How many blocks up a runner can climb, and down it can drop, from where it started.
@export var max_climb := 2
@export var max_drop := 3
## Light needed before blades grow taller once there's nowhere left to spread.
@export var tuft_light := 0.6
## Blades grow up to this many times tip_leaf_size as the plant tufts up.
@export var max_tuft := 2.0
## Most stems that can grow from one stem.
@export var max_branches := 2
## Most leaves on one stem.
@export var leaves_per_tip := 3
## Size limit in parts. Each plant gets its own, between 55% and 115% of this.
@export var max_parts := 80
## How much new stems favor growing upward over growing toward light.
@export var upward_bias := 0.12

@export_group("Needs")
## Energy a leaf makes in full light.
@export var photosynthesis := 2.0
## Nutrients a root draws while its tip is in soil.
@export var root_uptake := 0.8
## Block types roots can grow into and draw from.
@export var soil: Array[StringName] = [&"dirt", &"dung"]
## Upkeep per leaf of leaf_area_size.
@export var leaf_upkeep := Vector2(0.5, 0.08)
## Upkeep per square pixel (length × thickness) of stem, and of root.
@export var wood_upkeep := Vector2(0.006, 0.001)
@export var root_upkeep := Vector2(0.002, 0.0005)
## How long a part can go short before it falls apart, in seconds' worth of shortfall.
@export var starve_time := 20.0
## Leaves that don't earn their upkeep, branches whose own leaves don't pay for them,
## and roots out of soil are shed after this long.
@export var shed_time := 25.0
## Stored resources allowed per part, on top of a small base amount.
@export var reserve_per_part := Vector2(1.2, 0.8)
@export var sapling_reserves := Vector2(6.0, 4.0)

@export_group("Growth")
## Average plant-seconds between new parts; each step has a matching chance.
@export var growth_interval := 2.0
@export var stem_cost := Vector2(3.0, 1.5)
@export var leaf_cost := Vector2(2.0, 0.8)
@export var root_cost := Vector2(2.0, 0.5)

@export_group("Seeds")
## Parts a plant needs before it starts making seeds.
@export var maturity := 25
@export var seed_cost := Vector2(8.0, 4.0)
## Average plant-seconds between seeds once mature.
@export var seed_interval := 25.0
@export var seed_speed := 60.0

@export_group("Looks")
@export var bark_color := Color(0.4, 0.27, 0.16)
@export var root_color := Color(0.55, 0.42, 0.3)
@export var leaf_color := Color(0.3, 0.62, 0.22)
## Leaves fade toward this as they starve.
@export var dying_leaf_color := Color(0.7, 0.6, 0.2)
@export var seed_color := Color(0.5, 0.35, 0.15)

@export_group("Toughness")
## Drill ticks per pixel of thickness to cut through a part.
@export var wood_strength := 1.5
