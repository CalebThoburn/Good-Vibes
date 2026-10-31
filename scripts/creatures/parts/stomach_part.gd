class_name StomachPart
extends TorsoPart
## The belly: a segment of the body that holds what the creature eats (food_item) and
## digests it into blood as the body has room for it. Some of what it digests becomes
## dung instead, which builds up until there's a full load to drop as a block behind
## the creature. Digesting uses up bile, which only sleep makes, so a creature has to
## sleep now and then to keep turning food into blood. A wound here leaks food, dung and
## bile along with blood.

## What it eats, as an item id (grass for sheep, water for fireflies).
@export var food_item: StringName = &"grass"
## Food it holds when full (a full-grown blade of grass is 1).
@export var capacity := 8.0
## Food digested per second, at most.
@export var digest_rate := 0.08
## Blood made from each unit of food.
@export var blood_per_food := 0.85
## Blocks of dung made from each unit of food (a full load is 1).
@export var dung_per_food := 0.025
## Bile it holds when full (sleep fills it), and bile used per unit of food digested.
@export var bile_capacity := 10.0
@export var bile_per_food := 1.0


func roll(rng: RandomNumberGenerator) -> void:
	super(rng)
	capacity = vary(capacity, rng)


func food() -> float:
	return contents.get(food_item, 0.0)


func setup() -> void:
	super()
	contents[&"bile"] = bile_capacity * 0.8


func bile() -> float:
	return contents.get(&"bile", 0.0)


func fullness() -> float:
	return food() / capacity


## Takes in food, as much as fits. Returns how much it took.
func eat(amount: float) -> float:
	var taken := clampf(capacity - food(), 0.0, amount)
	contents[food_item] = food() + taken
	return taken


func update(delta: float) -> void:
	super(delta)
	if creature.dead:
		return
	var room := creature.max_blood() - creature.blood()
	var digested := minf(minf(food(), digest_rate * delta), room / blood_per_food)
	digested = minf(digested, bile() / bile_per_food)
	if digested <= 0.0:
		return
	contents[food_item] = food() - digested
	contents[&"bile"] = bile() - digested * bile_per_food
	contents[&"blood"] = blood() + digested * blood_per_food # The creature spreads it round.
	if dung_per_food > 0.0:
		contents[&"dung"] = contents.get(&"dung", 0.0) + digested * dung_per_food
		if contents[&"dung"] >= 1.0 and creature.drop_dung():
			contents[&"dung"] -= 1.0
