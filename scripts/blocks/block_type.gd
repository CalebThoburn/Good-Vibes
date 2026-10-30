class_name BlockType
extends Resource
## Definition of one kind of block. Put .tres files in res://data/blocks/ and the
## Blocks registry picks them up automatically.

## Stable name used to refer to this block in code and (later) save files.
@export var id: StringName
@export var display_name: String
## Mass per block, relative. Loose sections use this for their mass.
@export var density := 1.0
## How hard the block is to break. Not used yet.
@export var strength := 1.0

@export_group("Appearance")
## Base color of the generated placeholder texture.
@export var color := Color.MAGENTA
## How much per-pixel brightness variation the generated texture gets.
@export_range(0.0, 0.5) var texture_noise := 0.08
## Hand-made texture; overrides the generated one when set.
@export var texture: Texture2D

## Assigned by the registry at startup. Not stable between runs, so never save it.
var numeric_id := 0
