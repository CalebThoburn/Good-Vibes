class_name LooseItem
extends RigidBody2D
## Items lying loose in the world, like spilled blood or a dead creature's insides: a
## little lump that falls and rolls until a vacuum sucks it up, or after a while it's
## gone. Block items (dung) are dropped as real loose blocks instead, and liquids (water,
## blood) run free as liquid (see drop).

const LIFETIME := 180.0
const FADE_TIME := 3.0

var item_id: StringName
var count := 1

var _age := 0.0
var _color := Color.WHITE
var _size := Vector2.ONE


## Drops `count` of an item at a global point.
static func drop(world: BlockWorld, id: StringName, amount: int, at: Vector2, velocity := Vector2.ZERO) -> void:
	if amount <= 0:
		return
	if Liquids.KINDS.has(id): # Liquids run free rather than lying about.
		world.liquids.spill(at, id, amount)
		return
	var type := Items.get_type(id)
	if type.block:
		var half := Vector2.ONE * BlockGrid.CELL_SIZE * 0.5
		for i in amount:
			var center := at + Vector2(0.0, -BlockGrid.CELL_SIZE * i)
			if not world.is_area_free(center, half * 2.0):
				continue
			var cells: Dictionary[Vector2i, int] = {Vector2i.ZERO: Blocks.id_of(type.block)}
			world.spawn_body(cells, Transform2D(0.0, center - half)).linear_velocity = velocity
		return
	var item := LooseItem.new()
	item.item_id = id
	item.count = amount
	item._color = type.color
	item.position = at
	item.linear_velocity = velocity + Vector2(randf_range(-25.0, 25.0), randf_range(-50.0, -10.0))
	world.add_child(item)


func _ready() -> void:
	collision_layer = BlockWorld.CREATURE_LAYER # Where vacuums look for small loose things.
	collision_mask = BlockWorld.BLOCK_LAYER | BlockWorld.MACHINE_LAYER
	mass = 0.2
	var side := clampf(1.0 + sqrt(count), 2.0, 5.0)
	_size = Vector2(side, maxf(side - 1.0, 1.0))
	var shape := RectangleShape2D.new()
	shape.size = _size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	material = SunShade.lit_material()
	z_index = -1


func _physics_process(delta: float) -> void:
	_age += delta
	modulate.a = clampf((LIFETIME - _age) / FADE_TIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()


func _draw() -> void:
	var corner := (-_size * 0.5).round()
	draw_rect(Rect2(corner, _size), _color)
	draw_rect(Rect2(corner, Vector2(_size.x, 1.0)), _color.lightened(0.2))
