class_name Liquids
extends Node2D
## Water and blood, at the blocks' resolution. Each empty cell of the terrain can hold
## up to a cell's worth of liquid ("free" liquid), which falls, then spreads out level
## with its neighbours, so it pools into puddles and lakes and spills over edges.
##
## Blocks soak liquid up: a block can hold as much as its porosity, which comes from its
## density (light, loose blocks like dung hold plenty, dirt about half its volume, dense
## stone hardly any). Liquid on a block soaks in faster the emptier the block is, seeps on
## down (and a little sideways) into blocks that are drier, and drips out of the bottom of
## a block that's full with air below it. In the sun, water dries off open surfaces.
##
## Rain (from the Weather) falls on the top of every column. Plants' roots draw water
## from the blocks they're in, so without rain the ground slowly dries out.
##
## Amounts are a Vector2 per cell: x water, y blood (KINDS), each in cells of volume.

const KINDS: Array[StringName] = [&"water", &"blood"]
const COLORS: Array[Color] = [Color(0.25, 0.45, 0.85, 0.6), Color(0.5, 0.04, 0.06, 0.85)]
## How soaked blocks look: dark for water, red for blood, at their fullest.
const SOAK_COLORS: Array[Color] = [Color(0.02, 0.03, 0.1, 0.45), Color(0.35, 0.0, 0.02, 0.6)]
## Seconds between flow steps for free liquid, and between the slower steps where
## soaked liquid seeps, rain falls and things dry.
const STEP := 0.1
const SLOW_STEP := 1.0
## Cells checked for drying each slow step (a random handful stands for the rest).
const DRYING_SAMPLE := 300
## Less than this in a cell dries up.
const MIN_AMOUNT := 0.004
## Water falling on each column per second at full rain, in cells.
const RAIN_RATE := 0.01
## Share of a block's room that liquid on it fills per second.
const SOAK_RATE := 0.6
## Share of the difference in fullness that seeps from a block into a drier one per
## second (down; a third of that sideways).
const SEEP_RATE := 0.15
## A block this full drips into the air under it.
const DRIP_FILL := 0.95
## Water lost per second in full sun: from the top of open water, and from an open
## soaked surface.
const EVAPORATE := 0.002
const DRY := 0.0008
## Cells of liquid in one item of it (a spilled unit of blood).
const UNIT := 0.05
## How deep (in blocks) the ground starts damp, and how damp.
const DAMP_DEPTH := 6
const DAMP := 0.5
## Most blocks deep a lake fills to when the world is made, fewest and most blocks wide,
## and how far either side it looks for its banks.
const LAKE_DEPTH := 4
const LAKE_WIDTH := 3
const LAKE_MAX_WIDTH := 24
const LAKE_REACH := 12

var world: BlockWorld
## Free liquid in empty cells.
var free: Dictionary[Vector2i, Vector2] = {}
## Liquid soaked into terrain blocks.
var soaked: Dictionary[Vector2i, Vector2] = {}

# Cells that might move this step: free liquid, and (slower) soaked blocks.
var _flowing: Dictionary[Vector2i, bool] = {}
var _seeping: Dictionary[Vector2i, bool] = {}
var _wait := STEP
var _slow_wait := SLOW_STEP
var _tops: Dictionary[int, int] = {}
var _rng := RandomNumberGenerator.new()


## How much liquid a block can hold, from its density, in cells.
static func porosity(type: BlockType) -> float:
	return clampf(1.0 - type.density / 2.8, 0.03, 0.9)


static func total(amount: Vector2) -> float:
	return amount.x + amount.y


func _ready() -> void:
	z_index = 0 # Over the blocks it soaks (it's added after them), in front of the player.
	material = SunShade.lit_material()
	transform = world.terrain.transform
	world.terrain.changed.connect(_on_terrain_changed)


func _physics_process(delta: float) -> void:
	_wait -= delta
	while _wait <= 0.0:
		_wait += STEP
		_flow_step()
	_slow_wait -= delta
	while _slow_wait <= 0.0:
		_slow_wait += SLOW_STEP
		var sun := _sun()
		_rain()
		_seep_step(sun)
		_dry(sun)


func _process(_delta: float) -> void:
	queue_redraw()


#region Queries and changes

func kind_index(kind: StringName) -> int:
	return KINDS.find(kind)


func cell_at(global_point: Vector2) -> Vector2i:
	return world.terrain.global_to_cell(global_point)


## Free liquid in the cell at a global point.
func amount_at(global_point: Vector2) -> Vector2:
	return free.get(cell_at(global_point), Vector2.ZERO)


