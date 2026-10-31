class_name Player
extends CharacterBody2D
## The player can't touch blocks directly; everything goes through machines. Drills
## hurt the player (see hurt); health comes back slowly, and with none left the player
## starts again at the spawn point.

const GROUP := &"player"
const STARTING_TIDBITS: Dictionary[StringName, int] = {&"handle": 4, &"trigger": 8, &"launcher": 8, &"flip_flop": 6, &"drill": 4, &"vacuum": 4, &"nand": 6}
const STARTING_ITEMS: Dictionary[StringName, int] = {&"string": 12}
const MESSAGE_TIME := 2.5
## How long after being pulled the player keeps air control instead of ground grip.
const PULLED_GRIP_DELAY := 0.15
## Input actions for each Machine.Channel, in order.
const TRIGGER_ACTIONS: Array[StringName] = [&"trigger_q", &"trigger_e", &"trigger_space"]
## How close a wall has to be to jump off it.
const WALL_JUMP_REACH := 2.0
## How quickly the camera catches up with the player.
const CAMERA_SMOOTHING := 8.0

@export var world: BlockWorld
## Used when ropes and other machines pull on the player.
@export var mass := 30.0

@export_group("Health")
@export var max_health := 20.0
## Health regained per second, once it's been a while since the last hurt.
@export var heal_rate := 0.5
@export var heal_delay := 4.0

@export_group("Movement")
@export var move_speed := 150.0
@export var acceleration := 1400.0
## Lower than on the ground so swings and pulls keep their momentum. Only applies while
## steering; with no input the player keeps drifting.
@export var air_acceleration := 400.0
@export var jump_velocity := 270.0
## Added to (not set as) the upward speed when jumping off a wall.
@export var wall_jump_velocity := 230.0
## Horizontal push away from the wall.
@export var wall_jump_push := 160.0
## Impulse applied to loose blocks the player walks into.
@export var push_impulse := 20.0

@export_group("Dev mode")
## Flying speed in dev mode, in pixels per second.
@export var fly_speed := 260.0
## Seconds between breaks or placements while a button is held in dev mode.
@export var dev_edit_interval := 0.08

@export_group("Machines")
## How far away the player can place and pick up machines, in blocks.
@export var reach := 6.0

var inventory := Inventory.new()
## Dev mode (toggled with dev_mode, F1): fly through everything, and break and place blocks.
var dev_mode := false
## Set while a menu is open; stops picking up machines.
var ui_open := false

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _pulled_time := 0.0
var _dev_block := 0 # Index into Blocks.all() of the block dev mode places.
var _dev_edit_wait := 0.0
var health := 0.0
var _since_hurt := INF
var _health_bar := ColorRect.new()
var _health_back := ColorRect.new()

@onready var _cursor: BlockCursor = $BlockCursor
@onready var _held: HeldMachine = $HeldMachine
@onready var _message: Label = $HUD/Message
@onready var _sprite: Control = $Sprite
@onready var _dev_label: Label = $HUD/DevLabel
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group(GROUP)
	_sprite.material = SunShade.lit_material()
	global_position = world.spawn_position()
	for id in STARTING_TIDBITS:
		inventory.add_tidbits(id, STARTING_TIDBITS[id])
	for id in STARTING_ITEMS:
		inventory.add_items(id, STARTING_ITEMS[id])
	inventory.changed.connect(_on_inventory_changed)
	health = max_health
	_health_back.color = Color(0.0, 0.0, 0.0, 0.5)
	_health_back.position = Vector2(12.0, 36.0)
	_health_back.size = Vector2(124.0, 10.0)
	_health_bar.color = Blood.COLOR.lightened(0.15)
	_health_bar.position = Vector2(2.0, 2.0)
	_health_back.add_child(_health_bar)
	$HUD.add_child(_health_back)
	_update_health_bar()


func _process(_delta: float) -> void:
	# Smoothing runs on sped-up time while skipping; slowed to match, it doesn't overshoot.
	_camera.position_smoothing_speed = CAMERA_SMOOTHING / Engine.time_scale
	_held.aim_along(get_global_mouse_position() - global_position)
	# Draw on whole world pixels, like the blocks, so shading lines up with the sprite.
	_sprite.position = (global_position.round() - global_position) - _sprite.size * 0.5


