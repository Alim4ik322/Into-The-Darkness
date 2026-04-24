extends CharacterBody3D

class_name WarriorPlayer

const MOVE_SPEED: float = 6
const RUN_SPEED: float = 9
const CROUCH_SPEED: float = 3.5
const GRAVITY: float = 30.0
const MUSIC_TOGGLE_KEY: int = KEY_M
const ANIM_IDLE: String = "Idle"
const ANIM_WALK: String = "walk"
const ANIM_RUN: String = "Run"
const ANIM_CROUCH_IDLE: String = "Crouch idle"
const ANIM_CROUCH_WALK: String = "Crouch walk"

@onready var anim_player = find_child("AnimationPlayer", true) as AnimationPlayer
@onready var camera = find_child("Camera3D", true) as Camera3D
@onready var ui = find_child("UI", true) as Control
@onready var hp_bar = find_child("HPProgressBar", true) as Range
@onready var st_bar = find_child("StaminaProgressBar", true) as Range
@onready var hu_bar = find_child("HungryProgressBar", true) as Range
@onready var wa_bar = find_child("WaterProgressBar", true) as Range
@onready var model = get_node_or_null("wariror/Воин") as Node3D

var is_playing_music: bool = false
var health: int = 100
var stamina: float = 100.0
var hunger: float = 100.0
var stirst: float = 100.0
var is_crouching: bool = false

func _enter_tree() -> void:
	# Устанавливаем authority
	set_multiplayer_authority(name.to_int())
	# Если это МЫ, и мы только вошли, принудительно берем позицию из текущего места
	if is_multiplayer_authority():
		global_position = position

func _ready() -> void:
	# Если это не наш персонаж — отключаем управление и камеру
	if not is_multiplayer_authority():
		if camera: camera.current = false
		if ui: ui.hide()
		return

	# Если наш — включаем
	if camera: camera.make_current()
	if ui: ui.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event is InputEventKey and event.pressed and event.keycode == MUSIC_TOGGLE_KEY:
		is_playing_music = !is_playing_music
		print("Музыкальный режим: ", is_playing_music)

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		if hp_bar: hp_bar.value = health
		if st_bar: st_bar.value = stamina
		if hu_bar: hu_bar.value = hunger
		if wa_bar: wa_bar.value = stirst

func _physics_process(delta: float) -> void:
	# Двигаем персонажа только если мы им владеем
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if Input.is_action_just_pressed("C"):
		is_crouching = not is_crouching

	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = Vector3.ZERO

	if camera:
		var forward = -camera.global_transform.basis.z
		forward.y = 0
		if forward.length_squared() > 0:
			forward = forward.normalized()
		var right = camera.global_transform.basis.x
		right.y = 0
		if right.length_squared() > 0:
			right = right.normalized()
		direction = forward * input_dir.y - right * input_dir.x
	else:
		direction = transform.basis * Vector3(input_dir.x, 0, input_dir.y)
		direction.y = 0

	var sprinting = Input.is_action_pressed("Shift") and not is_crouching
	if direction.length_squared() > 0:
		direction = direction.normalized()
		var move_speed = MOVE_SPEED
		var animation_to_play = ANIM_WALK
		if is_crouching:
			move_speed = CROUCH_SPEED
			animation_to_play = ANIM_CROUCH_WALK
		elif sprinting:
			move_speed = RUN_SPEED
			animation_to_play = ANIM_RUN

		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		if anim_player:
			anim_player.play(animation_to_play)
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0, MOVE_SPEED)
		if anim_player:
			var idle_animation = ANIM_CROUCH_IDLE if is_crouching else ANIM_IDLE
			anim_player.play(idle_animation)

	move_and_slide()
