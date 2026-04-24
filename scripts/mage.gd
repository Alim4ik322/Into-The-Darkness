extends CharacterBody3D

class_name MagePlayer

# --- Константы настроек ---
const MOVE_SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const GRAVITY: float = 30.0
const ACCELERATION: float = 10.0 
const MUSIC_TOGGLE_KEY: int = KEY_M

# Костыль для поворота (90 градусов в радианах)
const ROTATION_FIX: float = deg_to_rad(-90) 

# Настройки камеры
const FOV_IDLE: float = 75.0
const FOV_RUN: float = 85.0
const FOV_LERP: float = 5.0

# Анимации
const ANIM_IDLE: String = "idle"
const ANIM_WALK: String = "walking"
const ANIM_RUN: String = "running"

# --- Узлы ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera3D = find_child("Camera3D", true) as Camera3D
@onready var ui: Control = find_child("UI", true) as Control
@onready var hp_bar = find_child("HPProgressBar", true) as Range
@onready var st_bar = find_child("StaminaProgressBar", true) as Range
@onready var hu_bar = find_child("HungryProgressBar", true) as Range
@onready var wa_bar = find_child("WaterProgressBar", true) as Range
@onready var model: Node3D = $"mg-anim"

# --- Переменные состояния ---
var is_playing_music: bool = false
var health: int = 100
var stamina: float = 100.0
var hunger: float = 100.0
var stirst: float = 100.0
var current_animation: String = ""

# --- Сетевая логика ---
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

@rpc("any_peer", "call_local", "reliable")
func force_teleport(new_pos: Vector3):
	global_position = new_pos
	velocity = Vector3.ZERO

func _ready() -> void:
	if not is_multiplayer_authority():
		if camera: camera.current = false
		if ui: ui.hide()
		return

	if camera: camera.make_current()
	if ui: ui.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		if hp_bar: hp_bar.value = health
		if st_bar: st_bar.value = stamina
		if hu_bar: hu_bar.value = hunger
		if wa_bar: wa_bar.value = stirst

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = Vector3.ZERO

	if camera:
		var forward = -camera.global_transform.basis.z
		forward.y = 0
		var right = camera.global_transform.basis.x
		right.y = 0
		direction = (forward * input_dir.y - right * input_dir.x).normalized()

	var sprinting = Input.is_action_pressed("Shift")
	
	if camera:
		var target_fov = FOV_RUN if (sprinting and direction.length() > 0.1) else FOV_IDLE
		camera.fov = lerp(camera.fov, target_fov, delta * FOV_LERP)

	var target_vel = Vector3.ZERO
	
	if direction.length() > 0.001:
		var move_speed = RUN_SPEED if sprinting else MOVE_SPEED
		target_vel = direction * move_speed
		
		var anim = ANIM_RUN if sprinting else ANIM_WALK
		_play_animation(anim, ANIM_WALK)
		
		# ПОВОРОТ С УЧЕТОМ КОСТЫЛЯ
		if model:
			# К углу движения (atan2) добавляем наш ROTATION_FIX
			var target_rot = atan2(direction.x, direction.z) + ROTATION_FIX
			model.rotation.y = lerp_angle(model.rotation.y, target_rot, delta * 10)
	else:
		_play_animation(ANIM_IDLE)
		# В IDLE плавно возвращаем в 0, если нужно, 
		# либо оставляем как есть, если в Blender IDLE стоит ровно
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, 0, delta * 10)

	var current_accel = ACCELERATION if is_on_floor() else 2.0
	velocity.x = lerp(velocity.x, target_vel.x, delta * current_accel)
	velocity.z = lerp(velocity.z, target_vel.z, delta * current_accel)

	move_and_slide()

func _play_animation(preferred_name: String, fallback_name: String = "") -> void:
	if anim_player == null: return
	var chosen_name: String = ""
	if preferred_name != "" and anim_player.has_animation(preferred_name):
		chosen_name = preferred_name
	elif fallback_name != "" and anim_player.has_animation(fallback_name):
		chosen_name = fallback_name
	
	if chosen_name == "" or current_animation == chosen_name: return
	anim_player.play(chosen_name)
	current_animation = chosen_name
