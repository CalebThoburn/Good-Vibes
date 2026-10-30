class_name Plant
extends Node2D
## A living plant: a branching structure of parts (PlantPart) standing on a terrain
## block. Leaves turn light into energy and roots in soil draw nutrients. Both flow
## through the plant into one pool, which feeds leaves and roots first and then stems from
## the trunk outward. A part that goes short for too long falls apart, taking everything
## beyond it with it.
##
## Spare resources go into growing whatever the plant is shortest of: roots for
## nutrients, leaves and stems for energy. Stems grow at right angles and lengthen and
## thicken with age. Two forms (PlantSpecies.Form):
## - Trees branch upward. Every branch turns a corner and gets a small leaf on its tip,
##   and the tree grows one main leaf mass on its trunk line (a few on big trees). Leaves
##   stay in the crown, and the trunk keeps stretching to lift the crown. Branches cost
##   energy, and one whose own leaves can't pay for it is shed, so trees stay covered.
##   Branches are drawn in one layer; each leaf patch sits in a layer behind or in front
##   of them, and the two leaf layers shift a little against the branches as the camera
##   passes. All of it is behind the player.
## - Creepers (grass) send runners sideways over the ground, climbing up and dropping
##   down steps within limits, with blades along them that grow taller only when there's
##   nowhere left to spread and the light is good. Drawn in front of the player.
## Stepped by Flora's random ticks.

## Each leaf re-measures its light every this many steps; they take turns.
const LIGHT_ROUNDS := 8
## Leaf layers: behind the branches and in front of them.
const LEAF_DEPTHS: Array[int] = [-1, 1]
## Draw order, back to front (blocks are at 0, in front of all of it). Every layer of a
## tree is behind the player (who's at -2), and grass is in front of the player.
const Z_ROOTS := -6
const Z_BACK_LEAVES := -5
const Z_BRANCHES := -4
const Z_FRONT_LEAVES := -3
const Z_GRASS := -1
## How far a leaf layer shifts per pixel the camera is off to the side of the plant.
const LAYER_PARALLAX := 0.012
## Back leaves are drawn a little darker so the layers read apart.
const BACK_TINT := Color(0.8, 0.8, 0.87)
## Plants further than this from the camera's center (world px) skip drawing updates.
const ACTIVE_REACH := 500.0
## Seconds between redraws of a plant's art while it's changing.
const REDRAW_INTERVAL := 0.4
## Creeping runners sit this far above the ground they cover, in pixels.
const RUNNER_HEIGHT := 1.0
## New branches won't spend reserves below this many seconds of running at a loss.
const RESERVE_SECONDS := 15.0
## Trees only add branches while their leaves make this many times what the tree uses,
## or their reserves are full anyway.
const BRANCH_SURPLUS := 1.1

static var _wind: ShaderMaterial

var species: PlantSpecies
var flora: Flora
## The terrain cell the plant stands on. If it goes, the plant falls.
var anchor_cell: Vector2i
## Every part, parents always before their children. parts[0] is the base stem.
var parts: Array[PlantPart] = []
## Stored (energy, nutrients).
var reserves := Vector2.ZERO
var age := 0.0

var _rng := RandomNumberGenerator.new()
## How readily this plant grows and seeds compared to others of its kind.
var _vigor := 1.0
## This plant's size limit, in parts; individuals of a species top out at different sizes.
var _max_parts := 0
## Creepers: how much taller than usual its blades grow (1 = not at all).
var _tuft := 1.0
# Totals from the last step, as Vector2(energy, nutrients).
var _supply := Vector2.ZERO
var _demand := Vector2.ZERO
# How much more it used than it made per second, from the last step (0 if it made more).
var _drain_rate := Vector2.ZERO
var _light_round := 0
var _roots := Sprite2D.new()
var _wood := Sprite2D.new()
# Per leaf depth (-1 behind the branches, 1 in front).
var _leaves: Dictionary[int, Sprite2D] = {}
var _hitbox := Area2D.new()
# Each leaf's drawn decline level and size; the art is redrawn when these change.
var _leaf_levels: Dictionary[PlantPart, int] = {}
var _leaf_sizes: Dictionary[PlantPart, int] = {}
var _art_dirty := true
# Where each leaf layer's art sits before parallax.
var _leaf_origins: Dictionary[int, float] = {}
var _redraw_wait := 0.0
# Shade cells this plant's leaves are counted in (see Flora.shade).
var _shade_cells: Array[Vector2i] = []


