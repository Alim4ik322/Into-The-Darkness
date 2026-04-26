extends CharacterBody3D

class_name MagePlayer

# --- [ КОНСТАНТЫ И НАСТРОЙКИ ] ---
@export_group("Magic Settings")
@export var fire_arrow_scene: PackedScene = preload("res://scenes/fire_arrow.tscn")
const FIRE_COST: float = 15.0

@export_group("Movement")
const MOVE_SPEED: float = 5.0
const RUN_SPEED: float  = 8.0
const GRAVITY: float    = 30.0
const ACCEL: float      = 10.0 
const ROTATION_FIX: float = deg_to_rad(-90) # Коррекция поворота модели

@export_group("Camera Settings")
const FOV_IDLE: float = 75.0
const FOV_RUN: float  = 85.0
const FOV_LERP: float = 5.0

# --- [ УЗЛЫ ] ---
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var model: Node3D = $"mg-anim"
@onready var camera: Camera3D = find_child("Camera3D", true) as Camera3D
@onready var ui: CanvasLayer = $UI # ИСПРАВЛЕНО: Прямой путь и тип CanvasLayer
@onready var fire_point = find_child("FireMuzzle", true)

# ИСПРАВЛЕНО: Прямые пути через $, чтобы Маг не "воровал" полоски Воина или другого Мага
@onready var hp_bar = $UI/HPProgressBar
@onready var mp_bar = $UI/MPProgressBar
@onready var st_bar = $UI/StaminaProgressBar
@onready var hu_bar = $UI/HungryProgressBar
@onready var wa_bar = $UI/WaterProgressBar

# --- [ ПЕРЕМЕННЫЕ СОСТОЯНИЯ ] ---
var is_dead: bool      = false
var is_attacking: bool = false
var current_anim: String = ""

var health: int = 100:
	set(v):
		health = clamp(v, 0, 100)
		if hp_bar: 
			hp_bar.value = health
		if health <= 0 and not is_dead: 
			_die()

var mana: float    = 100.0
var stamina: float = 100.0
var hunger: float  = 100.0
var stirst: float  = 100.0

var is_combat_mode: bool = false

# --- [ СИСТЕМНЫЕ ФУНКЦИИ ] ---

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		set_physics_process(false)
		return
		
	if not is_multiplayer_authority():
		if camera: camera.current = false
		# ЖЕСТКОЕ УДАЛЕНИЕ: Чтобы Маг не видел чужой UI и Хост не путался
		if ui: 
			ui.queue_free()
		return

	# Код ниже только для владельца
	if has_node("UI/HP"):
		$UI/HP.play("default")
		
	if camera: camera.make_current()
	if ui: 
		ui.show()
		ui.layer = 11 # У Мага слой чуть выше или такой же, как у Воина
		if hp_bar: hp_bar.value = health
		
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

# --- [ ОБРАБОТКА ВВОДА ] ---

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead: return
	
	if event.is_action_pressed("R"):
		is_combat_mode = !is_combat_mode

	if event.is_action_pressed("attack") and not is_attacking:
		if is_combat_mode and mana >= FIRE_COST:
			_cast_fireball()

func _cast_fireball() -> void:
	is_attacking = true
	mana -= FIRE_COST
	_play_animation("attack")

# --- [ ОБНОВЛЕНИЕ СТАТОВ ] ---

func _process(delta: float) -> void:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null: return
	if not is_multiplayer_authority(): return

	# Регенерация маны
	mana = min(mana + delta * 3.0, 100.0)
	
	# Обновление баров
	if hp_bar: hp_bar.value = health
	if mp_bar: mp_bar.value = mana
	if st_bar: st_bar.value = stamina
	if hu_bar: hu_bar.value = hunger
	if wa_bar: wa_bar.value = stirst
	
	if is_attacking and not anim_player.is_playing():
		is_attacking = false

