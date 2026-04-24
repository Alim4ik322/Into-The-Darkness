extends CharacterBody3D

const WALK_SPEED = 8.0
const RUN_SPEED = 15.0
const CROUCH_SPEED = 4.0
const GRAVITY = 30.0
const JUMP_VELOCITY = 12.0
const ANIM_BLEND = 0.3

var is_paused = false
var is_crouching = false 

@onready var camera_pivot = $CameraPivot
@onready var anim_player = $Archer_model/AnimationPlayer
@onready var model = $Archer_model

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Включаем анимацию покоя сразу
	_update_animation("Idle")

func _physics_process(delta):
	if is_paused: return
	
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var move_dir = (camera_pivot.global_transform.basis.x * input_dir.x + camera_pivot.global_transform.basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	var is_moving = move_dir != Vector3.ZERO
	var is_running = Input.is_action_pressed("Shift") and is_moving

	var target_speed = WALK_SPEED
	if is_crouching:
		target_speed = CROUCH_SPEED
	elif is_running:
		target_speed = RUN_SPEED

	if is_moving:
		velocity.x = move_dir.x * target_speed
		velocity.z = move_dir.z * target_speed
		# Плавный поворот модели
		model.rotation.y = lerp_angle(model.rotation.y, atan2(move_dir.x, move_dir.z), delta * 10.0)
		
		if is_crouching:
			_update_animation("Crouch_Walk") # Попробуем такое имя
		elif is_running:
			_update_animation("Run")
		else:
			_update_animation("Walk")
	else:
		_stop_movement()
		if is_crouching:
			_update_animation("Crouch_Idle")
		else:
			_update_animation("Idle")

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = max(velocity.y, 0)
	
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		is_crouching = false

	move_and_slide()

func _stop_movement():
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
	velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

func _update_animation(anim_name, speed = 1.0):
	# Пробуем найти анимацию с префиксом библиотеки (если она в glb)
	var full_anim_name = anim_name
	if not anim_player.has_animation(anim_name):
		# Пытаемся найти вариант Archer/Idle или Archer_Idle
		if anim_player.has_animation("Archer/" + anim_name):
			full_anim_name = "Archer/" + anim_name
		elif anim_player.has_animation("Library/" + anim_name):
			full_anim_name = "Library/" + anim_name

	if anim_player.has_animation(full_anim_name):
		if anim_player.current_animation != full_anim_name:
			anim_player.play(full_anim_name, ANIM_BLEND)
		anim_player.speed_scale = speed

func _input(event):
	if event.is_action_pressed("C") and not event.is_echo():
		is_crouching = !is_crouching
	
	if event.is_action_pressed("esc") and not event.is_echo():
		if is_paused: resume_game()
		else: pause_game()

func pause_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_paused = true

func resume_game():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_paused = false