## Whether a global point is under water (or blood).
func is_wet(global_point: Vector2, depth := 0.3) -> bool:
	return total(amount_at(global_point)) >= depth


## How much liquid a block holds, in cells, or 0 for empty cells.
func capacity(cell: Vector2i) -> float:
	var block := world.terrain.get_block(cell)
	return porosity(Blocks.get_type(block)) if block != Blocks.AIR else 0.0


## Adds liquid to a cell: soaked into its block if there is one, free otherwise. What
## doesn't fit goes to the cell above.
func add(cell: Vector2i, kind: int, amount: float) -> void:
	var guard := 0
	while amount > 0.00001 and guard < 64:
		guard += 1
		var table := soaked if _solid(cell) else free
		var room := (capacity(cell) if _solid(cell) else 1.0) - total(table.get(cell, Vector2.ZERO))
		var put := clampf(room, 0.0, amount)
		if put > 0.0:
			var held: Vector2 = table.get(cell, Vector2.ZERO)
			held[kind] += put
			table[cell] = held
			_wake(cell)
		amount -= put
		cell += Vector2i.UP


## Adds liquid at a global point: `amount` in items (see UNIT).
func spill(global_point: Vector2, kind: StringName, items: float) -> void:
	var index := kind_index(kind)
	if index >= 0:
		add(cell_at(global_point), index, items * UNIT)


## Takes up to `amount` of a liquid from a cell (its block's soak, or free liquid).
## Returns how much it got.
func take(cell: Vector2i, kind: int, amount: float) -> float:
	var table := soaked if _solid(cell) else free
	if not table.has(cell):
		return 0.0
	var held: Vector2 = table[cell]
	var taken := clampf(held[kind], 0.0, amount)
	held[kind] -= taken
	if total(held) < MIN_AMOUNT:
		table.erase(cell)
	else:
		table[cell] = held
	_wake(cell)
	return taken


## The nearest cell of free liquid of a kind within `reach` cells of a global point, or
## Vector2i.MAX if there's none.
func nearest(global_point: Vector2, kind: int, reach: int, at_least := 0.3) -> Vector2i:
	var center := cell_at(global_point)
	var best := Vector2i.MAX
	var best_distance := INF
	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			var cell := Vector2i(x, y)
			if free.has(cell) and free[cell][kind] >= at_least:
				var distance := Vector2(cell - center).length_squared()
				if distance < best_distance:
					best_distance = distance
					best = cell
	return best


## A cell's middle, global.
func cell_center(cell: Vector2i) -> Vector2:
	return world.terrain.to_global(BlockGrid.cell_center(cell))

#endregion


#region Making the world

## Dampens the top of the ground and fills hollows in it with lakes.
func generate() -> void:
	var tops: Array[int] = []
	for x in world.width:
		tops.append(_top(x))
		for y in range(tops[x], mini(tops[x] + DAMP_DEPTH, world.height)):
			var cell := Vector2i(x, y)
			if _solid(cell):
				soaked[cell] = Vector2(capacity(cell) * DAMP, 0.0)
	# Water rests in hollows: wherever the ground rises higher on both sides within a
	# short way (rows count down, so "higher" is a smaller row).
	var x := 0
	while x < world.width:
		var level := _hollow_level(tops, x)
		if level >= tops[x]:
			x += 1
			continue
		var run_end := x
		while run_end < world.width and _hollow_level(tops, run_end) == level and level < tops[run_end]:
			run_end += 1
		if run_end - x >= LAKE_WIDTH and run_end - x <= LAKE_MAX_WIDTH:
			for column in range(x, run_end):
				var surface := maxi(level, tops[column] - LAKE_DEPTH)
				for y in range(surface, tops[column]):
					free[Vector2i(column, y)] = Vector2(1.0, 0.0)
				# The lake bed (and its banks) are already soaked through, so it holds.
				for bank in range(column - 1, column + 2):
					for y in range(tops[column], mini(tops[column] + DAMP_DEPTH * 2, world.height)):
						var cell := Vector2i(bank, y)
						if _solid(cell):
							soaked[cell] = Vector2(capacity(cell), 0.0)
		x = maxi(run_end, x + 1)


## The row water would rest at over a column: the lower of the highest ground within
## LAKE_REACH on either side.
func _hollow_level(tops: Array[int], x: int) -> int:
	var left := tops[x]
	for i in range(maxi(x - LAKE_REACH, 0), x):
		left = mini(left, tops[i])
	var right := tops[x]
	for i in range(x + 1, mini(x + LAKE_REACH + 1, tops.size())):
		right = mini(right, tops[i])
	return maxi(left, right)

