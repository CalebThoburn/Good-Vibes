class_name OutcomeModel
extends RefCounted
## What a creature has learned about what its actions lead to. For each action on each
## kind of target ("bite|plant:grass", "sleep|"), it keeps the change it expects in its
## needs (OUTCOMES: food, energy, health, rest), learned from every time it's tried it.
## That expectation is a base amount plus an adjustment for each circumstance it noticed
## at the time (what was around, what it did last, what it heard), so it can learn that
## something only goes well when, say, a certain block is near. Each try nudges the base
## and the adjustments for what was present toward what actually happened.

## The needs an outcome measures, in order.
enum { FOOD, ENERGY, HEALTH, REST }
const SIZE := 4
## How far each try moves the expectation toward what happened (the first try sets it).
const RATE := 0.3

# key -> {n: int, bias: PackedFloat32Array, weights: {feature: PackedFloat32Array},
# counts: {feature: int}}
var _entries := {}


## The change it expects from doing `key` with these circumstances. Untried, it goes by
## its species' instincts (`hunch`), if any.
func predict(key: String, features: Array[StringName], hunch := PackedFloat32Array()) -> PackedFloat32Array:
	var entry: Dictionary = _entries.get(key, {})
	if entry.is_empty():
		return hunch.duplicate() if hunch.size() == SIZE else _zero()
	var expected: PackedFloat32Array = entry.bias.duplicate()
	for feature in features:
		if entry.weights.has(feature):
			_add(expected, entry.weights[feature], 1.0)
	return expected


## Learns from one try: `outcome` is what changed while doing `key` among `features`.
func learn(key: String, features: Array[StringName], outcome: PackedFloat32Array, hunch := PackedFloat32Array()) -> void:
	if not _entries.has(key):
		_entries[key] = {n = 0, bias = hunch.duplicate() if hunch.size() == SIZE else _zero(), weights = {}, counts = {}}
	var entry: Dictionary = _entries[key]
	var error := outcome.duplicate()
	_add(error, predict(key, features, hunch), -1.0)
	var rate := maxf(RATE, 1.0 / (entry.n + 1))
	# Half goes to the base, half shared among the circumstances present, so each try
	# moves the expectation by `rate` of the miss however many there were.
	_add(entry.bias, error, rate * (0.5 if not features.is_empty() else 1.0))
	for feature in features:
		if not entry.weights.has(feature):
			entry.weights[feature] = _zero()
		_add(entry.weights[feature], error, rate * 0.5 / features.size())
		entry.counts[feature] = entry.counts.get(feature, 0) + 1
	entry.n += 1


## How little it knows about doing `key` in these circumstances: 1.25 for never tried,
## falling toward 0 as it tries it more, and higher for circumstances it's rarely seen.
func novelty(key: String, features: Array[StringName]) -> float:
	var entry: Dictionary = _entries.get(key, {})
	if entry.is_empty():
		return 1.25
	var unfamiliar := 0.0
	for feature in features:
		unfamiliar += 1.0 / sqrt(1.0 + entry.counts.get(feature, 0))
	return 1.0 / sqrt(1.0 + entry.n) + 0.25 * unfamiliar / maxf(features.size(), 1.0)


## How much harm it's learned to expect when something is around, from what it's done
## with that thing near: 0 for none, higher for worse.
func danger(feature: StringName) -> float:
	var total := 0.0
	var seen := 0
	for entry: Dictionary in _entries.values():
		if entry.weights.has(feature):
			total += entry.weights[feature][HEALTH]
			seen += 1
	return maxf(-total / seen, 0.0) if seen > 0 else 0.0


## How many times it's done `key`.
func tries(key: String) -> int:
	return _entries.get(key, {}).get("n", 0)


func to_data() -> Dictionary:
	return _entries.duplicate(true)


func load_data(data: Dictionary) -> void:
	_entries = data.duplicate(true)


static func _zero() -> PackedFloat32Array:
	var zero := PackedFloat32Array()
	zero.resize(SIZE)
	return zero


static func _add(to: PackedFloat32Array, amount: PackedFloat32Array, scale: float) -> void:
	for i in SIZE:
		to[i] += amount[i] * scale
