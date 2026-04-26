extends Area3D

const SPEED = 25.0
var shooter = null 

@export var damage: int = 100

func _ready():
	$AudioStreamPlayer3D.play()
	# Убираем ручной set_multiplayer_authority от shooter.
	# Сервер сам поставит себе права при спавне.
	
	get_tree().create_timer(5.0).timeout.connect(_safe_destroy_rpc_wrapper)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Только сервер (ID 1) двигает стрелу. 
	# Все остальные увидят полет через MultiplayerSynchronizer.
	if multiplayer.is_server():
		global_position += -global_transform.basis.z * SPEED * delta

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	# Не бьем того, кто выстрелил
	if body == shooter:
		return
	
	# Создаем переменную для хранения того, кого реально будем бить
	var target_to_damage = body
	
	# ПРОВЕРКА: Если попали в StaticBody3D (твой хитбокс на кости)
	# Мы идем вверх по дереву узлов, пока не найдем CharacterBody3D (Мастера)
	if body is StaticBody3D:
		var parent = body.get_parent()
		while parent != null and not parent is CharacterBody3D:
			parent = parent.get_parent()
		
		if parent is CharacterBody3D:
			target_to_damage = parent

	# Наносим урон конечному родителю (Мастеру)
	if target_to_damage.has_method("take_damage"):
		target_to_damage.take_damage(damage)
		# Сразу удаляем стрелу после урона
		_safe_destroy.rpc()
		return

	# Если попали во что-то другое (пол, стены) — просто удаляем стрелу
	_safe_destroy.rpc()

func _safe_destroy_rpc_wrapper():
	_safe_destroy.rpc()

@rpc("any_peer", "call_local", "reliable")
func _safe_destroy():
	# Останавливаем полет и логику на всех клиентах
	set_physics_process(false)
	
	# Скрываем меш/спрайт стрелы на всех клиентах
	visible = false
	
	# Отключаем коллизии везде
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Каждый дослушивает звук локально
	if has_node("AudioStreamPlayer3D") and $AudioStreamPlayer3D.is_playing():
		await $AudioStreamPlayer3D.finished
	
	# Только сервер окончательно удаляет узел из сети
	if multiplayer.is_server():
		queue_free()