func _physics_process(delta: float) -> void:
	if dev_mode:
		_fly()
		_dev_edit(delta)
	else:
		_move(delta)
	_interact()
	_since_hurt += delta
	if _since_hurt > heal_delay and health < max_health:
		health = minf(health + heal_rate * delta, max_health)
		_update_health_bar()
	if global_position.y > world.kill_y():
		global_position = world.spawn_position()
		velocity = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev_mode"):
		_set_dev_mode(not dev_mode)
	for channel in TRIGGER_ACTIONS.size():
		if event.is_action_pressed(TRIGGER_ACTIONS[channel]):
			_activate_machines(channel)
	if not dev_mode:
		return
	var blocks := Blocks.all()
	if event is InputEventKey and event.pressed and not event.echo:
		var slot: int = event.keycode - KEY_1
		if slot >= 0 and slot < blocks.size():
			_dev_block = slot
			_update_dev_label()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dev_block = posmod(_dev_block - 1, blocks.size())
			_update_dev_label()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dev_block = posmod(_dev_block + 1, blocks.size())
			_update_dev_label()


## Pushes the player like a rigid body of `mass`. While being pushed, ground grip is
## relaxed so things like ropes can actually drag the player.
func apply_impulse(impulse: Vector2) -> void:
	velocity += impulse / mass
	_pulled_time = PULLED_GRIP_DELAY


## Takes damage at a global point (from a drill). At no health, starts again at spawn.
func hurt(amount: float, at: Vector2) -> void:
	if dev_mode:
		return
	health -= amount
	_since_hurt = 0.0
	Blood.spray(self, at, 2, (at - global_position).normalized() + Vector2.UP)
	if health <= 0.0:
		Blood.spray(self, global_position, 30, Vector2.UP, 90.0)
		global_position = world.spawn_position()
		velocity = Vector2.ZERO
		health = max_health
		notify("You were ground up by a drill")
	_update_health_bar()


func _update_health_bar() -> void:
	_health_back.visible = health < max_health
	_health_bar.size = Vector2(120.0 * health / max_health, 6.0)


## Shows a short message on screen.
func notify(text: String) -> void:
	_message.text = text
	get_tree().create_timer(MESSAGE_TIME).timeout.connect(func() -> void:
		if _message.text == text:
			_message.text = "")


## Handles a machine dragged out of the inventory to a point in the world: dropping it
## on the player toggles equipping it, anywhere else places it.
func drop_machine(design: MachineDesign, global_point: Vector2) -> void:
	if Rect2(global_position - Vector2(10, 16), Vector2(20, 32)).has_point(global_point):
		if inventory.equipped == design:
			inventory.equip(null)
		elif not inventory.equip(design):
			notify("A machine needs a Handle to be equipped")
	elif global_position.distance_to(global_point) > reach * BlockGrid.CELL_SIZE:
		notify("Too far away")
	elif not world.can_place_machine(global_point):
		notify("Something is in the way")
	else:
		inventory.remove_machine(design)
		world.spawn_machine(design, global_point)


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity.y += _gravity * delta
	if Input.is_action_just_pressed(&"jump"):
		_jump()
	elif Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= 0.5 # Short hop.

	var direction := Input.get_axis(&"move_left", &"move_right")
	_pulled_time = maxf(_pulled_time - delta, 0.0)
	var grounded := is_on_floor() and _pulled_time == 0.0
	if grounded or direction != 0.0: # In the air, momentum carries unless you steer.
		var accel := acceleration if grounded else air_acceleration
		velocity.x = move_toward(velocity.x, direction * move_speed, accel * delta)
	move_and_slide()

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as RigidBody2D
		if body:
			body.apply_impulse(-collision.get_normal() * push_impulse, collision.get_position() - body.global_position)


func _jump() -> void:
	if is_on_floor():
		velocity.y = -jump_velocity
		return
	var wall_normal := _wall_normal()
	if wall_normal != Vector2.ZERO:
		# Adds rather than sets, so a fast fall isn't cancelled outright.
		velocity.y -= wall_jump_velocity
		velocity.x += wall_normal.x * wall_jump_push
		_pulled_time = PULLED_GRIP_DELAY # Don't let air control eat the push at once.


## The normal of a wall right beside the player, or ZERO if there's none.
func _wall_normal() -> Vector2:
	for side: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
		var collision := KinematicCollision2D.new()
		if test_move(global_transform, side * WALL_JUMP_REACH, collision) and absf(collision.get_normal().x) > 0.7:
			return collision.get_normal()
	return Vector2.ZERO


