class_name StomachPart
extends BodyPart
## A stomach inside the body. Food eaten goes in (up to its capacity) and is slowly
## digested: most of it becomes the creature's energy, and the rest becomes dung, which
## builds up until there's a full load to drop as a block behind the creature.

## Food it holds when full (a full-grown blade of grass is 1).
@export var capacity := 8.0
## Food digested per second.
@export var digest_rate := 0.08
@export var energy_per_food := 1.0
## Share of digested food that becomes dung rather than energy.
@export_range(0.0, 1.0) var dung_share := 0.15
## Dung that makes a full load.
@export var load_size := 6.0

var food := 0.0
var dung := 0.0


func fits(candidate: BodyPart) -> bool:
	return candidate is TorsoPart # Organs sit inside a body.


func roll(rng: RandomNumberGenerator) -> void:
	super(rng)
	capacity = vary(capacity, rng)


func fullness() -> float:
	return food / capacity


## Takes in food, as much as fits. Returns how much it took.
func eat(amount: float) -> float:
	var taken := minf(amount, capacity - food)
	food += taken
	return taken


func update(delta: float) -> void:
	if creature.dead:
		return
	var digested := minf(food, digest_rate * delta)
	food -= digested
	creature.gain(digested * (1.0 - dung_share) * energy_per_food)
	dung += digested * dung_share
	if dung >= load_size and creature.drop_dung():
		dung -= load_size


func to_data() -> Dictionary:
	return {food = food, dung = dung}


func load_data(data: Dictionary) -> void:
	food = data.food
	dung = data.dung