# --- [ ФИЗИКА И ПЕРЕДВИЖЕНИЕ ] ---

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead: return
	
	_apply_gravity(delta)
	
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = _get_movement_direction(input_dir)
	
	_handle_movement(direction, delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _get_movement_direction(input: Vector2) -> Vector3:
	if not camera: return Vector3.ZERO
	
	var forward = -camera.global_transform.basis.z
	var right   = camera.global_transform.basis.x
	forward.y = 0; right.y = 0
	
	return (forward * input.y - right * input.x).normalized()

func _handle_movement(dir: Vector3, delta: float) -> void:
	var sprinting = Input.is_action_pressed("Shift") and dir.length() > 0.1
	var speed = RUN_SPEED if sprinting else MOVE_SPEED
	
	if camera:
		camera.fov = lerp(camera.fov, FOV_RUN if sprinting else FOV_IDLE, delta * FOV_LERP)

	if is_combat_mode and camera:
		var look_dir = -camera.global_transform.basis.z
		look_dir.y = 0
		model.rotation.y = lerp_angle(model.rotation.y, atan2(look_dir.x, look_dir.z) + ROTATION_FIX, delta * 20)
	elif dir.length() > 0.1 and not is_attacking:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z) + ROTATION_FIX, delta * 10)

	var target_vel = Vector3.ZERO
	
	if not is_attacking:
		if dir.length() > 0.1:
			target_vel = dir * speed
			_play_smart_animation("run" if sprinting else "walk")
		else:
			_play_smart_animation("idle1")
	else:
		target_vel = velocity * 0.8
	
	velocity.x = lerp(velocity.x, target_vel.x, delta * ACCEL)
	velocity.z = lerp(velocity.z, target_vel.z, delta * ACCEL)

# --- [ МАГИЧЕСКАЯ ЛОГИКА ] ---

func spawn_fire_ball() -> void:
	if not is_multiplayer_authority(): return
	
	var cam = get_viewport().get_camera_3d()
	var dir = -cam.global_transform.basis.z if cam else -model.global_transform.basis.z
	
	server_spawn_arrow.rpc(fire_point.global_position, dir)

@rpc("any_peer", "call_local", "reliable")
func server_spawn_arrow(pos: Vector3, dir: Vector3) -> void:
	if not multiplayer.is_server(): return
		
	if fire_arrow_scene:
		var arrow = fire_arrow_scene.instantiate()
		arrow.shooter = self 
		arrow.set_multiplayer_authority(1) 
		
		get_parent().add_child(arrow, true)
		arrow.global_position = pos
		arrow.look_at(pos + dir)

# --- [ СИСТЕМА УРОНА ] ---

func take_damage(amount: int) -> void:
	_apply_damage.rpc_id(get_multiplayer_authority(), amount)

@rpc("any_peer", "call_local", "reliable")
func _apply_damage(amount: int) -> void:
	if not is_multiplayer_authority() or is_dead: return
	
	self.health -= amount
	_trigger_hit_vfx.rpc()

@rpc("any_peer", "call_local", "reliable")
func _trigger_hit_vfx() -> void:
	if anim_player.has_animation("impact"):
		is_attacking = true 
		_play_animation("impact")

func _die() -> void:
	is_dead = true
	is_attacking = false
	set_physics_process(false)
	_play_animation("Death")

# --- [ СИСТЕМА АНИМАЦИЙ ] ---

func _play_smart_animation(base_name: String) -> void:
	var final_name = base_name
	if is_combat_mode:
		var combat_anim = "stc-idle" if base_name == "idle1" else "stc-" + base_name
		if anim_player.has_animation(combat_anim):
			final_name = combat_anim
	_play_animation(final_name)

func _play_animation(anim_name: String) -> void:
	if not anim_player.has_animation(anim_name): return
	if is_dead and anim_name != "Death": return
	if current_anim != anim_name:
		anim_player.play(anim_name, 0.2)
		current_anim = anim_name

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Death":
		anim_player.pause()
		return
	if anim_name in ["attack", "impact"]:
		is_attacking = false
		anim_player.speed_scale = 1.0

# --- [ СЕТЕВАЯ КОРРЕКЦИЯ ] ---

@rpc("any_peer", "call_local", "reliable")
func force_teleport(new_pos: Vector3):
	global_position = new_pos
	velocity = Vector3.ZERO
