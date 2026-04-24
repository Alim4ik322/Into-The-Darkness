extends CharacterBody3D

const WALK_SPEED = 8.0
const RUN_SPEED = 15.0
const CROUCH_SPEED = 4.0
const GRAVITY = 30.0
const JUMP_VELOCITY = 12.0
const ANIM_BLEND = 0.15 # Сделал чуть быстрее для отзывчивости

var is_paused = false
var is_playing_music = false
var is_crouching = false

@onready var camera_pivot = $CameraPivot
@onready var anim_player = $AnimationPlayer
@onready var mp_bar = $UI/MPProgressBar
@onready var stamina_bar = $UI/StaminaProgressBar
@onready var hungry_bar = $UI/HungryProgressBar
@onready var water_bar = $UI/WaterProgressBar
@onready var model = $"wariror/Воин"
@onready var lute = $Lute

func _ready():
	# Имя ноды - это ID игрока. Устанавливаем власть.
	if name.is_valid_int():
		set_multiplayer_authority(int(str(name)))
	
	# Настройка синхронизации
	if not has_node("MultiplayerSynchronizer"):
		var sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		var config = SceneReplicationConfig.new()
		config.add_property(".:global_position")
		config.add_property("wariror/Воин:rotation")
		config.add_property("AnimationPlayer:current_animation")
		sync.replication_config = config
		# ВАЖНО: Устанавливаем власть синхронизатора ТАКУЮ ЖЕ как у игрока
		sync.set_multiplayer_authority(int(str(name)))
		add_child(sync)

	# Путь к камере
	var camera_path = "CameraPivot/CameraVerticalPivot/CameraZoomPivot/Camera3D"
	var camera = get_node_or_null(camera_path)

	if is_multiplayer_authority():
		# Эта камера ТВОЯ
		if camera:
			camera.make_current()
			camera.current = true
	else:
		# Эта камера ЧУЖАЯ
		if camera:
			camera.current = false
		if has_node("UI"):
			$UI.hide()

	$UI/HP.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if lute: lute.visible = false

func _physics_process(delta):
	if not multiplayer.has_multiplayer_peer(): return
	if not is_multiplayer_authority(): return
	if is_paused: return
	
	# Сброс позиции модели (на всякий случай)
	model.position = Vector3.ZERO 

	# Если играем на лютне — стоим
	if is_playing_music:
		_apply_gravity(delta)
		_stop_movement()
		_update_animation("Idle")
		move_and_slide()
		return

	# Потребности
	hungry_bar.value -= 1.0 * delta
	water_bar.value -= 0.5 * delta
	
	# Направление движения (ИСПРАВИЛ ПОРЯДОК: left, right, up, down)
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var move_dir = (camera_pivot.global_transform.basis.x * input_dir.x + camera_pivot.global_transform.basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	var is_moving = move_dir != Vector3.ZERO
	
	# Логика бега: бежим только если есть стамина, зажат шифт, мы двигаемся и НЕ присели
	var want_to_run = Input.is_action_pressed("Shift") and stamina_bar.value > 1.0 and is_moving and not is_crouching

	var target_speed = WALK_SPEED

	if is_crouching:
		target_speed = CROUCH_SPEED
		stamina_bar.value = min(100, stamina_bar.value + 5 * delta)
	elif want_to_run:
		target_speed = RUN_SPEED
		stamina_bar.value = max(0, stamina_bar.value - 20 * delta)
	else:
		stamina_bar.value = min(100, stamina_bar.value + 10 * delta)

	# Управление скоростью и анимациями
	if is_moving:
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed
		
		# Плавный поворот модели в сторону движения
		var target_rotation = atan2(move_dir.x, move_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, delta * 10.0)
		
		# Выбор анимации движения
		if is_crouching:
			_update_animation("Crouch walk", 1.5)
		elif want_to_run:
			_update_animation("Run", 1.2)
		else:
			_update_animation("walk", 1.5)
	else:
		_stop_movement()
		# Анимация покоя
		if is_crouching:
			_update_animation("Crouch idle", 1.0)
		else:
			_update_animation("Idle", 1.0)

	_apply_gravity(delta)
	
	# Прыжок
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		is_crouching = false 

	move_and_slide()
	mp_bar.value = min(100, mp_bar.value + 0.1)

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = max(velocity.y, 0)

func _stop_movement():
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
	velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

func _update_animation(anim_name, speed = 1.0):
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name, ANIM_BLEND)
		anim_player.speed_scale = speed
	else:
		print("Ошибка: Анимация не найдена: ", anim_name)

func _input(event):
	if not is_multiplayer_authority(): return
	if is_paused: return
	
	# Переключение приседа на клавишу C (убедись, что в Input Map экшен называется "C")
	if event.is_action_pressed("C"):
		is_crouching = !is_crouching
	
	#if event.is_action_pressed("lute"):
		#is_playing_music = !is_playing_music
		#if lute: lute.visible = is_playing_music
		
	if event.is_action_pressed("esc"):
		if is_paused: resume_game()
		else: pause_game()

func pause_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_paused = true
	$UI/Pause_menu.show()

func resume_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_paused = false
	$UI/Pause_menu.hide()