func _init() -> void:
	if _wind == null:
		_wind = ShaderMaterial.new()
		_wind.shader = preload("res://shaders/leaf_wind.gdshader")
	_roots.centered = false
	_roots.z_index = Z_ROOTS # Behind the terrain, so roots stay hidden in the ground.
	add_child(_roots)
	_wood.centered = false
	_wood.z_index = Z_BRANCHES
	_wood.material = SunShade.lit_material()
	add_child(_wood)
	for depth in LEAF_DEPTHS:
		var leaves := Sprite2D.new()
		leaves.centered = false
		leaves.material = _wind
		leaves.z_index = Z_BACK_LEAVES if depth < 0 else Z_FRONT_LEAVES
		if depth < 0:
			leaves.modulate = BACK_TINT
		add_child(leaves)
		_leaves[depth] = leaves
	_hitbox.collision_layer = BlockWorld.PLANT_LAYER
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	add_child(_hitbox)


## Starts the plant as a sapling (or a sprig of grass).
func setup(p_species: PlantSpecies, p_flora: Flora, p_anchor_cell: Vector2i, seed_value: int) -> void:
	species = p_species
	flora = p_flora
	anchor_cell = p_anchor_cell
	_rng.seed = seed_value
	_vigor = _rng.randf_range(0.6, 1.4)
	_max_parts = roundi(species.max_parts * _rng.randf_range(0.55, 1.15))
	reserves = species.sapling_reserves
	if _creeping():
		_wood.z_index = Z_GRASS # In front of the player.
		_leaves[1].z_index = Z_GRASS
		var base := _add_segment(PlantPart.Kind.STEM, null, Vector2i.UP, RUNNER_HEIGHT, 0)
		base.length = RUNNER_HEIGHT
		_add_leaf(base, Vector2.ZERO)
	else:
		var base := _add_segment(PlantPart.Kind.STEM, null, Vector2i.UP, species.segment_length, 0)
		_add_leaf(base, Vector2(0.0, -species.min_leaf_size * 0.5))
	_add_segment(PlantPart.Kind.ROOT, parts[0], Vector2i.DOWN, species.segment_length * 0.6, 0)
	_rebuild()


func to_data() -> Dictionary:
	var index: Dictionary[PlantPart, int] = {}
	var saved := []
	for part in parts:
		index[part] = saved.size()
		saved.append(part.to_data(index.get(part.parent, -1)))
	return {species = species.id, anchor = anchor_cell, position = position, reserves = reserves, age = age,
			vigor = _vigor, max_parts = _max_parts, tuft = _tuft, rng = _rng.state, parts = saved}


## Rebuilds a saved plant (see to_data).
func restore(p_species: PlantSpecies, p_flora: Flora, data: Dictionary) -> void:
	species = p_species
	flora = p_flora
	anchor_cell = data.anchor
	position = data.position
	reserves = data.reserves
	age = data.age
	_vigor = data.vigor
	_max_parts = data.max_parts
	_tuft = data.tuft
	_rng.state = data.rng
	if _creeping():
		_wood.z_index = Z_GRASS
		_leaves[1].z_index = Z_GRASS
	for saved: Dictionary in data.parts:
		var parent: PlantPart = parts[saved.parent] if saved.parent >= 0 else null
		var part := PlantPart.from_data(saved, parent)
		if parent:
			parent.children.append(part)
		parts.append(part)
	_rebuild()


func step(dt: float) -> void:
	age += dt
	if not flora.world.terrain.has_block(anchor_cell): # Runners are checked when the terrain changes.
		fall()
		return
	_measure(dt)
	_distribute()
	var changed := _shed_failing_parts(dt)
	if is_queued_for_deletion():
		return
	changed = _mature(dt) or changed
	changed = _grow(dt) or changed
	_try_seed(dt)
	for part in parts:
		if part.kind == PlantPart.Kind.LEAF:
			var level := PlantRenderer.leaf_level(species, part)
			var size := PlantRenderer.leaf_size(species, part)
			if _leaf_levels.get(part, -1) != level or _leaf_sizes.get(part, -1) != size:
				_leaf_levels[part] = level
				_leaf_sizes[part] = size
				_art_dirty = true
	if changed:
		_rebuild()


## Lets go of anything the ground has gone from under: the whole plant if its anchor
## block is gone, or for creepers, any runner with a pixel over empty air or with no wall
## left to climb. Returns whether the plant is still standing.
func check_support() -> bool:
	if not flora.world.terrain.has_block(anchor_cell):
		fall()
		return false
	if not _creeping():
		return true
	for part in parts.duplicate():
		if part == parts[0] or part.kind != PlantPart.Kind.STEM or not parts.has(part):
			continue
		var held := true
		if part.direction.y == 0: # Lying on the ground: every pixel needs ground under it.
			for step in roundi(part.length) + 1:
				if not _ground_under(part.start + Vector2(part.direction) * step):
					held = false
					break
		else: # Up or down a wall.
			var wall := Vector2(part.run) * (1.0 if part.direction == Vector2i.UP else -1.0)
			held = _solid_at((part.start + part.end) * 0.5 + wall * 2.0)
		if not held:
			cut(part)
	return true


## Cuts a part off, along with everything beyond it. Cutting the base fells the plant.
func cut(part: PlantPart) -> void:
	if part == parts[0]:
		fall()
		return
	flora.drop_debris(self, _remove_subtree(part))
	_rebuild()


