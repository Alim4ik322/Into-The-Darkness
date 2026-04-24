extends CharacterBody3D

@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true)
@onready var camera: Camera3D = find_child("Camera3D", true)
@onready var ui = find_child("UI", true)
@onready var model = get_node_or_null("wariror/Воин")

func _enter_tree():
	# Важно: устанавливаем власть ПЕРЕД тем как узел появится у всех на экранах
	set_multiplayer_authority(name.to_int())

func _ready():
	# Проверяем, наш ли это персонаж
	if not is_multiplayer_authority():
		# ДЛЯ ЧУЖОГО: выключаем камеру и управление
		if camera: camera.current = false
		if ui: ui.hide()
		set_physics_process(false)
		set_process_input(false)
		return
	
	# ДЛЯ НАШЕГО: включаем камеру и UI
	if camera: camera.make_current()
	if ui: ui.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= 30.0 * delta

	# Твое управление
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
		if anim_player: anim_player.play("Idle")

	move_and_slide()
