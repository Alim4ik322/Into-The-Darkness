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
@onready var anim_player: AnimationPlayer = $Archer_model/AnimationPlayer
@onready var model = $Archer_model

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if anim_player:
		print("--- ДОСТУПНЫЕ АНИМАЦИИ ЛУЧНИКА ---")
		var libs = anim_player.get_animation_library_list()
		for lib_name in libs:
			var lib = anim_player.get_animation_library(lib_name)
			for anim in lib.get_animation_list():
				print("Библиотека: ", lib_name, " | Анимация: ", anim)
		print("----------------------------------")
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

func _update_animation(anim_name: String, speed: float = 1.0) -> void:
	if not anim_player: return
	
	var target_anim = ""
	
	# 1. Прямое совпадение
	if anim_player.has_animation(anim_name):
		target_anim = anim_name
	else:
		# 2. Поиск по частичному совпадению (например "Walk" в "Archer/Walk-loop")
		var all_anims = anim_player.get_animation_library_list()
		for lib_name in all_anims:
			var lib = anim_player.get_animation_library(lib_name)
			for a in lib.get_animation_list():
				var full_path = str(lib_name) + "/" + str(a) if str(lib_name) != "" else str(a)
				if a.to_lower().contains(anim_name.to_lower()):
					target_anim = full_path
					break
			if target_anim != "": break

	if target_anim != "":
		if anim_player.current_animation != target_anim:
			anim_player.play(target_anim, ANIM_BLEND)
		anim_player.speed_scale = speed
	else:
		# Если не нашли, выведем список доступных (один раз для отладки)
		# print("Animation not found: ", anim_name, ". Available: ", anim_player.get_animation_list())
		pass

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
