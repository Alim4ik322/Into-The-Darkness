extends CharacterBody3D

const WALK_SPEED = 8.0
const RUN_SPEED = 15.0
const CROUCH_SPEED = 4.0
const ROLL_SPEED = 15.0
const DASH_SPEED = 20.0
const GRAVITY = 30.0
const JUMP_VELOCITY = 12.0
const ANIM_BLEND = 0.3

var is_paused = false
var is_playing_music = false
var is_crouching = false
var is_rolling = false
var is_dashing = false
var is_capo = false

var roll_timer = 0.0
var dash_timer = 0.0
var dash_cooldown = 0.0

var forced_velocity = Vector3.ZERO

# --- Логика двойного нажатия (Dashes) ---
var last_press_time = {"up": 0, "down": 0, "left": 0, "right": 0}
const DOUBLE_TAP_TIME = 250 # ms

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
	if is_paused: return
	
	if hungry_bar: hungry_bar.value -= 1.0 * delta
	if water_bar: water_bar.value -= 0.5 * delta
	if mp_bar: mp_bar.value = min(100, mp_bar.value + 0.1)
	
	if dash_cooldown > 0: dash_cooldown -= delta
	
	if Input.is_key_pressed(KEY_V):
		is_capo = true
		_apply_gravity(delta)
		_stop_movement(delta)
		_update_animation("capo")
		move_and_slide()
		return
	else:
		is_capo = false
		
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
		else:
			velocity.x = forced_velocity.x
			velocity.z = forced_velocity.z
			_apply_gravity(delta)
			move_and_slide()
			return
			
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
		else:
			velocity.x = forced_velocity.x
			velocity.z = forced_velocity.z
			_apply_gravity(delta)
			move_and_slide()
			return

	if Input.is_key_pressed(KEY_ALT) and is_on_floor() and not is_rolling and not is_dashing and (stamina_bar.value if stamina_bar else 100) >= 20:
		_perform_roll()
		return

	var input_dir = Input.get_vector("right", "left", "down", "up")
	var move_dir = (camera_pivot.global_transform.basis.x * input_dir.x + camera_pivot.global_transform.basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	var is_moving = move_dir != Vector3.ZERO
	var is_running = Input.is_action_pressed("Shift") and (stamina_bar.value if stamina_bar else 100) > 0 and is_moving
	if is_running: is_crouching = false 

	var target_speed = WALK_SPEED
	if is_crouching:
		target_speed = CROUCH_SPEED
		if stamina_bar: stamina_bar.value = min(100, stamina_bar.value + 5 * delta)
	elif is_running:
		target_speed = RUN_SPEED
		if stamina_bar: stamina_bar.value = max(0, stamina_bar.value - 20 * delta)
	else:
		if stamina_bar: stamina_bar.value = min(100, stamina_bar.value + 10 * delta)

	if is_moving:
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed
		
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(move_dir.x, move_dir.z), delta * 10.0)
		
		if is_crouching:
			_update_animation("crouch_forward", 0.8)
		elif is_running:
			_update_animation("crouch_forward", 1.8)
		else:
			_update_animation("crouch_forward", 1.2)
	else:
		_stop_movement(delta)
		_update_animation("idle", 1.0)

	_apply_gravity(delta)
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		is_crouching = false

	move_and_slide()

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = max(velocity.y, 0)

func _stop_movement(delta):
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
	velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

func _perform_roll():
	is_rolling = true
	roll_timer = 0.6
	if stamina_bar: stamina_bar.value -= 20
	_update_animation("somersault", 1.0)
	
	var roll_dir = Vector3.ZERO
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var move_dir = (camera_pivot.global_transform.basis.x * input_dir.x + camera_pivot.global_transform.basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()
	
	if move_dir != Vector3.ZERO:
		roll_dir = move_dir
		if model:
			model.rotation.y = atan2(roll_dir.x, roll_dir.z)
	else:
		roll_dir = Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)).normalized()
		
	forced_velocity = roll_dir * ROLL_SPEED

func _perform_dash(action: String):
	if is_dashing or is_rolling or dash_cooldown > 0 or (stamina_bar.value if stamina_bar else 100) < 15: return
	
	is_dashing = true
	dash_timer = 0.3
	dash_cooldown = 0.5
	if stamina_bar: stamina_bar.value -= 15
	
	var dash_dir = Vector3.ZERO
	var anim_name = "dash_forward"
	
	match action:
		"up":
			dash_dir = camera_pivot.global_transform.basis.z
			anim_name = "dash_forward"
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
	
	forced_velocity = dash_dir * DASH_SPEED
	_update_animation(anim_name, 1.5)
	
	if model:
		model.rotation.y = atan2(camera_pivot.global_transform.basis.z.x, camera_pivot.global_transform.basis.z.z)

func _update_animation(anim_name: String, speed: float = 1.0):
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
				
	if target != "":
		if anim_player.current_animation != target:
			anim_player.play(target, ANIM_BLEND)
		anim_player.speed_scale = speed

func _input(event):
	if is_paused: return
	
	if event.is_action_pressed("C") and not event.is_echo():
		is_crouching = !is_crouching

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
