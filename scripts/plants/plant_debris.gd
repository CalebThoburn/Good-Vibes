class_name PlantDebris
extends RigidBody2D
## A cut or fallen piece of plant. It tumbles like any loose body, then crumbles away.
## Fallen grass tries to take root where it comes to rest instead.

const LIFETIME := 25.0
## Fallen grass gives up and crumbles sooner.
const CREEPER_LIFETIME := 6.0
## Below this speed (px/s) a piece has come to rest.
const RESTING_SPEED := 8.0
const MASS_PER_AREA := 0.08
## Square pixels of stem per piece of wood it gives when sucked up.
const AREA_PER_WOOD := 60.0

var flora: Flora
var species: PlantSpecies
var parts: Array[PlantPart]

var _age := 0.0


func _init(p_flora: Flora, p_species: PlantSpecies, p_parts: Array[PlantPart], global_xform: Transform2D) -> void:
	flora = p_flora
	species = p_species
	parts = p_parts
	transform = global_xform # Flora sits at the world origin.
	z_index = Plant.Z_BRANCHES
	collision_layer = BlockWorld.BLOCK_LAYER
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.PLAYER_LAYER | BlockWorld.MACHINE_LAYER
	var area := 0.0
	for part in parts:
		if part.kind == PlantPart.Kind.STEM:
			var rect := PlantRenderer.bar_rect(part)
			var shape := RectangleShape2D.new()
			shape.size = Vector2(rect.size).max(Vector2.ONE * 2.0)
			var collision := CollisionShape2D.new()
			collision.shape = shape
			collision.position = Vector2(rect.position) + Vector2(rect.size) * 0.5
			add_child(collision)
			area += part.length * part.thickness
		else:
			area += pow(PlantRenderer.leaf_size(species, part), 2.0) * 0.3
	mass = maxf(area * MASS_PER_AREA, 0.5)
	var art := PlantRenderer.render(species, parts, [PlantPart.Kind.STEM, PlantPart.Kind.LEAF])
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.material = SunShade.lit_material()
	sprite.texture = art[0]
	sprite.position = art[1]
	add_child(sprite)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlantPart.unlink(parts)


## How much wood this piece is worth.
func wood() -> int:
	var area := 0.0
	for part in parts:
		if part.kind == PlantPart.Kind.STEM:
			area += part.length * part.thickness
	return maxi(roundi(area / AREA_PER_WOOD), 1)


func _physics_process(delta: float) -> void:
	_age += delta
	var creeping := species.form == PlantSpecies.Form.CREEPER
	if creeping and _age > 0.4 and linear_velocity.length() < RESTING_SPEED and _replant():
		queue_free()
		return
	if _age > (CREEPER_LIFETIME if creeping else LIFETIME):
		flora.crumble_parts(species, global_transform, parts)
		queue_free()


## The middle of the piece, in its own space.
func _middle() -> Vector2:
	var total := Vector2.ZERO
	for part in parts:
		total += (part.start + part.end) * 0.5
	return total / parts.size()


## Grass that's come to rest takes root in the ground under it, if it can. Returns
## whether it did.
func _replant() -> bool:
	var center := global_transform * _middle()
	var query := PhysicsRayQueryParameters2D.create(center, center + Vector2.DOWN * 12.0, BlockWorld.BLOCK_LAYER, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and flora.try_sprout(species, hit.position, hit.normal)

