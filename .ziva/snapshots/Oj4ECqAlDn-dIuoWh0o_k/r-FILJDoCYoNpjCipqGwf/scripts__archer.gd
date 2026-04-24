extends CharacterBody3D

# --- Параметры движения ---
const WALK_SPEED = 7.0
const RUN_SPEED = 14.0
const CROUCH_SPEED = 3.5
const ROLL_SPEED = 10.0
const ROLL_DURATION = 0.6
const DASH_SPEED = 16.0
const GRAVITY = 30.0
const JUMP_VELOCITY = 11.0
const ANIM_BLEND = 0.2

# --- Состояния ---
var is_paused = false
var is_crouching = false 
var is_rolling = false
var is_dashing = false
var is_capo = false
var roll_time_left = 0.0
var roll_velocity = Vector3.ZERO

# --- Логика двойного нажатия (Dashes) ---
var last_press_time = {"up": 0, "down": 0, "left": 0, "right": 0}
const DOUBLE_TAP_TIME = 250 # ms
var dash_cooldown = 0.0

@onready var camera_pivot = $CameraPivot
@onready var model = $Archer_model
@onready var anim_player: AnimationPlayer = _find_animation_player(model)

# UI Ссылки (теперь они будут в Archer.tscn)
@onready var mp_bar = $UI/MPProgressBar
@onready var stamina_bar = $UI/StaminaProgressBar
@onready var hungry_bar = $UI/HungryProgressBar
@onready var water_bar = $UI/WaterProgressBar

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
	_show_all_meshes(model)
	if has_node("UI/HP"): $UI/HP.play()

func _show_all_meshes(node: Node):
	if node is MeshInstance3D:
		node.visible = true
	for child in node.get_children():
		_show_all_meshes(child)

func _physics_process(delta):
	if is_paused or not camera_pivot: return
	
	# Статы
	if hungry_bar: hungry_bar.value -= 0.8 * delta
	if water_bar: water_bar.value -= 0.4 * delta
	if mp_bar: mp_bar.value = min(100, mp_bar.value + 0.1)
	
	if dash_cooldown > 0: dash_cooldown -= delta

	# 1. Анимация Capo (Кнопка V)
	if Input.is_key_pressed(KEY_V):
		is_capo = true
		_update_animation("capo")
		_stop_movement(delta)
		move_and_slide()
		return
	else:
		is_capo = false

	# 2. Перекат (Кнопка Alt)
	if Input.is_key_pressed(KEY_ALT) and is_on_floor() and not is_rolling and not is_dashing and (stamina_bar.value if stamina_bar else 100) >= 20:
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
	var is_running = Input.is_action_pressed("Shift") and is_moving and not is_crouching and (stamina_bar.value if stamina_bar else 100) > 0

	var target_speed = WALK_SPEED
	if is_crouching:
		target_speed = CROUCH_SPEED
		if stamina_bar: stamina_bar.value = min(100, stamina_bar.value + 5 * delta)
	elif is_running:
		target_speed = RUN_SPEED
		if stamina_bar: stamina_bar.value = max(0, stamina_bar.value - 15 * delta)
	else:
		target_speed = WALK_SPEED
		if stamina_bar: stamina_bar.value = min(100, stamina_bar.value + 10 * delta)

	if is_moving:
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(move_dir.x, move_dir.z), delta * 12.0)
		
		if is_running:
			_update_animation("run")
		elif is_crouching:
			_update_animation("crouch walk")
		else:
			# Юзаем "crouch forward" для обычной ходьбы по просьбе юзера
			_update_animation("crouch forward")
	else:
		_stop_movement(delta)
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
	if stamina_bar: stamina_bar.value -= 20
	_update_animation("somersault")
	
	# Направление переката - назад или вперед? Юзер говорит "все деши и увороты не в ту сторону"
	var roll_dir = model.global_transform.basis.z # инвертировано (было -z)
	velocity.x = roll_dir.x * ROLL_SPEED
	velocity.z = roll_dir.z * ROLL_SPEED
	
	await get_tree().create_timer(0.6).timeout
	is_rolling = false

# --- Логика Рывка (Dash) ---
func _perform_dash(dir_name: String):
	if is_dashing or is_rolling or dash_cooldown > 0 or (stamina_bar.value if stamina_bar else 100) < 15: return
	is_dashing = true
	if stamina_bar: stamina_bar.value -= 15
	dash_cooldown = 0.5
	
	var dash_dir = Vector3.ZERO
	var anim_name = "dash forward"
	
	# Направление относительно камеры (все инвертировано)
	match dir_name:
		"up": 
			dash_dir = camera_pivot.global_transform.basis.z
			anim_name = "dash forward"
		"down": 
			dash_dir = -camera_pivot.global_transform.basis.z
			anim_name = "dash backward"
		"left": 
			dash_dir = camera_pivot.global_transform.basis.x
			anim_name = "dash left"
		"right": 
			dash_dir = -camera_pivot.global_transform.basis.x
			anim_name = "dash right"
	
	dash_dir.y = 0
	dash_dir = dash_dir.normalized()
	
	velocity = dash_dir * DASH_SPEED
	_update_animation(anim_name)
	
	if model:
		model.rotation.y = atan2(dash_dir.x, dash_dir.z)
	
	await get_tree().create_timer(0.3).timeout
	is_dashing = false

func _stop_movement(delta: float):
	velocity.x = move_toward(velocity.x, 0, delta * 30.0)
	velocity.z = move_toward(velocity.z, 0, delta * 30.0)

# --- Умная система анимаций ---
func _update_animation(anim_name: String):
	if not anim_player: return
	
	var target = ""
	var all_anims = anim_player.get_animation_library_list()
	for lib_name in all_anims:
		var lib = anim_player.get_animation_library(lib_name)
		for a in lib.get_animation_list():
			if a.to_lower() == anim_name.to_lower() or a.to_lower().contains(anim_name.to_lower()):
				target = str(lib_name) + "/" + str(a) if str(lib_name) != "" else str(a)
				break
		if target != "": break
	
	if target != "" and anim_player.current_animation != target:
		anim_player.play(target, ANIM_BLEND)

func _input(event):
	if is_paused: return
	
	if event.is_action_pressed("C"):
		is_crouching = !is_crouching

	# Двойное нажатие
	for action in ["up", "down", "left", "right"]:
		if event.is_action_pressed(action):
			var now = Time.get_ticks_msec()
			if now - last_press_time[action] < DOUBLE_TAP_TIME:
				_perform_dash(action)
			last_press_time[action] = now

	if event.is_action_pressed("esc"):
		if is_paused: resume_game()
		else: pause_game()

func pause_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_paused = true
	if has_node("UI/Pause_menu"): $UI/Pause_menu.show()

func resume_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_paused = false
	if has_node("UI/Pause_menu"): $UI/Pause_menu.hide()
