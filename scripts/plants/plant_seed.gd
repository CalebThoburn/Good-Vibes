class_name PlantSeed
extends Node2D
## A seed in flight. It sprouts if it lands on top of good soil (see Flora.try_sprout),
## and is lost otherwise.

const GRAVITY := 300.0
## How quickly the air slows its sideways drift.
const DRAG := 1.0
const LIFETIME := 12.0

var flora: Flora
var species: PlantSpecies
var velocity := Vector2.ZERO

var _age := 0.0


func _init(p_flora: Flora, p_species: PlantSpecies, p_velocity: Vector2) -> void:
	flora = p_flora
	species = p_species
	velocity = p_velocity
	visibility_layer = SunShade.NO_SHADE_LAYER


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	velocity.x *= maxf(1.0 - DRAG * delta, 0.0)
	var from := global_position
	var to := from + velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters2D.create(from, to, BlockWorld.BLOCK_LAYER))
	if not hit.is_empty():
		flora.try_sprout(species, hit.position, hit.normal)
		queue_free()
		return
	global_position = to


func _draw() -> void:
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), species.seed_color)
