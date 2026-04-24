extends CharacterBody3D

class_name WarriorPlayer

const MOVE_SPEED: float = 8.0
const GRAVITY: float = 30.0
const MUSIC_TOGGLE_KEY: int = KEY_M

@onready var anim_player: AnimationPlayer? = find_child("AnimationPlayer", true) as AnimationPlayer?
@onready var camera: Camera3D? = find_child("Camera3D", true) as Camera3D?
@onready var ui: Control? = find_child("UI", true) as Control?
@onready var hp_bar: Range? = find_child("HPProgressBar", true) as Range?
@onready var st_bar: Range? = find_child("StaminaProgressBar", true) as Range?
@onready var hu_bar: Range? = find_child("HungryProgressBar", true) as Range?
@onready var wa_bar: Range? = find_child("WaterProgressBar", true) as Range?
@onready var model: Node3D? = get_node_or_null("wariror/Воин") as Node3D?

var is_playing_music: bool = false
var health: int = 100
var stamina: float = 100.0
var hunger: float = 100.0
var stirst: float = 100.0

func _input(event: InputEvent) -> void:
	if not _has_active_multiplayer():
		return
	if not is_multiplayer_authority():
		return
	if event is InputEventKey and event.pressed and event.keycode == MUSIC_TOGGLE_KEY:
		is_playing_music = !is_playing_music
		print("Музыкальный режим: ", is_playing_music)

func _has_active_multiplayer() -> bool:
	if not multiplayer:
		return false
	return multiplayer.has_multiplayer_peer()

func _is_local_authority() -> bool:
	return _has_active_multiplayer() and is_multiplayer_authority()

func _process(_delta: float) -> void:
	if not _has_active_multiplayer():
		return
	if is_multiplayer_authority():
		if hp_bar: hp_bar.value = health
		if st_bar: st_bar.value = stamina
		if hu_bar: hu_bar.value = hunger
		if wa_bar: wa_bar.value = stirst

func _enter_tree() -> void:
	# Важно: устанавливаем власть ПЕРЕД тем как узел появится у всех на экранах
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if not _has_active_multiplayer():
		return
	if not is_multiplayer_authority():
		if camera: camera.current = false
		ui?.hide()
		set_physics_process(false)
		set_process_input(false)
		return
	camera?.make_current()
	ui?.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not _is_local_authority():
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
		anim_player?.play("walk")
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0, MOVE_SPEED)
		anim_player?.play("Idle")
	move_and_slide()
	if _has_active_multiplayer():
		multiplayer.rpc_unreliable("sync_state", global_transform, velocity)

@rpc("any_peer")
func sync_state(sync_transform: Transform3D, sync_velocity: Vector3) -> void:
	if is_multiplayer_authority():
		return
	global_transform = sync_transform
	velocity = sync_velocity
