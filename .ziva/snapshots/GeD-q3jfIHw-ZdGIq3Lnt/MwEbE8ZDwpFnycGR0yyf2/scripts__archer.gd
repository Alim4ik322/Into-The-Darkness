extends CharacterBody3D

const WALK_SPEED = 8.0
const RUN_SPEED = 15.0
const CROUCH_SPEED = 4.0
const ROLL_SPEED = 18.0 # Чуть быстрее бега
const DASH_SPEED = 16.0 # Уменьшил скорость рывка
const GRAVITY = 30.0
const JUMP_VELOCITY = 12.0
const ANIM_BLEND = 0.2

var is_paused = false
var is_crouching = false

enum State { IDLE, MOVING, ROLLING, DASHING, CAPO }
var current_state = State.IDLE

var roll_timer = 0.0
const ROLL_DURATION = 0.6
var dash_timer = 0.0
const DASH_DURATION = 0.3
var dash_cooldown = 0.0

var forced_velocity = Vector3.ZERO
var last_press_time = {"up": 0, "down": 0, "left": 0, "right": 0}
const DOUBLE_TAP_TIME = 250

@onready var camera_pivot = $CameraPivot
@onready var model = $Archer_model
@onready var anim_player = null

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
	is_crouching = false
	current_state = State.IDLE
	
	# Имя ноды - это ID игрока. Устанавливаем власть.
	if name.is_valid_int():
		var id = name.to_int()
		set_multiplayer_authority(id)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(id)
		
	# Поиск камеры
	var camera = find_child("Camera3D", true)
	if is_multiplayer_authority():
		if camera:
			camera.make_current()
	else:
		if camera:
			camera.current = false
			camera.enabled = false
		set_physics_process(false)
		set_process_input(false)
		if has_node("UI"):
			$UI.hide()

	anim_player = _find_animation_player(model)
	if has_node("UI/HP"): $UI/HP.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_show_all_meshes(model)
	_update_animation("idle")

func _show_all_meshes(node: Node):
	if node is MeshInstance3D:
		node.visible = true
	for child in node.get_children():
		_show_all_meshes(child)

func _physics_process(delta):
	if not multiplayer.has_multiplayer_peer(): return
	if not is_multiplayer_authority(): return
	if is_paused: return
	
	# Регенерация и нужды (оптимизировано как у воина)
	_update_stats(delta)
	
	if dash_cooldown > 0: dash_cooldown -= delta

	# Обработка состояний
	match current_state:
		State.CAPO:
			_handle_capo_state(delta)
		State.ROLLING:
			_handle_roll_state(delta)
		State.DASHING:
			_handle_dash_state(delta)
		_:
			_handle_normal_state(delta)

	_apply_gravity(delta)
	move_and_slide()

func _update_stats(delta):
	if hungry_bar: hungry_bar.value -= 1.0 * delta
	if water_bar: water_bar.value -= 0.5 * delta
	if mp_bar: mp_bar.value = min(100, mp_bar.value + 0.5 * delta) # Реген маны быстрее
	
	# Регенерация стамины (у лучника она быстрее, так как он ловкач)
	if stamina_bar:
		var regen_mult = 1.0
		if current_state == State.IDLE: regen_mult = 2.0
		elif is_crouching: regen_mult = 1.5
		
		# Если не бежим и не кувыркаемся - регеним
		if not Input.is_action_pressed("Shift") or not (current_state == State.MOVING):
			stamina_bar.value = min(100, stamina_bar.value + 20 * regen_mult * delta)

func _handle_capo_state(delta):
	if not Input.is_key_pressed(KEY_V):
		current_state = State.IDLE
		return
	_stop_movement(delta)
	_update_animation("capo")

func _handle_roll_state(delta):
	roll_timer -= delta
	velocity.x = forced_velocity.x
	velocity.z = forced_velocity.z
	
	if roll_timer <= 0:
		current_state = State.IDLE
		velocity.x *= 0.5
		velocity.z *= 0.5
		# Сбрасываем позицию модели и всех её дочерних узлов, если анимация имела смещение
		if model:
			model.position = Vector3.ZERO
			for child in model.get_children():
				if child is Node3D:
					child.position = Vector3.ZERO

func _handle_dash_state(delta):
	dash_timer -= delta
	velocity.x = forced_velocity.x
	velocity.z = forced_velocity.z
	
	if dash_timer <= 0:
		current_state = State.IDLE
		velocity.x *= 0.3
		velocity.z *= 0.3
		# Сбрасываем позицию модели после рывка
		if model:
			model.position = Vector3.ZERO
			for child in model.get_children():
				if child is Node3D:
					child.position = Vector3.ZERO

