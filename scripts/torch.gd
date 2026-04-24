extends OmniLight3D

var time = 0.0
# Эти переменные появятся в самом верху инспектора в разделе Torch.gd
@export var base_energy: float = 2.5 
@export var flicker_speed: float = 4.0
@export var flicker_strength: float = 0.4

func _process(delta: float) -> void:
	time += delta * flicker_speed
	var noise = sin(time) * cos(time * 0.7) 
	# Прямо назначаем яркость
	light_energy = base_energy + (noise * flicker_strength)