#endregion


#region Flow

## How strongly things dry: the sun's height, unless it's raining. 0-1.
func _sun() -> float:
	var weather := get_tree().get_first_node_in_group(Weather.GROUP) as Weather
	var sky := get_tree().get_first_node_in_group(SkyLayer.GROUP) as SkyLayer
	return (sky.daylight() if sky else 1.0) * (weather.dryness() if weather else 1.0)


func _rain() -> void:
	var weather := get_tree().get_first_node_in_group(Weather.GROUP) as Weather
	if weather == null or weather.rain <= 0.0:
		return
	var amount := RAIN_RATE * weather.rain * SLOW_STEP
	for x in world.width:
		add(Vector2i(x, _top(x) - 1), 0, amount)


func _flow_step() -> void:
	var cells := _flowing.keys()
	_flowing.clear()
	cells.shuffle()
	for cell: Vector2i in cells:
		if not free.has(cell):
			continue
		if _solid(cell): # A block went in on it: the liquid's pushed into it and up.
			var pushed: Vector2 = free[cell]
			free.erase(cell)
			for kind in KINDS.size():
				add(cell, kind, pushed[kind])
		else:
			_flow(cell)


func _seep_step(_sun_strength: float) -> void:
	var cells := _seeping.keys()
	_seeping.clear()
	for cell: Vector2i in cells:
		if not soaked.has(cell):
			continue
		if not _solid(cell): # Its block has gone: what it held spills out.
			var spilled: Vector2 = soaked[cell]
			soaked.erase(cell)
			for kind in KINDS.size():
				add(cell, kind, spilled[kind])
		else:
			_seep(cell)


## Water dries off open surfaces in the sun: a random handful of cells each step, each
## losing as much as all of them would.
func _dry(sun: float) -> void:
	if sun <= 0.0:
		return
	for table: Dictionary in [free, soaked]:
		var cells := table.keys()
		if cells.is_empty():
			continue
		var scale := maxf(float(cells.size()) / DRYING_SAMPLE, 1.0)
		for i in mini(DRYING_SAMPLE, cells.size()):
			var cell: Vector2i = cells[_rng.randi() % cells.size()]
			if not table.has(cell) or free.has(cell + Vector2i.UP) or _solid(cell + Vector2i.UP):
				continue
			var rate := EVAPORATE if table == free else DRY
			_lose(table, cell, rate * sun * SLOW_STEP * scale)


## Free liquid falls, soaks into what it rests on, and levels out with its neighbours.
func _flow(cell: Vector2i) -> void:
	var below := cell + Vector2i.DOWN
	if not _solid(below):
		var room := 1.0 - total(free.get(below, Vector2.ZERO))
		if room > 0.0:
			_move(free, cell, free, below, room)
	else:
		var room := capacity(below) - total(soaked.get(below, Vector2.ZERO))
		if room > 0.001:
			_move(free, cell, soaked, below, room * SOAK_RATE * STEP + 0.002)
	if not free.has(cell):
		return
	var sides: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
	if _rng.randf() < 0.5:
		sides.reverse()
	for side in sides:
		var next := cell + side
		if not free.has(cell):
			return
		if _solid(next): # Soaks a little into a wall beside it.
			var room := capacity(next) - total(soaked.get(next, Vector2.ZERO))
			if room > 0.01:
				_move(free, cell, soaked, next, room * SOAK_RATE * STEP * 0.3)
			continue
		var difference := total(free[cell]) - total(free.get(next, Vector2.ZERO))
		if difference > 0.02:
			_move(free, cell, free, next, difference / 3.0)


