extends Node
## Autoload "MachineClock": ticks every machine TICKS_PER_SECOND times a second.

signal ticked

const TICKS_PER_SECOND := 20

var tick_count := 0

var _accumulator := 0.0


func _physics_process(delta: float) -> void:
	var step := 1.0 / TICKS_PER_SECOND
	_accumulator += delta
	while _accumulator >= step - 0.0001: # Tolerance so 60 Hz physics lands on every 3rd frame.
		_accumulator -= step
		tick_count += 1
		ticked.emit()
