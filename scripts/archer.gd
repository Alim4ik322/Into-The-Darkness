extends CharacterBody3D

class_name ArcherPlayer

const MOVE_SPEED: float = 8.0 # Лучник чуть быстрее воина по стандарту
const GRAVITY: float = 30.0

# Константы анимаций (проверь названия в своем AnimationPlayer)
const ANIM_IDLE: String = "Idle"
const ANIM_WALK: String = "Walk"

@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true)
@onready var camera: Camera3D = find_child("Camera3D", true)
@onready var ui = find_child("UI", true)
@onready var model = $Archer_model

# Бары и показатели
var health: int = 100
var stamina: float = 100.0
var hunger: float = 100.0
var stirst: float = 100.0
var current_animation: String = ""

@onready var hp_bar = find_child("HPProgressBar", true) as Range
@onready var st_bar = find_child("StaminaProgressBar", true) as Range
@onready var hu_bar = find_child("HungryProgressBar", true) as Range
@onready var wa_bar = find_child("WaterProgressBar", true) as Range

# ТОТ САМЫЙ RPC, который мы настроили ("any_peer" важен!)
@rpc("any_peer", "call_local", "reliable")
func force_teleport(new_pos: Vector3):
	global_position = new_pos
	velocity = Vector3.ZERO
	print("[ARCHER] Teleport success to: ", new_pos)

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		if camera: camera.current = false
		if ui: ui.hide()
		return
	
	if camera: camera.make_current()
	if ui: ui.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta):
	if is_multiplayer_authority():
		if hp_bar: hp_bar.value = health
		if st_bar: st_bar.value = stamina
		if hu_bar: hu_bar.value = hunger
		if wa_bar: wa_bar.value = stirst

func _play_animation(anim_name: String) -> void:
	if anim_player and current_animation != anim_name:
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
			current_animation = anim_name

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Защита от падения (как у воина)
	if global_position.y < -50:
		global_position = Vector3(0, 5, 0)
		velocity = Vector3.ZERO

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir = Input.get_vector("right", "left", "down", "up")
	
	# Движение относительно камеры (как мы фиксили у воина)
	var direction = Vector3.ZERO
	if camera:
		var forward = -camera.global_transform.basis.z
		forward.y = 0
		var right = camera.global_transform.basis.x
		right.y = 0
		direction = (forward * input_dir.y - right * input_dir.x).normalized()
	
	if direction.length() > 0.001:
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
		_play_animation(ANIM_WALK)
		
		if model:
			var target_rot = atan2(direction.x, direction.z)
			model.rotation.y = lerp_angle(model.rotation.y, target_rot, delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0, MOVE_SPEED)
		_play_animation(ANIM_IDLE)

	move_and_slide()
