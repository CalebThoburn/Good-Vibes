class_name PlantPart
extends RefCounted
## One appendage of a plant: a stem segment, a root segment, or a leaf. Segments grow at
## right angles and lengthen over time; positions are worked out from the structure (see
## Plant._layout), so a growing branch carries everything beyond it along.

enum Kind { STEM, ROOT, LEAF }

var kind: Kind
var parent: PlantPart
var children: Array[PlantPart] = []
## Stems and roots: which way it grows (always along an axis).
var direction := Vector2i.UP
## Stems and roots: current length, growing toward target_length, which starts at
## base_length and can stretch as the part carries more of the plant.
var length := 0.0
var target_length := 0.0
var base_length := 0.0
## Creeping stems: the sideways way the runner is spreading, kept through climbs and drops.
var run := Vector2i.ZERO
## Stems and roots: width in pixels. Leaves: 1 (they're quick to cut).
var thickness := 1.0
## Leaves: where it sits relative to the end of the stem it's on (a square's center, or
## the foot of a grass blade).
var offset := Vector2.ZERO
## Which layer it's drawn in: -1 behind, 0 middle, 1 in front.
var depth := 0
## Seconds of plant time since it grew.
var age := 0.0
## Leaves: a random phase so they don't all sway together.
var phase := 0.0
## Leaves: which speckle pattern it's drawn with.
var variant := 0
## Leaves: the size it grows to, set by where it sits in the crown.
var size_cap := 0.0
## Leaves: one of the tree's main leaf masses, rather than a small leaf on a branch end.
var core := false

## Worked out by Plant._layout, in the plant's space.
var start := Vector2.ZERO
## Stems and roots: the far end. Leaves: the center (blades: the foot).
var end := Vector2.ZERO

## Seconds' worth of going short on energy or nutrients.
var starvation := 0.0
## How long it's been useless: a leaf not earning its upkeep, a branch with no leaves, a
## root outside soil.
var idle := 0.0
## Leaves: the light last measured at the leaf (0-1).
var light := 1.0

# Per-step bookkeeping, as Vector2(energy, nutrients).
var production := Vector2.ZERO
var need := Vector2.ZERO
var met := Vector2.ZERO
var flow := Vector2.ZERO # Left over after feeding this part, heading for the base.

var leaves_carried := 0
var roots_carried := 0


func _init(p_kind: Kind, p_parent: PlantPart) -> void:
	kind = p_kind
	parent = p_parent


## Breaks the parent/child links between parts so they can be freed (parents and
## children refer to each other, which would otherwise keep them alive).
static func unlink(parts: Array[PlantPart]) -> void:
	for part in parts:
		part.parent = null
		part.children.clear()


## Places this part from its parent's current shape.
func layout() -> void:
	if parent:
		# Roots grow from the bottom of the stem they belong to, everything else from the top.
		start = parent.start if kind == Kind.ROOT and parent.kind == Kind.STEM else parent.end
	end = start + offset if kind == Kind.LEAF else start + Vector2(direction) * length


func count_children(child_kind: Kind) -> int:
	var count := 0
	for child in children:
		if child.kind == child_kind:
			count += 1
	return count


## Directions its children of a kind already grow in.
func child_directions(child_kind: Kind) -> Array[Vector2i]:
	var used: Array[Vector2i] = []
	for child in children:
		if child.kind == child_kind:
			used.append(child.direction)
	return used