func _handle_normal_state(delta):
	if Input.is_key_pressed(KEY_V):
		current_state = State.CAPO
		return

	# Направление движения (ИСПРАВИЛ ПОРЯДОК: left, right, up, down)
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var move_dir = (camera_pivot.global_transform.basis.x * input_dir.x + camera_pivot.global_transform.basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	var is_moving = move_dir != Vector3.ZERO
	var is_running = Input.is_action_pressed("Shift") and stamina_bar.value > 0 and is_moving
	
	if is_running: 
		is_crouching = false
		stamina_bar.value -= 15 * delta # Бег тратит стамину

	var target_speed = WALK_SPEED
	if is_crouching:
		target_speed = CROUCH_SPEED
	elif is_running:
		target_speed = RUN_SPEED

	if is_moving:
		current_state = State.MOVING
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed
		
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(move_dir.x, move_dir.z), delta * 10.0)
		
		# Анимации
		if is_crouching:
			_update_animation("crouch_forward", 0.8)
		elif is_running:
			_update_animation("crouch_forward", 1.8)
		else:
			_update_animation("crouch_forward", 1.2)
	else:
		current_state = State.IDLE
		_stop_movement(delta)
		if is_crouching:
			_update_animation("idle", 0.5)
		else:
			_update_animation("idle", 1.0)

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

func _stop_movement(delta):
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED * 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, WALK_SPEED * 10.0 * delta)

func _perform_roll():
	current_state = State.ROLLING
	roll_timer = ROLL_DURATION
	stamina_bar.value -= 15 # Уменьшил стоимость до 15
	
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var move_dir = (camera_pivot.global_transform.basis.x * input_dir.x + camera_pivot.global_transform.basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()
	
	# Если стоим на месте - катимся вперед
	var roll_dir = move_dir if move_dir != Vector3.ZERO else model.global_transform.basis.z
	roll_dir = roll_dir.normalized()
	
	if model:
		model.rotation.y = atan2(roll_dir.x, roll_dir.z)
		
	forced_velocity = roll_dir * ROLL_SPEED
	# Синхронизируем скорость анимации: если анимация 1с, а таймер 0.6с, то скорость 1.66
	_update_animation("somersault", 1.6, 0.1) 

func _perform_dash(action: String):
	if current_state == State.DASHING or current_state == State.ROLLING or dash_cooldown > 0 or stamina_bar.value < 10: return
	
	current_state = State.DASHING
	dash_timer = DASH_DURATION
	dash_cooldown = 0.4
	stamina_bar.value -= 10 
	
	var dash_dir = Vector3.ZERO
	var anim_name = "dash_forward"
	
	# Теперь направления совпадают с ходьбой
	match action:
		"up": dash_dir = camera_pivot.global_transform.basis.z 
		"down": 
			dash_dir = -camera_pivot.global_transform.basis.z
			anim_name = "backdash"
		"left": 
			dash_dir = camera_pivot.global_transform.basis.x
			anim_name = "dash_left"
		"right": 
			dash_dir = -camera_pivot.global_transform.basis.x
			anim_name = "dash_right"
			
	dash_dir.y = 0
	dash_dir = dash_dir.normalized()
	
	if model:
		model.rotation.y = atan2(dash_dir.x, dash_dir.z)
		
	forced_velocity = dash_dir * DASH_SPEED
	_update_animation(anim_name, 1.5, 0.1)

func _update_animation(anim_name: String, speed: float = 1.0, blend: float = ANIM_BLEND):
	if not anim_player: return
	
	var target = ""
	if anim_player.has_animation(anim_name):
		target = anim_name
	else:
		var all_anims = anim_player.get_animation_library_list()
		for lib_name in all_anims:
			var lib = anim_player.get_animation_library(lib_name)
			if lib.has_animation(anim_name):
				target = str(lib_name) + "/" + anim_name
				break
				
	if target != "" and anim_player.current_animation != target:
		anim_player.play(target, blend)
		anim_player.speed_scale = speed

func _input(event):
	if not is_multiplayer_authority(): return
	if is_paused: return
	
	if event.is_action_pressed("C") and not event.is_echo():
		is_crouching = !is_crouching

	# Ролл по нажатию Alt (только один раз за нажатие)
	if event is InputEventKey:
		if event.keycode == KEY_ALT and event.pressed and not event.is_echo():
			if is_on_floor() and current_state != State.ROLLING and stamina_bar.value >= 15:
				_perform_roll()

	for action in ["up", "down", "left", "right"]:
		if event.is_action_pressed(action) and not event.is_echo():
			var now = Time.get_ticks_msec()
			if now - last_press_time[action] < DOUBLE_TAP_TIME:
				_perform_dash(action)
			last_press_time[action] = now

	if event.is_action_pressed("esc") and not event.is_echo():
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
