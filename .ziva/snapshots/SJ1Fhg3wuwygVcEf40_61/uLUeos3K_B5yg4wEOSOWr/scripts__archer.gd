extends CharacterBody3D

@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true)
@onready var camera: Camera3D = find_child("Camera3D", true)

var is_playing_music: bool = false
var is_crouching: bool = false
var health: int = 100
var stamina: float = 100.0
var hunger: float = 100.0
var stirst: float = 100.0

@onready var hp_bar = find_child("HPProgressBar", true)
@onready var st_bar = find_child("StaminaProgressBar", true)
@onready var hu_bar = find_child("HungryProgressBar", true)
@onready var wa_bar = find_child("WaterProgressBar", true)

func _input(event):
	if not multiplayer.has_multiplayer_peer(): return
	if is_multiplayer_authority() and event is InputEventKey and event.pressed and event.keycode == KEY_M:
		is_playing_music = !is_playing_music
		print("Музыкальный режим: ", is_playing_music)

func _process(_delta):
	if not multiplayer.has_multiplayer_peer(): return
	if is_multiplayer_authority():
		if hp_bar: hp_bar.value = health
		if st_bar: st_bar.value = stamina
		if hu_bar: hu_bar.value = hunger
		if wa_bar: wa_bar.value = stirst
@onready var ui = find_child("UI", true)
@onready var model = $Archer_model

func _enter_tree():
	# Устанавливаем authority в самом начале жизни узла
	set_multiplayer_authority(name.to_int())

func _ready():
	# Безопасная проверка сети
	if not multiplayer.has_multiplayer_peer():
		return

	if not is_multiplayer_authority():
		if camera: camera.current = false
		if ui: ui.hide()
		set_physics_process(false)
		set_process_input(false)
		return
	
	if camera: camera.make_current()
	if ui: ui.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not multiplayer.has_multiplayer_peer(): return
	if not is_multiplayer_authority(): return
	
	if not is_on_floor():
		velocity.y -= 30.0 * delta

	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * 8.0
		velocity.z = direction.z * 8.0
		if anim_player: anim_player.play("walk")
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, 8.0)
		velocity.z = move_toward(velocity.z, 0, 8.0)
		if anim_player: anim_player.play("idle")

	move_and_slide()
	# Отправляем движение на всех клиентов, чтобы видели, как движется персонаж
	rpc_unreliable("sync_state", global_transform, velocity)

@rpc("any_peer")
func sync_state(sync_transform: Transform3D, sync_velocity: Vector3):
	if is_multiplayer_authority():
		return
	global_transform = sync_transform
	velocity = sync_velocity
