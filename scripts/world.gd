extends Node3D

# --- [ ССЫЛКИ НА УЗЛЫ ] ---
@onready var hp_bar_master = $CanvasLayer/Control/HPBarMaster
@onready var label1 = $CanvasLayer/Control/Label
@onready var label2 = $CanvasLayer/Control/Label2
@onready var label3 = $CanvasLayer/Control/Label3
@onready var label4: Label = $CanvasLayer/Control/Label4
@onready var gate_sound: AudioStreamPlayer3D = $"NavigationRegion3D/OBJECTS/door arc_038/GateSound"

# --- [ КОНСТАНТЫ ] ---
const CHARACTER_SCENES = {
	"Warrior": "res://scenes/Characters/Warrior.tscn",
	"Archer": "res://scenes/Characters/Archer.tscn",
	"Mage": "res://scenes/Characters/Mage.tscn"
}

# --- [ ОСНОВНЫЕ ФУНКЦИИ ] ---

func _ready():
	# Останавливаем музыку меню
	if GlobalMusic.has_node("AudioStreamPlayer"):
		GlobalMusic.get_node("AudioStreamPlayer").stop()
	
	# Скрываем все элементы UI при старте
	if hp_bar_master: hp_bar_master.hide()
	if label1: label1.hide()
	if label2: label2.hide()
	if label3: label3.hide()
	if label4: label4.hide()

	if not multiplayer.is_server(): return
	
	# Подключаем спавн игроков
	multiplayer.peer_connected.connect(_spawn)
	for id in Global.players:
		_spawn(id)
	
	# ПРИМЕЧАНИЕ: Таймер открытия ворот отсюда УДАЛЕН. 
	# Теперь ворота открывает Мастер, когда дойдет до рычага.

@rpc("call_local", "reliable")
func _open_gate():
	gate_sound.pitch_scale = 3
	gate_sound.play()
	# 1. Анимация ворот (поднимаем решетку)
	var gate: Node3D = get_node_or_null("NavigationRegion3D/OBJECTS/door arc_038/bars_001")
	if gate:
		var tween = create_tween()
		tween.tween_property(gate, "position:z", gate.position.z + 2.75, 3.0)
	
	# 2. Показываем первую реплику Мастера
	_sync_ui_element("label1", true)
	
	# 3. Запускаем озвучку/текст Мастера (включает анимацию talk1)
	var master_node = get_node_or_null("Master")
	if master_node and master_node.has_method("start_opening_speech"):
		master_node.start_opening_speech.rpc()
	
	# 4. Через 5 секунд убираем приветствие и даем задание найти меч
	get_tree().create_timer(5.0).timeout.connect(func():
		_sync_ui_element("label1", false)
		_sync_ui_element("label2", true)
		# --- НОВОЕ: Таймер для исчезновения Label2 ---
		get_tree().create_timer(5.0).timeout.connect(func():
			_sync_ui_element.rpc("label2", false)
			)
	)

# --- [ СЕТЕВАЯ ЛОГИКА (RPC) ] ---

# Универсальная функция для управления видимостью UI на всех клиентах
@rpc("any_peer", "call_local", "reliable")
func _sync_ui_element(element_name: String, should_show: bool):
	match element_name:
		"label1": if label1: label1.visible = should_show
		"label2": if label2: label2.visible = should_show
		"label3": if label3: label3.visible = should_show
		"label4": if label4: label4.visible = should_show

func _spawn(id):
	if has_node(str(id)): return
	var p_data = Global.players.get(id, {})
	var p_class = p_data.get("class", "Warrior")
	var scene_path = CHARACTER_SCENES.get(p_class, CHARACTER_SCENES["Warrior"])

	if not FileAccess.file_exists(scene_path): return

	var p = load(scene_path).instantiate()
	p.name = str(id)
	p.add_to_group("Player") 
	
	# Определяем точку спавна
	var spawn_node = get_node_or_null("Player") if id == 1 else get_node_or_null("Player2")
	var target_pos = spawn_node.position if spawn_node else Vector3(0, 5, 0)
	
	p.position = target_pos
	add_child(p, true)
	
	# Принудительная телепортация для синхронизации позиции на клиентах
	if id != 1:
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(p):
			p.force_teleport.rpc_id(id, target_pos)

# --- [ ВЗАИМОДЕЙСТВИЕ С ИГРОКОМ ] ---

@rpc("any_peer", "call_local", "reliable")
func swap_to_battle_labels():
	# Прячем подсказку "Возьми меч" и показываем "Нападай!"
	_sync_ui_element("label2", false)
	_sync_ui_element("label3", true)
	
	# Label3 исчезнет сама через 5 секунд
	get_tree().create_timer(5.0).timeout.connect(func():
		_sync_ui_element("label3", false)
	)
