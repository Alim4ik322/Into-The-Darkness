extends CharacterBody3D

class_name WarriorPlayer

const MOVE_SPEED: float = 8.0
const GRAVITY: float = 30.0
const MUSIC_TOGGLE_KEY: int = KEY_M

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

	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
		if anim_player: anim_player.play("walk")
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0, MOVE_SPEED)
		if anim_player: anim_player.play("Idle")
	
	move_and_slide()