## Bitten off by a grazing creature: the leaf is gone, and nothing falls. A plant is
## never grazed down to nothing, so it can grow back. Returns how much was eaten, from
## around 0.5 for a small leaf to 1 for a full-grown one, or 0 if it couldn't be.
func graze(part: PlantPart) -> float:
	if part.kind != PlantPart.Kind.LEAF or not parts.has(part) or is_queued_for_deletion():
		return 0.0
	var leaves := 0
	for other in parts:
		if other.kind == PlantPart.Kind.LEAF:
			leaves += 1
	if leaves <= 1:
		return 0.0
	var eaten := clampf(PlantRenderer.leaf_size(species, part) / species.max_leaf_size, 0.3, 1.0)
	PlantPart.unlink(_remove_subtree(part))
	_rebuild()
	return eaten


## The plant comes off its anchor: everything above ground falls, the roots crumble.
func fall() -> void:
	flora.drop_debris(self, parts)
	flora.remove_plant(self)


## Everything crumbles away.
func die() -> void:
	flora.crumble_parts(species, global_transform, parts)
	flora.remove_plant(self)


## Stops counting toward the shade other plants get.
func clear_shade() -> void:
	flora.shade(_shade_cells, -1)
	_shade_cells.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PlantPart.unlink(parts)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var off_center := camera.get_screen_center_position().x - global_position.x
	if absf(off_center) > ACTIVE_REACH:
		return # Off screen: art waits until it's seen.
	_redraw_wait -= delta
	if _art_dirty and _redraw_wait <= 0.0:
		_render_art()
	if not _creeping(): # After any redraw, so the layers never show unshifted for a frame.
		for depth in LEAF_DEPTHS: # Front leaves slide against the camera's motion, back ones with it.
			_leaves[depth].position.x = roundf(_leaf_origins.get(depth, 0.0) - off_center * depth * LAYER_PARALLAX)


func _render_art() -> void:
	_art_dirty = false
	_redraw_wait = REDRAW_INTERVAL
	var wood := PlantRenderer.render(species, parts, [PlantPart.Kind.STEM])
	_wood.texture = wood[0]
	_wood.position = wood[1]
	for depth in LEAF_DEPTHS:
		var leaves := PlantRenderer.render_leaves(species, parts, depth, _leaf_levels)
		_leaves[depth].texture = leaves[0]
		_leaves[depth].position = leaves[1]
		_leaf_origins[depth] = leaves[1].x
	var roots := PlantRenderer.render(species, parts, [PlantPart.Kind.ROOT])
	_roots.texture = roots[0]
	_roots.position = roots[1]


func _creeping() -> bool:
	return species.form == PlantSpecies.Form.CREEPER


func _add_segment(kind: PlantPart.Kind, parent: PlantPart, direction: Vector2i, target_length: float, depth: int) -> PlantPart:
	var part := PlantPart.new(kind, parent)
	part.direction = direction
	part.target_length = target_length
	part.base_length = target_length
	part.length = minf(target_length, maxf(target_length * species.initial_length, 2.0))
	part.thickness = species.min_thickness if kind == PlantPart.Kind.STEM else species.root_thickness
	part.depth = depth
	if parent and parent.kind == PlantPart.Kind.STEM:
		part.run = direction if direction.y == 0 else parent.run
	return _attach(part)


func _add_leaf(parent: PlantPart, offset: Vector2) -> PlantPart:
	var part := PlantPart.new(PlantPart.Kind.LEAF, parent)
	part.offset = offset.round()
	part.size_cap = _leaf_cap(parent)
	part.depth = _leaf_depth()
	part.phase = _rng.randf() * TAU
	part.variant = _rng.randi() % PlantRenderer.LEAF_VARIANTS
	_attach(part)
	part.light = flora.light_at(to_global(part.end))
	return part


func _attach(part: PlantPart) -> PlantPart:
	if part.parent:
		part.parent.children.append(part)
	parts.append(part)
	part.layout()
	return part


## Takes a part and everything beyond it out of the plant, and returns them.
func _remove_subtree(part: PlantPart) -> Array[PlantPart]:
	var removed: Dictionary[PlantPart, bool] = {part: true}
	for other in parts: # Parents come first, so this reaches every descendant.
		if other.parent and removed.has(other.parent):
			removed[other] = true
	part.parent.children.erase(part)
	var gone: Array[PlantPart] = []
	var kept: Array[PlantPart] = []
	for other in parts:
		(gone if removed.has(other) else kept).append(other)
	parts = kept
	for other in gone:
		_leaf_levels.erase(other)
		_leaf_sizes.erase(other)
	return gone


#region Resources

