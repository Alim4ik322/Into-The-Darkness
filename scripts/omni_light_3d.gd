extends OmniLight3D

var base_energy: float = 2.0
var target_energy: float = 2.0
var flicker_timer: float = 0.0

# Настрой эти переменные под себя:
var flicker_speed: float = 0.15  # Как часто выбирается новая цель (чем больше, тем реже)
var smoothing: float = 5.0      # Плавность перехода (чем меньше, тем медленнее)

func _process(delta: float) -> void:
	flicker_timer -= delta
	
	# 1. Выбираем новую "цель" для яркости по таймеру
	if flicker_timer <= 0.0:
		target_energy = base_energy + randf_range(-0.5, 0.5)
		flicker_timer = flicker_speed
	
	# 2. ПЛАВНО двигаем текущую яркость к целевой
	# lerp(откуда, куда, скорость * время)
	light_energy = lerp(light_energy, target_energy, smoothing * delta)
