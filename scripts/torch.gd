extends OmniLight3D

var time = 0.0

@export_group("Settings")
@export var base_energy: float = 2 
@export var flicker_speed: float = 3
@export var flicker_strength: float = 0.3

@export_group("Colors")
@export var normal_color: Color = Color("f8bfa6") 
# Заменили Color.RED на более мягкий оттенок красного
@export var battle_color: Color = Color("e35a5a") 

@export var master_path: NodePath = "/root/World/Master" 

var boss_node = null

func _ready() -> void:
	light_color = normal_color
	boss_node = get_node_or_null(master_path)

func _process(delta: float) -> void:
	# 1. Логика мерцания
	time += delta * flicker_speed
	var noise = sin(time) * cos(time * 0.7) 
	light_energy = base_energy + (noise * flicker_strength)
	
	# 2. Логика смены цвета
	if boss_node and is_instance_valid(boss_node):
		if boss_node.get("is_battle_started") == true:
			# Замедлил скорость перехода (delta * 1.0), чтобы смена была еще мягче
			light_color = light_color.lerp(battle_color, delta * 1.0)
		else:
			# Возврат к нормальному цвету тоже сделаем плавным, чтобы не дергалось
			light_color = light_color.lerp(normal_color, delta * 1.0)
