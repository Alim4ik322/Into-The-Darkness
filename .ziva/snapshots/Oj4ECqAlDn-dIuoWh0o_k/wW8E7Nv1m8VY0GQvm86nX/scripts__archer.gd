extends CharacterBody3D

# --- Параметры движения ---
const WALK_SPEED = 6.0
const RUN_SPEED = 12.0
const CROUCH_SPEED = 3.5
const ROLL_SPEED = 14.0
const DASH_SPEED = 22.0
const GRAVITY = 30.0
const JUMP_VELOCITY = 10.0
const ANIM_BLEND = 0.2

# --- Состояния ---
var is_paused = false
var is_crouching = false 
var is_rolling = false
var is_dashing = false
var is_capo = false

# --- Логика двойного нажатия (Dashes) ---
var last_press_time = {"up": 0, "down": 0, "left": 0, "right": 0}
const DOUBLE_TAP_TIME = 250 # ms

@onready var camera_pivot = $CameraPivot
@onready var model = $Archer_model
@onready var anim_player: AnimationPlayer = _find_animation_player(model)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if not node: return null
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var res = _find_animation_player(child)
		if res: return res
	return null

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_animation("idle")
	
	# Пытаемся найти и показать все меши (на случай если лук скрыт)
	_show_all_meshes(model)

func _show_all_meshes(node: Node):
	if node is MeshInstance3D:
		node.visible = true
	for child in node.get_children():
		_show_all_meshes(child)

func _physics_process(delta):
	if is_paused or not camera_pivot: return
	
	# 1. Анимация Capo (Кнопка V)
	if Input.is_key_pressed(KEY_V):
		is_capo = true
		_update_animation("capo")
		_stop_movement()
		move_and_slide()
		return
	else:
		is_capo = false

	# 2. Перекат (Кнопка Alt)
	if Input.is_key_pressed(KEY_ALT) and is_on_floor() and not is_rolling and not is_dashing:
		_perform_roll()

	# Если мы в процессе переката или рывка, пропускаем обычное управление
	if is_rolling or is_dashing:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	# 3. Обычное передвижение
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var move_dir = (camera_pivot.global_transform.basis.x * input_dir.x + camera_pivot.global_transform.basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	var is_moving = move_dir != Vector3.ZERO
	var is_running = Input.is_action_pressed("Shift") and is_moving and not is_crouching

	var target_speed = WALK_SPEED
	if is_crouching:
		target_speed = CROUCH_SPEED
	elif is_running:
		target_speed = RUN_SPEED

	if is_moving:
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed
		model.rotation.y = lerp_angle(model.rotation.y, atan2(move_dir.x, move_dir.z), delta * 12.0)
		
		if is_running:
			_update_animation("run")
		else:
			# Юзаем "crouch forward" для обычной ходьбы как просил юзер
			_update_animation("crouch forward")
	else:
		_stop_movement()
		if is_crouching:
			_update_animation("crouch idle")
		else:
			_update_animation("idle")

	# Гравитация и прыжок
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		is_crouching = false

	move_and_slide()

# --- Логика Переката ---
func _perform_roll():
	is_rolling = true
	_update_animation("somersault")
	
	# Направление переката - вперед по взгляду модели
	var roll_dir = -model.global_transform.basis.z
	velocity.x = roll_dir.x * ROLL_SPEED
	velocity.z = roll_dir.z * ROLL_SPEED
	
	# Длительность анимации somersault примерно 0.7с
	await get_tree().create_timer(0.7).timeout
	is_rolling = false

# --- Логика Рывка (Dash) ---
func _perform_dash(dir_name: String):
	if is_dashing or is_rolling: return
	is_dashing = true
	
	var dash_dir = Vector3.ZERO
	var anim_suffix = "forward"
	
	match dir_name:
		"up": 
			dash_dir = -camera_pivot.global_transform.basis.z
			anim_suffix = "forward"
		"down": 
			dash_dir = camera_pivot.global_transform.basis.z
			anim_suffix = "backward"
		"left": 
			dash_dir = -camera_pivot.global_transform.basis.x
			anim_suffix = "left"
		"right": 
			dash_dir = camera_pivot.global_transform.basis.x
			anim_suffix = "right"
	
	dash_dir.y = 0
	dash_dir = dash_dir.normalized()
	
	velocity = dash_dir * DASH_SPEED
	_update_animation("dash " + anim_suffix)
	
	# Поворачиваем модель в сторону дэша мгновенно
	model.rotation.y = atan2(dash_dir.x, dash_dir.z)
	
	# Длительность дэша
	await get_tree().create_timer(0.4).timeout
	is_dashing = false

func _stop_movement():
	velocity.x = move_toward(velocity.x, 0, 1.0)
	velocity.z = move_toward(velocity.z, 0, 1.0)

# --- Умная система анимаций ---
func _update_animation(anim_name: String):
	if not anim_player: return
	
	var target = ""
	var all_anims = anim_player.get_animation_library_list()
	for lib_name in all_anims:
		var lib = anim_player.get_animation_library(lib_name)
		for a in lib.get_animation_list():
			# Ищем по вхождению строки (регистронезависимо)
			if a.to_lower() == anim_name.to_lower() or a.to_lower().contains(anim_name.to_lower()):
				target = str(lib_name) + "/" + str(a) if str(lib_name) != "" else str(a)
				break
		if target != "": break
	
	if target != "" and anim_player.current_animation != target:
		anim_player.play(target, ANIM_BLEND)

func _input(event):
	if is_paused: return
	
	# Присед
	if event.is_action_pressed("C"):
		is_crouching = !is_crouching

	# Двойное нажатие для Рывков (WASD)
	for action in ["up", "down", "left", "right"]:
		if event.is_action_pressed(action):
			var now = Time.get_ticks_msec()
			if now - last_press_time[action] < DOUBLE_TAP_TIME:
				_perform_dash(action)
			last_press_time[action] = now

	# Пауза
	if event.is_action_pressed("esc"):
		if is_paused: resume_game()
		else: pause_game()

func pause_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_paused = true

func resume_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_paused = false