## Works out what each part makes and needs this step.
func _measure(dt: float) -> void:
	_supply = Vector2.ZERO
	_demand = Vector2.ZERO
	_light_round = (_light_round + 1) % LIGHT_ROUNDS
	var leaf_index := 0
	for part in parts:
		match part.kind:
			PlantPart.Kind.LEAF:
				if leaf_index % LIGHT_ROUNDS == _light_round:
					part.light = flora.light_at(to_global(_leaf_middle(part)))
				leaf_index += 1
				# Leaves make and cost in proportion to their area.
				var area := pow(PlantRenderer.leaf_size(species, part) / species.leaf_area_size, 2.0)
				part.production = Vector2(part.light * species.photosynthesis * area, 0.0) * dt
				part.need = species.leaf_upkeep * area * dt
			PlantPart.Kind.STEM:
				part.production = Vector2.ZERO
				part.need = species.wood_upkeep * part.length * part.thickness * dt
			PlantPart.Kind.ROOT:
				var fertility := flora.fertility(to_global(part.end), species)
				part.production = Vector2(0.0, species.root_uptake * fertility * dt)
				part.need = species.root_upkeep * part.length * part.thickness * dt
		_supply += part.production
		_demand += part.need
	_drain_rate = ((_demand - _supply) / dt).max(Vector2.ZERO)


## Feeds every part from what the whole plant makes plus its reserves: leaves and roots
## first (they're what keep it going), then stems from the trunk outward. So in hard
## times it's the outer branches that go short and get shed, not the trunk. Also notes,
## for each part, whether it and everything beyond it make what they cost.
func _distribute() -> void:
	for i in range(parts.size() - 1, -1, -1): # Children before parents.
		var part := parts[i]
		part.flow = part.production - part.need
		for child in part.children:
			part.flow += child.flow
		part.pays_its_way = part.flow.x >= 0.0
		reserves += part.production
	for producers_first in [true, false]:
		for part in parts: # Parents before children: the trunk before its branches.
			if (part.kind != PlantPart.Kind.STEM) == producers_first:
				part.met = part.need.min(reserves)
				reserves -= part.met
	reserves = reserves.min(_reserve_cap())


## The most it can store.
func _reserve_cap() -> Vector2:
	return Vector2(10.0, 10.0) + species.reserve_per_part * parts.size()


## Lets go of parts that have gone short or been useless for too long. Returns whether
## anything went.
func _shed_failing_parts(dt: float) -> bool:
	var crown_base := _crown_base()
	var failing: Array[PlantPart] = []
	for part in parts:
		var fed := _fed(part)
		if fed < 0.98:
			part.starvation += dt * (1.0 - fed)
		else:
			part.starvation = maxf(part.starvation - dt, 0.0)
		var useless := false
		match part.kind:
			PlantPart.Kind.LEAF: # Not earning its keep, or below a tree's crown (main masses can hang lower).
				var lowest := crown_base * 0.6 if part.core else crown_base
				useless = part.production.x < part.need.x or -part.end.y < lowest
			PlantPart.Kind.STEM:
				# A branch its own leaves can't pay for, once they've had time to grow (the
				# trunk line is spared).
				var unpaid := not part.pays_its_way and part.age > species.leaf_grow_time
				useless = part != parts[0] and (part.leaves_carried == 0 or unpaid) \
						and part.leaves_carried * 2 < parts[0].leaves_carried
			PlantPart.Kind.ROOT:
				useless = part.production.y == 0.0
		part.idle = part.idle + dt if useless else 0.0
		if part.starvation > species.starve_time or part.idle > species.shed_time:
			failing.append(part)
	if failing.is_empty():
		return false
	if failing.has(parts[0]):
		die()
		return true
	for part in failing:
		if parts.has(part): # Not already gone with a failing parent.
			var gone := _remove_subtree(part)
			flora.crumble_parts(species, global_transform, gone)
			PlantPart.unlink(gone)
	return true


## The share of its needs a part got this step (the scarcer of the two).
static func _fed(part: PlantPart) -> float:
	var fed := 1.0
	if part.need.x > 0.0:
		fed = minf(fed, part.met.x / part.need.x)
	if part.need.y > 0.0:
		fed = minf(fed, part.met.y / part.need.y)
	return fed


## A roll that succeeds with probability `odds` (scaled by vigor).
func _chance(odds: float) -> bool:
	return _rng.randf() < odds * _vigor


## Spends reserves on growth. With `keep_buffer` (for branches, which cost to keep), only
## if it leaves enough to ride out RESERVE_SECONDS of the plant running at a loss.
func _pay(cost: Vector2, keep_buffer := false) -> bool:
	var left := reserves - cost
	var keep := _drain_rate * RESERVE_SECONDS if keep_buffer else Vector2.ZERO
	if left.x < keep.x or left.y < keep.y:
		return false
	reserves = left
	return true

#endregion


#region Growth