## Lets a carried creature out into the world at a point.
func drop_creature(creature: StoredCreature, global_point: Vector2) -> void:
	if global_position.distance_to(global_point) > reach * BlockGrid.CELL_SIZE:
		notify("Too far away")
	elif not world.is_area_free(global_point, Vector2.ONE * 6.0):
		notify("Something is in the way")
	else:
		inventory.remove_creature(creature)
		creature.release(world, global_point, Vector2.ZERO)


## Highlights a placed machine (or a creature small enough to carry) under the cursor;
## the pick-up button grabs it.
func _interact() -> void:
	var target := get_global_mouse_position()
	var in_reach := not ui_open and global_position.distance_to(target) <= reach * BlockGrid.CELL_SIZE
	var machine := world.machine_at(target) if in_reach else null
	if machine == null:
		var creature := _small_creature_at(target) if in_reach else null
		if creature == null:
			_cursor.hide()
			return
		var bounds := Rect2(creature.global_position - creature.box_size * Vector2(0.5, 1.0), creature.box_size).grow(2.0)
		_cursor.show_rect(Transform2D.IDENTITY, bounds, Color(1, 1, 1, 0.9))
		if Input.is_action_just_pressed(&"pick_up"):
			if inventory.free_slots() > 0:
				inventory.add_creature(StoredCreature.capture(creature))
			else:
				notify("No free machine slots")
		return
	var size := Vector2.ONE * MachineDesign.SIZE * MachineDesign.TIDBIT_PIXELS
	_cursor.show_rect(machine.global_transform, Rect2(-size * 0.5, size), Color(1, 1, 1, 0.9))
	if Input.is_action_just_pressed(&"pick_up"):
		if inventory.add_machine(machine.view.machine.design):
			machine.queue_free()
		else:
			notify("No free machine slots")


## A live creature small enough to carry, at (or very near) a point.
func _small_creature_at(point: Vector2) -> Creature:
	for creature: Creature in get_tree().get_nodes_in_group(Creature.GROUP):
		if not creature.dead and creature.global_position.distance_to(point) < 24.0 and creature.small():
			var middle := creature.global_position + Vector2(0.0, -creature.ride_height)
			if creature.part_at(point) or middle.distance_to(point) < 5.0:
				return creature
	return null


func _set_dev_mode(on: bool) -> void:
	dev_mode = on
	collision_mask = 0 if on else BlockWorld.BLOCK_LAYER | BlockWorld.MACHINE_LAYER # Through everything.
	velocity = Vector2.ZERO
	_dev_label.visible = on
	_update_dev_label()


func _update_dev_label() -> void:
	_dev_label.text = "DEV MODE (F1)   %s   LMB break  RMB place  wheel/1-%d block  WASD fly" \
			% [Blocks.all()[_dev_block].display_name, Blocks.all().size()]


## Dev mode: flies in any direction, through everything.
func _fly() -> void:
	var direction := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"jump", &"move_down"))
	velocity = direction.normalized() * fly_speed
	move_and_slide()


## Dev mode: the mouse buttons break whatever block (or plant part) is under the cursor,
## or place the chosen block. Placed blocks stay put, even floating.
func _dev_edit(delta: float) -> void:
	_dev_edit_wait = maxf(_dev_edit_wait - delta, 0.0)
	if ui_open or _dev_edit_wait > 0.0:
		return
	var target := get_global_mouse_position()
	if Input.is_action_pressed(&"pick_up") and world.machine_at(target) == null:
		var plant := world.flora.part_at(target)
		var block := world.block_at(target)
		if not plant.is_empty():
			plant.plant.cut(plant.part)
		elif not block.is_empty():
			block.grid.remove_block(block.cell)
		_dev_edit_wait = dev_edit_interval
	elif Input.is_action_pressed(&"place"):
		var cell := world.terrain.global_to_cell(target)
		if not world.terrain.has_block(cell):
			world.terrain.set_block(cell, Blocks.id_of(Blocks.all()[_dev_block].id))
			_dev_edit_wait = dev_edit_interval


## A trigger key activates the equipped machine and any placed machine under the cursor.
func _activate_machines(channel: Machine.Channel) -> void:
	if _held.view.machine:
		_held.view.machine.activate(channel)
	var hovered := world.machine_at(get_global_mouse_position())
	if hovered:
		hovered.view.machine.activate(channel)


func _on_inventory_changed() -> void:
	if _held.get_design() != inventory.equipped:
		_held.hold(inventory.equipped, world, self)
