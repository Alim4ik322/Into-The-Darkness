extends Node3D

# Словарь путей к сценам персонажей для удобства
const CHARACTER_SCENES = {
	"Warrior": "res://scenes/Characters/Warrior.tscn",
	"Archer": "res://scenes/Characters/Archer.tscn",
	"Mage": "res://scenes/Characters/Mage.tscn"
}

func _ready():
	if not multiplayer.is_server(): return
	
	# Коннектим новых игроков, которые зайдут ПОСЛЕ старта
	multiplayer.peer_connected.connect(_spawn)
	
	# Спавним тех, кто УЖЕ в лобби (включая хоста с ID 1)
	for id in Global.players:
		_spawn(id)
		
	get_tree().create_timer(5.0).timeout.connect(_open_gate)


func _open_gate():
	var gate: Node3D = $"OBJECTS/door arc_038/bars_001"
	
	if gate:
		# Создаем плавную анимацию через Tween
		var tween = create_tween()
		# Поднимаем на 5 метров вверх за 2 секунды
		tween.tween_property(gate, "position:z", gate.position.z + 2.75, 3.0)

func _spawn(id):
	if has_node(str(id)): return
	
	# Получаем данные игрока и его класс
	var p_data = Global.players.get(id, {})
	var p_class = p_data.get("class", "Warrior")
	
	# Выбираем путь к сцене из словаря. Если класса нет в списке, берем Воина по дефолту.
	var scene_path = CHARACTER_SCENES.get(p_class, CHARACTER_SCENES["Warrior"])
	
	# Проверка на существование файла перед загрузкой (чтобы не вылетело, если забыл создать файл)
	if not FileAccess.file_exists(scene_path):
		print("[ERROR] Scene file not found: ", scene_path)
		return

	var p = load(scene_path).instantiate()
	p.name = str(id)
	
	# 1. Находим точку спавна по маркерам в сцене
	var spawn_node = get_node_or_null("Player") if id == 1 else get_node_or_null("Player2")
	var target_pos = Vector3(0, 5, 0) # Запасная позиция, если маркеры не найдены
	
	if spawn_node:
		# Используем position, так как при добавлении в дерево он станет глобальным
		target_pos = spawn_node.position 

	# 2. Устанавливаем позицию ДО добавления в дерево
	p.position = target_pos
	
	# 3. Добавляем игрока в мир
	add_child(p, true)
	
	# 4. Принудительная синхронизация позиции для клиента (RPC)
	# Хосту (ID 1) это не нужно, так как он и есть сервер
	if id != 1:
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(p):
			p.force_teleport.rpc_id(id, target_pos)
			print("[DEBUG] Teleport RPC sent to player ", id, " to position ", target_pos)