## Soaked liquid seeps into drier blocks below and beside, and drips out of a full
## block's underside.
func _seep(cell: Vector2i) -> void:
	var fill := total(soaked[cell]) / capacity(cell)
	var below := cell + Vector2i.DOWN
	if _solid(below):
		var below_fill := total(soaked.get(below, Vector2.ZERO)) / capacity(below)
		if fill > below_fill + 0.03:
			_move(soaked, cell, soaked, below, (fill - below_fill) * capacity(below) * SEEP_RATE * SLOW_STEP)
	elif fill > DRIP_FILL:
		_move(soaked, cell, free, below, (fill - DRIP_FILL) * capacity(cell) + 0.001)
	for side in [Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = cell + side
		if soaked.has(cell) and _solid(next):
			var next_fill := total(soaked.get(next, Vector2.ZERO)) / capacity(next)
			fill = total(soaked[cell]) / capacity(cell)
			if fill > next_fill + 0.05:
				_move(soaked, cell, soaked, next, (fill - next_fill) * capacity(next) * SEEP_RATE * SLOW_STEP / 3.0)


## Moves up to `amount` of the liquid in one cell to another, keeping its mix of kinds.
func _move(from_table: Dictionary, from: Vector2i, to_table: Dictionary, to: Vector2i, amount: float) -> void:
	var held: Vector2 = from_table[from]
	var share := clampf(amount / maxf(total(held), 0.000001), 0.0, 1.0)
	if share <= 0.0:
		return
	var moved := held * share
	var rest := held - moved
	if total(rest) < MIN_AMOUNT:
		moved = held
		from_table.erase(from)
	else:
		from_table[from] = rest
	to_table[to] = to_table.get(to, Vector2.ZERO) + moved
	_wake(from)
	_wake(to)


## Water drying away (blood doesn't).
func _lose(table: Dictionary, cell: Vector2i, amount: float) -> void:
	var held: Vector2 = table[cell]
	held.x = maxf(held.x - amount, 0.0)
	if total(held) < MIN_AMOUNT:
		table.erase(cell)
	else:
		table[cell] = held
	_wake(cell)


## Marks a cell and its neighbours that hold liquid to be looked at next step.
func _wake(cell: Vector2i) -> void:
	for next in [cell, cell + Vector2i.UP, cell + Vector2i.DOWN, cell + Vector2i.LEFT, cell + Vector2i.RIGHT]:
		if free.has(next):
			_flowing[next] = true
		if soaked.has(next):
			_seeping[next] = true


func _solid(cell: Vector2i) -> bool:
	return world.terrain.has_block(cell)


## The row of the highest block in a column.
func _top(x: int) -> int:
	if not _tops.has(x):
		var y := 0
		while y < world.height and not _solid(Vector2i(x, y)):
			y += 1
		_tops[x] = y
	return _tops[x]


func _on_terrain_changed() -> void:
	_tops.clear()
	for cell in free: # Anything might have lost its floor or gained a block.
		_flowing[cell] = true
	for cell in soaked:
		if not _solid(cell) or not _solid(cell + Vector2i.DOWN):
			_seeping[cell] = true

#endregion


#region Drawing and saving

func _draw() -> void:
	var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	var local := get_global_transform().affine_inverse() * view
	var first := Vector2i((local.position / BlockGrid.CELL_SIZE).floor()) - Vector2i.ONE
	var last := Vector2i((local.end / BlockGrid.CELL_SIZE).ceil()) + Vector2i.ONE
	var size := float(BlockGrid.CELL_SIZE)
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var cell := Vector2i(x, y)
			if soaked.has(cell):
				var held: Vector2 = soaked[cell]
				var tint := SOAK_COLORS[0].lerp(SOAK_COLORS[1], held.y / total(held))
				tint.a *= clampf(total(held) / capacity(cell), 0.0, 1.0) if capacity(cell) > 0.0 else 0.0
				draw_rect(Rect2(Vector2(cell) * size, Vector2.ONE * size), tint)
			if free.has(cell):
				var held: Vector2 = free[cell]
				var color := COLORS[0].lerp(COLORS[1], held.y / total(held))
				var full := free.has(cell + Vector2i.UP) or _solid(cell + Vector2i.UP)
				var height := size if full else clampf(ceilf(total(held) * size), 1.0, size)
				var top := (y + 1) * size - height
				draw_rect(Rect2(x * size, top, size, height), color)
				if not full: # A lighter line along the surface.
					draw_rect(Rect2(x * size, top, size, 1.0), color.lightened(0.3))


func to_data() -> Dictionary:
	return {free = _pack(free), soaked = _pack(soaked)}


func load_data(data: Dictionary) -> void:
	free = _unpack(data.free)
	soaked = _unpack(data.soaked)
	for cell in free:
		_flowing[cell] = true


static func _pack(table: Dictionary[Vector2i, Vector2]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for cell in table:
		packed.append_array([cell.x, cell.y, table[cell].x, table[cell].y])
	return packed


static func _unpack(packed: PackedFloat32Array) -> Dictionary[Vector2i, Vector2]:
	var table: Dictionary[Vector2i, Vector2] = {}
	for i in range(0, packed.size(), 4):
		table[Vector2i(int(packed[i]), int(packed[i + 1]))] = Vector2(packed[i + 2], packed[i + 3])
	return table

#endregion