## Ages every part: segments lengthen toward their target (stopping at anything in the
## way) and leaves grow. Returns whether any segment's drawn length changed.
func _mature(dt: float) -> bool:
	var changed := false
	for part in parts:
		part.age += dt
		if part.kind == PlantPart.Kind.LEAF or part.length >= part.target_length:
			continue
		var longer := minf(part.length + species.elongation_rate * dt, part.target_length)
		var tip := to_global(part.start + Vector2(part.direction) * longer)
		var blocked := flora.is_solid(tip) if part.kind == PlantPart.Kind.STEM else not flora.is_soil(tip, species)
		if blocked:
			part.target_length = part.length # Grown as far as it can.
			continue
		changed = changed or roundi(longer) != roundi(part.length)
		part.length = longer
	return changed


## Sometimes grows one new part: on average once per growth interval, scaled by
## vigor, but by chance each step. Returns whether it did.
func _grow(dt: float) -> bool:
	if parts.size() >= _max_parts or not _chance(dt / species.growth_interval):
		return false
	var energy_ratio := _supply.x / maxf(_demand.x, 0.0001)
	var nutrient_ratio := _supply.y / maxf(_demand.y, 0.0001)
	var short_of_nutrients := nutrient_ratio < energy_ratio
	if short_of_nutrients and _grow_root():
		return true
	if _creeping():
		return _grow_creeper()
	# Roots only when they're what's short: they cost energy to keep too.
	return _grow_shoot() or (short_of_nutrients and _grow_root())


## A leaf or a stem: a leaf first on any bare branch end, otherwise leaning toward
## leaves. New branches only with energy to spare, since they cost to keep.
func _grow_shoot() -> bool:
	# Branch only once most leaves have filled out, and with energy to spare.
	var leaves := parts.filter(func(part: PlantPart) -> bool: return part.kind == PlantPart.Kind.LEAF)
	var young := leaves.filter(func(part: PlantPart) -> bool: return part.age < species.leaf_grow_time).size()
	var can_branch := young * 3 <= leaves.size() \
			and (_supply.x >= _demand.x * BRANCH_SURPLUS or reserves.x >= _reserve_cap().x * 0.9)
	if not can_branch:
		return _grow_leaf()
	if not _bare_tips().is_empty() or _rng.randf() < 0.6:
		return _grow_leaf() or _grow_stem()
	return _grow_stem() or _grow_leaf()


## Stem ends with no leaves on them.
func _bare_tips() -> Array[PlantPart]:
	var bare: Array[PlantPart] = []
	for part in parts:
		if part.kind == PlantPart.Kind.STEM and part.count_children(PlantPart.Kind.STEM) == 0 \
				and part.count_children(PlantPart.Kind.LEAF) == 0:
			bare.append(part)
	return bare


## A leaf in the crown: a main leaf mass if the tree is due one, else a small leaf, on a
## bare branch end if there is one.
func _grow_leaf() -> bool:
	if _core_count() < _cores_wanted():
		return _grow_core()
	var crown_base := _crown_base()
	var stems: Array[PlantPart] = _bare_tips()
	if stems.is_empty():
		for part in parts:
			if part.kind == PlantPart.Kind.STEM and part.count_children(PlantPart.Kind.LEAF) < species.leaves_per_tip \
					and -part.end.y >= crown_base:
				stems.append(part)
	if stems.is_empty() or not _pay(species.leaf_cost):
		return false
	var stem: PlantPart = stems[_rng.randi() % stems.size()]
	var along := Vector2(stem.direction)
	var spread := _leaf_cap(stem) * 0.5
	var offset := along * _rng.randf_range(-0.5, 0.2) * stem.target_length + along.orthogonal() * _rng.randf_range(-spread, spread)
	_add_leaf(stem, offset)
	return true


## A new branch: straight on from a tip, or off to the side, whichever way is brightest
## and clear. It turns a corner and gets a leaf on its end straight away.
func _grow_stem() -> bool:
	var candidates: Array[PlantPart] = []
	for part in parts:
		var branches := part.count_children(PlantPart.Kind.STEM)
		if part.kind == PlantPart.Kind.STEM and branches < species.max_branches:
			candidates.append(part)
			if branches == 0: # Tips are likelier to extend.
				candidates.append(part)
	if candidates.is_empty():
		return false
	var parent: PlantPart = candidates[_rng.randi() % candidates.size()]
	var used := parent.child_directions(PlantPart.Kind.STEM)
	var length := _segment_length()

	var best := Vector2i.ZERO
	var best_score := -INF
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if direction == -parent.direction or used.has(direction):
			continue
		var tip := to_global(parent.end + Vector2(direction) * length)
		if flora.is_solid(tip) or flora.is_solid(to_global(parent.end + Vector2(direction) * length * 0.5)):
			continue
		var score := flora.light_at(tip) + (species.upward_bias if direction == Vector2i.UP else 0.0) + _rng.randf() * 0.15
		if score > best_score:
			best_score = score
			best = direction
	if best == Vector2i.ZERO or not _pay(species.stem_cost, true):
		return false
	var end := _add_segment(PlantPart.Kind.STEM, parent, best, length, 0)

	# Branches turn a corner, so nothing grows dead straight.
	if best != parent.direction or _rng.randf() < species.jog_chance:
		var turn := _turn_from(best)
		var turn_length := length * _rng.randf_range(0.4, 0.8)
		var corner := parent.end + Vector2(best) * length
		if not flora.is_solid(to_global(corner + Vector2(turn) * turn_length)) \
				and not flora.is_solid(to_global(corner + Vector2(turn) * turn_length * 0.5)):
			end = _add_segment(PlantPart.Kind.STEM, end, turn, turn_length, 0)
	_add_leaf(end, Vector2(end.direction) * 2.0) # Never a bare branch.
	return true


