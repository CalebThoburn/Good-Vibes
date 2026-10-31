class_name Thing
extends RefCounted
## Something a creature notices: one particular plant, block, creature, item, machine,
## pool of liquid or the player. Its kind ("plant:grass", "block:stone", "creature:sheep",
## "player", "machine", "item:grass", "liquid:water") is what the creature learns about; a creature only keeps
## track of the nearest of each kind.

var kind: StringName
var node: Object
## Plants: the leaf nearest the creature.
var leaf: PlantPart
## Blocks: the grid and cell.
var grid: BlockGrid
var cell := Vector2i.ZERO
## Liquids: the Liquids it's in (cell is the cell).
var liquids: Liquids


func _init(p_kind: StringName, p_node: Object) -> void:
	kind = p_kind
	node = p_node


## Where it is, global: a leaf's foot, a block's middle, a creature's body.
func point() -> Vector2:
	if liquids:
		return liquids.cell_center(cell)
	if grid:
		return grid.to_global(BlockGrid.cell_center(cell))
	if leaf:
		return node.to_global(leaf.end) + Vector2(0.0, -2.0)
	if node is Creature:
		return node.global_position + Vector2(0.0, -node.ride_height * 0.5)
	return node.global_position


## Whether it's still there to be acted on.
func valid() -> bool:
	if liquids:
		return Liquids.total(liquids.free.get(cell, Vector2.ZERO)) > 0.1
	if grid:
		return is_instance_valid(grid) and grid.has_block(cell)
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if leaf:
		return node.parts.has(leaf)
	if node is Creature:
		return not node.dead
	return true
