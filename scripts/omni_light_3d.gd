extends OmniLight3D

var base_energy = 4
var flicker_timer := 0.0



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	flicker_timer -= delta
	if flicker_timer <= 0.0:
		light_energy = base_energy + randf_range(-0.5, 0.5)
		flicker_timer = 0.05
