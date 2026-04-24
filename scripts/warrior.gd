extends CharacterBody3D

class_name WarriorPlayer

# --- Константы настроек ---
const MOVE_SPEED: float = 6.0
const RUN_SPEED: float = 9.0
const GRAVITY: float = 30.0
const ACCELERATION: float = 10.0 
const MUSIC_TOGGLE_KEY: int = KEY_M
const COMBAT_TOGGLE_KEY: int = KEY_R

# Настройки камеры
const FOV_IDLE: float = 75.0
const FOV_RUN: float = 85.0
const FOV_LERP: float = 5.0

# --- Узлы ---
@onready var anim_player: AnimationPlayer = $Warrior_final/AnimationPlayer
@onready var model: Node3D = $Warrior_final
@onready var camera: Camera3D = find_child("Camera3D", true) as Camera3D
@onready var ui: Control = find_child("UI", true) as Control

# Крепления оружия
@onready var sword_attach: BoneAttachment3D = find_child("Sword", true)
@onready var shield_attach: BoneAttachment3D = find_child("Shield", true)

# Полоски UI
@onready var hp_bar = find_child("HPProgressBar", true) as Range
@onready var st_bar = find_child("StaminaProgressBar", true) as Range
@onready var hu_bar = find_child("HungryProgressBar", true) as Range
@onready var wa_bar = find_child("WaterProgressBar", true) as Range

# --- Переменные состояния ---
var is_combat_mode: bool = false : set = _set_combat_mode
var is_attacking: bool = false
var is_blocking: bool = false

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
	
	_update_weapon_visibility()
	
	# Подключаем сигнал завершения анимации для сброса состояния атаки
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

# --- Логика Боевого Режима ---
func _set_combat_mode(value: bool):
	is_combat_mode = value
	if not is_combat_mode:
		is_blocking = false # Нельзя блокировать без щита
	_update_weapon_visibility()

func _update_weapon_visibility():
	if sword_attach: sword_attach.visible = is_combat_mode
	if shield_attach: shield_attach.visible = is_combat_mode

# --- Ввод ---
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	# Смена стойки на R
	if event.is_action_pressed("R"):
		is_combat_mode = !is_combat_mode

	# ЛОГИКА АТАКИ (Левая кнопка мыши)
	if event.is_action_pressed("attack") and not is_attacking and not is_blocking:
		if is_combat_mode:
			_start_attack("Sword_Attack_Slash", 1.4) # Быстрый удар мечом
		else:
			_start_attack("Punch", 1.2) # Удар рукой в мирном режиме

	# ЛОГИКА УДАРА НОГОЙ (Клавиша F)
	if event.is_action_pressed("F") and is_combat_mode and not is_attacking and not is_blocking:
		_start_attack("Kick", 1.3)

	# БЛОК (Правая кнопка мыши)
	if is_combat_mode and not is_attacking:
		if event.is_action_pressed("block"):
			is_blocking = true
		elif event.is_action_released("block"):
			is_blocking = false

# --- Универсальная функция запуска атаки ---
func _start_attack(anim_name: String, speed: float = 1.0):
	if anim_player.has_animation(anim_name):
		is_attacking = true
		anim_player.speed_scale = speed
		_play_smart_animation(anim_name)

func _on_animation_finished(anim_name: String):
	# Сбрасываем флаг атаки, если закончилась любая из боевых анимаций
	if anim_name in ["Sword_Attack_Slash", "Punch", "Kick"]:
		is_attacking = false
		anim_player.speed_scale = 1.0 # Возвращаем нормальную скорость для бега/ходьбы

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		if hp_bar: hp_bar.value = health
		if st_bar: st_bar.value = stamina
		if hu_bar: hu_bar.value = hunger
		if wa_bar: wa_bar.value = stirst

# --- Физика и Движение ---
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = Vector3.ZERO

	# Нельзя менять направление движения во время атаки
	var can_move = not is_attacking
	var current_move_speed = MOVE_SPEED

	if is_blocking: 
		current_move_speed *= 0.4 # Замедление со щитом

	if camera and can_move:
		var forward = -camera.global_transform.basis.z
		forward.y = 0
		var right = camera.global_transform.basis.x
		right.y = 0
		direction = (forward * input_dir.y - right * input_dir.x).normalized()

	var sprinting = Input.is_action_pressed("Shift") and direction.length() > 0.1 and not is_blocking and not is_attacking
	
	# FOV Камеры
	if camera:
		var target_fov = FOV_RUN if sprinting else FOV_IDLE
		camera.fov = lerp(camera.fov, target_fov, delta * FOV_LERP)

	var target_vel = Vector3.ZERO
	
	if not is_attacking:
		if is_blocking:
			_play_smart_animation("Block_Sword_and_Shield")
		elif direction.length() > 0.1:
			var move_speed = RUN_SPEED if sprinting else current_move_speed
			target_vel = direction * move_speed
			
			var anim_type = "Run" if sprinting else "Walk"
			_play_smart_animation(anim_type)
			
			if model:
				var target_rot = atan2(direction.x, direction.z)
				model.rotation.y = lerp_angle(model.rotation.y, target_rot, delta * 10)
		else:
			_play_smart_animation("Idle")
	else:
		# Во время атаки персонаж может немного катиться по инерции, но не управляться
		target_vel = velocity * 0.9 

	# Инерция
	var accel = ACCELERATION if is_on_floor() else 2.0
	velocity.x = lerp(velocity.x, target_vel.x, delta * accel)
	velocity.z = lerp(velocity.z, target_vel.z, delta * accel)

	move_and_slide()

# --- Система Анимаций ---
func _play_smart_animation(base_name: String) -> void:
	if anim_player == null: return
	
	var final_anim = base_name
	
	# Автоматические суффиксы для базовых движений
	if is_combat_mode and (base_name in ["Idle", "Walk", "Run"]):
		var combat_variant = base_name + "_Sword_and_Shield"
		if anim_player.has_animation(combat_variant):
			final_anim = combat_variant
	
	# Для специфических атак (Punch, Kick, Slash) играем напрямую
	if anim_player.has_animation(base_name) and not (base_name in ["Idle", "Walk", "Run"]):
		final_anim = base_name

	if current_animation != final_anim:
		anim_player.play(final_anim, 0.2)
		current_animation = final_anim
