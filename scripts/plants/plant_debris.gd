class_name PlantDebris
extends RigidBody2D
## A cut or fallen piece of plant. It tumbles like any loose body, then crumbles away.

const LIFETIME := 25.0
const MASS_PER_AREA := 0.08

var flora: Flora
var species: PlantSpecies
var parts: Array[PlantPart]

var _age := 0.0


func _init(p_flora: Flora, p_species: PlantSpecies, p_parts: Array[PlantPart], global_xform: Transform2D) -> void:
	flora = p_flora
	species = p_species
	parts = p_parts
	transform = global_xform # Flora sits at the world origin.
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
	sprite.texture = art[0]
	sprite.position = art[1]
	add_child(sprite)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlantPart.unlink(parts)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		flora.crumble_parts(species, global_transform, parts)
		queue_free()

