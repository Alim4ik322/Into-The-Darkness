extends Area3D

const SPEED = 25.0
var shooter = null 

@export var damage: int = 100

func _ready():
	# Убираем ручной set_multiplayer_authority от shooter.
	# Сервер сам поставит себе права при спавне.
	
	get_tree().create_timer(5.0).timeout.connect(queue_free)
	
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
		queue_free()
		return

	# Если попали во что-то другое (пол, стены) — просто удаляем стрелу
	queue_free()