## A main leaf mass, on the stem in the upper crown carrying the most of the tree that
## doesn't already have one.
func _grow_core() -> bool:
	var height := _height()
	var upper := maxf(_crown_base(), height * 0.6) if height > species.segment_length * 2.0 else 0.0
	var best: PlantPart = null
	for part in parts:
		if part.kind != PlantPart.Kind.STEM or -part.end.y < upper:
			continue
		var has_core := part.children.any(func(child: PlantPart) -> bool: return child.core)
		if not has_core and (best == null or part.leaves_carried > best.leaves_carried):
			best = part
	if best == null or not _pay(species.leaf_cost * 2.0):
		return false
	var mass := PlantPart.new(PlantPart.Kind.LEAF, best)
	mass.core = true
	mass.depth = _leaf_depth()
	mass.size_cap = _core_size()
	mass.phase = _rng.randf() * TAU
	mass.variant = _rng.randi()
	_attach(mass)
	mass.light = flora.light_at(to_global(mass.end))
	return true


func _core_count() -> int:
	return parts.reduce(func(count: int, part: PlantPart) -> int: return count + (1 if part.core else 0), 0)


## Trees carry one main leaf mass, and another for every parts_per_core parts, up to three.
func _cores_wanted() -> int:
	return 0 if _creeping() else mini(1 + parts.size() / species.parts_per_core, 3)


## How big a main leaf mass grows: bigger the bigger the tree.
func _core_size() -> float:
	return lerpf(species.core_leaf_size, species.max_leaf_size, clampf(float(parts.size()) / species.max_parts, 0.0, 1.0))


## The way a branch turns its corner: up from a sideways branch, sideways from an
## upward one.
func _turn_from(direction: Vector2i) -> Vector2i:
	if direction != Vector2i.UP:
		return Vector2i.UP
	return Vector2i.LEFT if _rng.randf() < 0.5 else Vector2i.RIGHT


## A new root into soil, from a root tip or the base (or, for creepers, a runner), down
## or sideways.
func _grow_root() -> bool:
	var base := parts[0]
	var candidates: Array[PlantPart] = []
	if base.count_children(PlantPart.Kind.ROOT) < 3:
		candidates.append(base)
	for part in parts:
		if part.kind == PlantPart.Kind.ROOT and part.count_children(PlantPart.Kind.ROOT) < 2:
			candidates.append(part)
		elif _creeping() and part.kind == PlantPart.Kind.STEM and part.direction.y == 0 \
				and part.count_children(PlantPart.Kind.ROOT) == 0:
			candidates.append(part) # Runners root where they lie.
	if candidates.is_empty():
		return false
	var parent: PlantPart = candidates[_rng.randi() % candidates.size()]
	var origin := parent.start if parent.kind == PlantPart.Kind.STEM else parent.end
	var used := parent.child_directions(PlantPart.Kind.ROOT)
	var length := _segment_length()

	var options: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if direction == -parent.direction or used.has(direction):
			continue
		if flora.is_soil(to_global(origin + Vector2(direction) * length), species) \
				and flora.is_soil(to_global(origin + Vector2(direction) * length * 0.5), species):
			options.append(direction)
	if options.is_empty() or not _pay(species.root_cost):
		return false
	_add_segment(PlantPart.Kind.ROOT, parent, options[_rng.randi() % options.size()], length, 0)
	return true


## Creepers: blades on bare runner ends first, then spread if there's anywhere to go,
## else more blades, else (in good light, with nowhere left to spread) grow taller.
func _grow_creeper() -> bool:
	var bare := _bare_tips()
	if not bare.is_empty():
		return _grow_blade(bare[_rng.randi() % bare.size()])
	if _spread():
		return true
	var runners := parts.filter(func(part: PlantPart) -> bool:
		return part.kind == PlantPart.Kind.STEM and part.count_children(PlantPart.Kind.LEAF) < species.leaves_per_tip)
	if not runners.is_empty() and _rng.randf() < 0.7:
		return _grow_blade(runners[_rng.randi() % runners.size()])
	# Only a well-spread patch grows taller, so a young sprig never stands above the rest.
	if _tuft < species.max_tuft and parts.size() >= species.maturity * 2 and _average_light() >= species.tuft_light:
		_tuft = minf(_tuft + 0.25, species.max_tuft)
		for part in parts:
			if part.kind == PlantPart.Kind.LEAF:
				part.size_cap = _leaf_cap(part.parent)
		return true
	return false


