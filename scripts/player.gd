extends CharacterBody3D

const WALK_SPEED: float = 10.0
const RUN_SPEED: float = 15.0
var SPEED: float = WALK_SPEED
const GRAVITY: float = 30.0
const JUMP_VELOCITY: float = 12.0

var is_paused: bool = false
var is_running: bool = false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_3d: Camera3D = $CameraPivot/CameraVerticalPivot/CameraZoomPivot/Camera3D
@onready var animation_player: AnimationPlayer = $LowPolySaxonSoldier/AnimationPlayer
@onready var mp_bar: TextureProgressBar = $UI/MPProgressBar
@onready var stamina_bar: TextureProgressBar = $UI/StaminaProgressBar
@onready var hungry_progress_bar: TextureProgressBar = $UI/HungryProgressBar
@onready var water_progress_bar: TextureProgressBar = $UI/WaterProgressBar
@onready var hp: AnimatedSprite2D = $UI/HP

@onready var model: Node3D = $LowPolySaxonSoldier

func _ready() -> void:
	hp.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	

func _physics_process(delta: float) -> void:
	if is_paused:
		return
	hungry_progress_bar.value -= 1 * delta
	water_progress_bar.value -= 0.5 * delta
	var input_dir := Input.get_vector("right", "left", "down", "up")
	var cam_basis := camera_pivot.global_transform.basis
	var move_dir := (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	# Проверяем, удерживается ли Shift и есть ли стамина
	is_running = Input.is_action_pressed("Shift") and stamina_bar.value > 0 and move_dir != Vector3.ZERO

	# Скорость и стамина
	if is_running:
		SPEED = RUN_SPEED
		stamina_bar.value = max(0, stamina_bar.value - 20 * delta)
	else:
		SPEED = WALK_SPEED
		stamina_bar.value = min(100, stamina_bar.value + 10 * delta)

	# Движение
	if move_dir != Vector3.ZERO:
		velocity.x = move_dir.x * SPEED
		velocity.z = move_dir.z * SPEED

		var target_yaw := atan2(move_dir.x, move_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, delta * 10.0)

		# Анимация ходьбы / бега: воспроизводим walk, меняем speed_scale
		if animation_player.current_animation != "Armature|Walk":
			animation_player.play("Armature|Walk")

		animation_player.speed_scale = 4.0 if is_running else 2.0  # при беге в 2 раза быстрее

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if animation_player.current_animation != "Armature|Idle":
			animation_player.speed_scale = 1.0
			animation_player.play("Armature|Idle")

	# Гравитация
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	# Прыжок
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	# Восстановление маны
	if mp_bar.value < 100:
		mp_bar.value = min(100, mp_bar.value + 0.1)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		if is_paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_paused = true
	$UI/Pause_menu.show()

func resume_game() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_paused = false
	$UI/Pause_menu.hide()


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_resume_button_pressed() -> void:
	resume_game()
