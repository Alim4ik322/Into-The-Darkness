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
var check_timer = 0.0

func _ready() -> void:
	light_color = normal_color
	boss_node = get_node_or_null(master_path)

func _process(delta: float) -> void:
	# 1. Логика мерцания (каждый кадр для плавности)
	time += delta * flicker_speed
	var noise = sin(time) * cos(time * 0.7) 
	light_energy = base_energy + (noise * flicker_strength)
	
	# 2. Логика смены цвета (реже, чем каждый кадр)
	check_timer -= delta
	if check_timer <= 0:
		_update_battle_status()
		check_timer = 0.5 # Проверяем раз в полсекунды
	
	# Плавный переход цвета (каждый кадр для красоты)
	var target_color = battle_color if is_in_battle else normal_color
	if light_color != target_color:
		light_color = light_color.lerp(target_color, delta * 1.0)

var is_in_battle = false
func _update_battle_status():
	if boss_node and is_instance_valid(boss_node):
		is_in_battle = boss_node.get("is_battle_started") == true
	else:
		is_in_battle = false