func _grow_blade(runner: PlantPart) -> bool:
	if not _pay(species.leaf_cost):
		return false
	var back := -Vector2(runner.run) * _rng.randf_range(0.0, runner.length) if runner.direction.y == 0 else Vector2.ZERO
	_add_leaf(runner, back)
	return true


## Sends a runner on from one of the creeper's ends, following the ground: along it,
## up a step (within max_climb blocks of where it started) or down a ledge (within
## max_drop). Returns whether it grew.
func _spread() -> bool:
	var ends: Array[PlantPart] = []
	for part in parts:
		var limit := 2 if part == parts[0] else 1 # The first sprig spreads both ways.
		# Only from fully grown ends: where a growing one ends up isn't settled yet.
		if part.kind == PlantPart.Kind.STEM and part.count_children(PlantPart.Kind.STEM) < limit \
				and part.length >= part.target_length - 0.01:
			ends.append(part)
	ends.shuffle()
	for tip in ends:
		var run := tip.run
		if tip == parts[0]:
			var used := tip.child_directions(PlantPart.Kind.STEM)
			run = Vector2i.LEFT if _rng.randf() < 0.5 else Vector2i.RIGHT
			if used.has(run):
				run = -run
		var step := _runner_step(tip.end, run)
		if step.is_empty() or not _pay(species.stem_cost):
			continue
		var runner := _add_segment(PlantPart.Kind.STEM, tip, step[0], step[1], 0)
		runner.run = run
		# The inside corner gets a curve only where the climb or drop meets the ground.
		if step[0] == Vector2i.UP:
			runner.fillet = tip.direction.y == 0
		elif step[0] == Vector2i.DOWN:
			runner.fillet = _solid_at(tip.end + Vector2.DOWN * (step[1] + RUNNER_HEIGHT + 1.0))
		return true
	return false


## The next piece of runner from `from` heading `run`: [direction, length], or [] if
## it can't go on. Runners hug the ground RUNNER_HEIGHT above it, and climb or drop
## exactly as far as the wall or ledge goes (a block at a time at most).
func _runner_step(from: Vector2, run: Vector2i) -> Array:
	var ahead := Vector2(run)
	var below := Vector2(0.0, RUNNER_HEIGHT + 1.0)
	var block := float(BlockGrid.CELL_SIZE)
	if _solid_at(from + ahead * 2.0): # A step up: climb until clear of its top.
		for height in range(1, int(block) + 1):
			if -(from.y - height) > species.max_climb * block + RUNNER_HEIGHT or _solid_at(from + Vector2.UP * height):
				return []
			if not _solid_at(from + ahead * 2.0 + Vector2.UP * height):
				return [Vector2i.UP, float(height)]
		return [Vector2i.UP, block]
	if not _solid_at(from + ahead * 2.0 + below): # A ledge.
		if _solid_at(from + below): # Still standing on the edge: step out over it first.
			return [run, 1.0]
		for depth in range(1, int(block) + 1): # Down the face until just above the ground.
			if from.y + depth > species.max_drop * block:
				return []
			if _solid_at(from + Vector2.DOWN * (depth + RUNNER_HEIGHT)):
				return [Vector2i.DOWN, float(depth)]
		return [Vector2i.DOWN, block]
	# Along the ground: as far as it stays supported, or one pixel past an edge.
	var length := 0.0
	while length < species.segment_length:
		var next := from + ahead * (length + 1.0)
		if _solid_at(next):
			break
		length += 1.0
		if not _solid_at(next + below):
			break # Just over the edge, ready to drop down the face.
	if length < 1.0 or not _over_soil(from + ahead * length * 0.5):
		return []
	return [run, length]


## Whether there's ground under a runner pixel, or diagonally under it (so the pixel that
## steps out over an edge to climb down it still counts).
func _ground_under(local_point: Vector2) -> bool:
	var below := local_point + Vector2(0.0, RUNNER_HEIGHT + 1.0)
	return _solid_at(below) or _solid_at(below + Vector2.LEFT) or _solid_at(below + Vector2.RIGHT)


func _solid_at(local_point: Vector2) -> bool:
	return flora.is_solid(to_global(local_point))


func _over_soil(local_point: Vector2) -> bool:
	return flora.is_soil(to_global(local_point + Vector2(0.0, RUNNER_HEIGHT + 1.0)), species)


## Which leaf layer a new leaf goes in: behind or in front of the branches, at random.
## Grass blades all go in front.
func _leaf_depth() -> int:
	return 1 if _creeping() or _rng.randf() < 0.5 else -1


## How big a small leaf (or a creeper's blade) grows. Main leaf masses are sized by
## _core_size instead.
func _leaf_cap(_stem: PlantPart) -> float:
	return species.tip_leaf_size * (_tuft if _creeping() else 1.0)


## Height above the base below which a tree grows no leaves (no limit for creepers).
func _crown_base() -> float:
	if _creeping():
		return -INF
	var height := _height()
	return height * species.crown_start if height > species.segment_length * 2.0 else 0.0


## How tall the plant's stems reach, in pixels.
func _height() -> float:
	var height := 0.0
	for part in parts:
		if part.kind == PlantPart.Kind.STEM:
			height = maxf(height, -part.end.y)
	return height


func _segment_length() -> float:
	return species.segment_length * (1.0 + _rng.randf_range(-1.0, 1.0) * species.segment_length_variation)


## Where a leaf catches light: a square's center, partway up a blade, or the sunlit top
## of a main leaf mass.
func _leaf_middle(leaf: PlantPart) -> Vector2:
	if _creeping():
		return leaf.end + Vector2(0.0, -2.0)
	if leaf.core:
		return leaf.end + Vector2(0.0, -leaf.size_cap * 0.45)
	return leaf.end


func _average_light() -> float:
	var total := 0.0
	var count := 0
	for part in parts:
		if part.kind == PlantPart.Kind.LEAF:
			total += part.light
			count += 1
	return total / count if count > 0 else 0.0


func _try_seed(dt: float) -> void:
	if parts.size() < species.maturity or not _chance(dt / species.seed_interval):
		return
	if reserves.x < species.seed_cost.x * 2.0 or reserves.y < species.seed_cost.y * 2.0:
		return # Keep enough back to stay alive.
	var leaves := parts.filter(func(part: PlantPart) -> bool: return part.kind == PlantPart.Kind.LEAF)
	if leaves.is_empty():
		return
	reserves -= species.seed_cost
	var leaf: PlantPart = leaves[_rng.randi() % leaves.size()]
	var throw := Vector2(_rng.randf_range(-1.0, 1.0), -0.5) * species.seed_speed
	flora.drop_seed(species, to_global(_leaf_middle(leaf)), throw)

#endregion


## After the structure or lengths change: re-lays out parts, works out thickness (from
## the leaves carried and age) and how far trunks stretch, and rebuilds the hitbox and
## shade. The art is redrawn when the plant's next on screen.
func _rebuild() -> void:
	for part in parts:
		part.layout()
		part.leaves_carried = 1 if part.kind == PlantPart.Kind.LEAF else 0
		part.roots_carried = 1 if part.kind == PlantPart.Kind.ROOT else 0
	for i in range(parts.size() - 1, 0, -1):
		parts[i].parent.leaves_carried += parts[i].leaves_carried
		parts[i].parent.roots_carried += parts[i].roots_carried
	for part in parts:
		var aged := species.thickening * part.age
		match part.kind:
			PlantPart.Kind.LEAF: # Main leaf masses grow with the tree.
				part.size_cap = maxf(part.size_cap, _core_size() if part.core else _leaf_cap(part.parent))
			PlantPart.Kind.STEM:
				part.thickness = minf(species.min_thickness + species.thickness_per_leaf * sqrt(part.leaves_carried) + aged,
						species.max_thickness)
				if not _creeping() and part.target_length >= part.length:
					# The more it carries, the longer it grows, so trunks lift the crown
					# (unless something stopped it).
					var stretched := part.base_length * minf(1.0 + species.trunk_stretch * sqrt(part.leaves_carried), 2.5)
					part.target_length = maxf(part.target_length, stretched)
			PlantPart.Kind.ROOT:
				part.thickness = minf(species.root_thickness + 0.25 * sqrt(part.roots_carried) + aged * 0.5,
						species.max_thickness)

	# Drills find parts through the hitbox. Roots are underground, behind the blocks.
	for owner_id in _hitbox.get_shape_owners():
		_hitbox.remove_shape_owner(owner_id)
	for part in parts:
		if part.kind == PlantPart.Kind.ROOT:
			continue
		var rect := PlantRenderer.footprint(species, part)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(rect.size).max(Vector2.ONE * 2.0)
		var owner_id := _hitbox.create_shape_owner(part)
		_hitbox.shape_owner_add_shape(owner_id, shape)
		_hitbox.shape_owner_set_transform(owner_id, Transform2D(0.0, Vector2(rect.position) + Vector2(rect.size) * 0.5))

	clear_shade()
	if species.casts_shade: # Each leaf shades every cell its shape covers.
		for part in parts:
			if part.kind == PlantPart.Kind.LEAF:
				var rect := PlantRenderer.footprint(species, part)
				var first := Flora.shade_cell(to_global(Vector2(rect.position)))
				var last := Flora.shade_cell(to_global(Vector2(rect.end - Vector2i.ONE)))
				for y in range(first.y, last.y + 1):
					for x in range(first.x, last.x + 1):
						_shade_cells.append(Vector2i(x, y))
		flora.shade(_shade_cells, 1)
	_art_dirty = true
