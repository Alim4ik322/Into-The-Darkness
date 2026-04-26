extends CharacterBody3D

class_name WarriorPlayer

# --- [ КОНСТАНТЫ И НАСТРОЙКИ ] ---
@export_group("Movement")
const MOVE_SPEED: float = 6.0
const RUN_SPEED: float  = 9.0
const GRAVITY: float    = 30.0
const ACCEL: float      = 10.0 

@export_group("Rotation Speed")
const ROT_COMBAT: float = 20.0 
const ROT_FREE: float   = 15.0 

@export_group("Camera Settings")
const FOV_IDLE: float = 75.0
const FOV_RUN: float  = 85.0
const FOV_LERP: float = 5.0

# --- [ УЗЛЫ ] ---
@onready var anim_player: AnimationPlayer = $Warrior_final/AnimationPlayer
@onready var model: Node3D = $Warrior_final
@onready var camera: Camera3D = find_child("Camera3D", true) as Camera3D
@onready var ui: CanvasLayer = $UI 
@onready var attack_ray: ShapeCast3D = $Warrior_final/Warrior/AttackRay

@onready var sword: BoneAttachment3D = find_child("Sword", true)
@onready var shield: BoneAttachment3D = find_child("Shield", true)

@onready var hp_bar = $UI/HPProgressBar
@onready var mp_bar = $UI/MPProgressBar
@onready var st_bar = $UI/StaminaProgressBar
@onready var hu_bar = $UI/HungryProgressBar
@onready var wa_bar = $UI/WaterProgressBar

@onready var sfx_impact: AudioStreamPlayer3D = $SfxImpact
@onready var sfx_sword: AudioStreamPlayer3D = $Warrior_final/Warrior/Skeleton3D/Sword/SfxSword


# --- [ ПЕРЕМЕННЫЕ СОСТОЯНИЯ ] ---
var is_dead: bool      = false
var is_attacking: bool = false
var is_blocking: bool  = false
var is_reacting: bool  = false 
var current_anim: String = ""
var has_weapons: bool = false # По умолчанию оружия нет

var health: int = 100:
	set(v):
		health = clamp(v, 0, 100)
		if hp_bar:
			hp_bar.value = health
		if health <= 0 and not is_dead: 
			_die()

var stamina: float = 100.0:
	set(v):
		stamina = clamp(v, 0.0, 100.0)
		if st_bar:
			st_bar.value = stamina

var mana: float    = 50.0
var hunger: float  = 100.0
var stirst: float  = 100.0

var is_combat_mode: bool = false: 
	set(v):
		is_combat_mode = v
		if not is_combat_mode: is_blocking = false
		_update_equipment_visuals()

# --- [ СИСТЕМНЫЕ ФУНКЦИИ ] ---

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if multiplayer.multiplayer_peer == null:
		set_physics_process(false)
		return
		
	if not is_multiplayer_authority():
		if camera: camera.current = false
		# Удаляем чужой UI, чтобы он не перекрывал экран хосту
		if ui: 
			ui.queue_free() 
		return

	# Ниже код только для владельца персонажа
	if has_node("UI/HP"):
		$UI/HP.play("default")

	if camera: camera.make_current()
	if ui: 
		ui.show()
		ui.layer = 10 # Твой UI всегда сверху
		if hp_bar: hp_bar.value = health
		
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if attack_ray:
		attack_ray.add_exception(self)
	
	_update_equipment_visuals()
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

# --- [ ОБРАБОТКА ВВОДА ] ---

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead: return
	
	if event.is_action_pressed("R") and has_weapons:
		is_combat_mode = !is_combat_mode

	# Добавлена проверка stamina >= 10.0
	if event.is_action_pressed("attack") and _can_act() and stamina >= 10.0:
		if is_combat_mode:
			_execute_attack("Sword_Attack_Slash", 1.4, 15.0) # 15 - цена удара мечом
		else:
			_execute_attack("Punch", 1.2, 5.0) # 5 - цена удара кулаком

	if event.is_action_pressed("F") and is_combat_mode and _can_act() and stamina >= 15.0:
		_execute_attack("Kick", 1.3, 12.0) # 12 - цена удара ногой

	if is_combat_mode and not is_attacking and not is_reacting:
		is_blocking = Input.is_action_pressed("block")

func pickup_weapons() -> void:
	if not is_multiplayer_authority(): return
	
	has_weapons = true
	is_combat_mode = true
	
	var world = get_tree().root.find_child("World", true, false)
	if world:
		world.swap_to_battle_labels.rpc()
		
		var master_node = world.get_node_or_null("Master")
		# Проверяем, что мастер существует, прежде чем дергать его
		if is_instance_valid(master_node) and master_node.has_method("_enable_battle_mode"):
			master_node._enable_battle_mode.rpc()
	sfx_sword.stream = load("res://sound/Sword/Sword Unsheath.wav")
	sfx_sword.play()
	
@rpc("any_peer", "call_local", "reliable")
func _on_weapon_picked_up():
	# Ищем скрипт World, чтобы вызвать там смену UI
	var world = get_tree().root.find_child("World", true, false)
	if world and world.has_method("_sync_ui_element"):
		world._sync_ui_element.rpc("label2", false) # Прячем "Возьми меч"
		world._sync_ui_element.rpc("label3", true)  # Показываем "Нападай!"
		
		# Можно сделать, чтобы Label3 исчезла сама через 5 секунд
		get_tree().create_timer(5.0).timeout.connect(func():
			world._sync_ui_element.rpc("label3", false)
		)
func _can_act() -> bool:
	return not is_attacking and not is_blocking and not is_reacting

# --- [ ЛОГИКА ОБНОВЛЕНИЯ ] ---

func _process(delta: float) -> void:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null: return
	if not is_multiplayer_authority(): return
	if not is_attacking:
		stamina += delta * 5.0
	mana = min(mana + delta * 3.0, 100.0)
	if mp_bar: mp_bar.value = mana
	if st_bar: st_bar.value = stamina
	if hu_bar: hu_bar.value = hunger
	if wa_bar: wa_bar.value = stirst
	
	# Подстраховка для UI
	if hp_bar and hp_bar.value != health:
		hp_bar.value = health
	
	if (is_attacking or is_reacting) and not anim_player.is_playing():
		is_attacking = false
		is_reacting = false

func _physics_process(delta: float) -> void:
	if is_dead:
		_play_animation("Death")
		return
		
	if not is_multiplayer_authority() or is_dead: return
	
	_apply_gravity(delta)
	
	var input_dir = Input.get_vector("right", "left", "down", "up")
	var direction = _get_camera_oriented_direction(input_dir)
	
	_handle_movement_logic(direction, delta)
	move_and_slide()

# --- [ ПЕРЕДВИЖЕНИЕ И ПОВОРОТЫ ] ---

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _get_camera_oriented_direction(input: Vector2) -> Vector3:
	if not camera or is_attacking or is_reacting: return Vector3.ZERO
	
	var forward = -camera.global_transform.basis.z
	var right   = camera.global_transform.basis.x
	forward.y = 0; right.y = 0
	
	return (forward * input.y - right * input.x).normalized()

func _handle_movement_logic(dir: Vector3, delta: float) -> void:
	var sprinting = Input.is_action_pressed("Shift") and dir.length() > 0.1 and not is_blocking
	var speed = RUN_SPEED if sprinting else (MOVE_SPEED * (0.4 if is_blocking else 1.0))
	
	if camera:
		camera.fov = lerp(camera.fov, FOV_RUN if sprinting else FOV_IDLE, delta * FOV_LERP)

	if is_combat_mode:
		var look_dir = -camera.global_transform.basis.z
		look_dir.y = 0
		model.rotation.y = lerp_angle(model.rotation.y, atan2(look_dir.x, look_dir.z), delta * ROT_COMBAT)
	elif dir.length() > 0.1 and not is_attacking:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), delta * ROT_FREE)

	var target_vel = Vector3.ZERO
	
	if not is_attacking and not is_reacting:
		if is_blocking:
			_play_animation("Block_Sword_and_Shield")
		elif dir.length() > 0.1:
			target_vel = dir * speed
			_play_smart_animation("Run" if sprinting else "Walk")
		else:
			_play_smart_animation("Idle")
	
	velocity.x = lerp(velocity.x, target_vel.x, delta * ACCEL)
	velocity.z = lerp(velocity.z, target_vel.z, delta * ACCEL)

# --- [ БОЕВАЯ СИСТЕМА ] ---

func _animation_hit_moment():
	if not is_multiplayer_authority() or is_dead: return
	
	var damage = 15
	if current_anim == "Punch": damage = 5
	if current_anim == "Kick": damage = 10
	
	_request_server_hit.rpc_id(1, damage)

func _execute_attack(anim_name: String, speed: float, stamina_cost: float = 0.0) -> void:
	sfx_sword.stream = load("res://sound/Sword/Sword Attack.wav")
	sfx_sword.play()
	is_attacking = true
	stamina -= stamina_cost # Трата выносливости
	anim_player.speed_scale = speed
	_play_animation(anim_name)

@rpc("any_peer", "call_local", "reliable")
func _request_server_hit(dmg: int):
	if not multiplayer.is_server(): return
	
	attack_ray.force_shapecast_update()
	
	if attack_ray.get_collision_count() > 0:
		var collider = attack_ray.get_collider(0) 
		var current_node = collider
		while current_node != null:
			if current_node.has_method("take_damage"):
				current_node.take_damage(dmg)
				return 
			current_node = current_node.get_parent()

func _update_equipment_visuals() -> void:
	if sword: sword.visible = is_combat_mode and has_weapons
	if shield: shield.visible = is_combat_mode and has_weapons

# --- [ СИСТЕМА УРОНА И RPC ] ---

func take_damage(amount: int) -> void:
	_apply_damage.rpc_id(get_multiplayer_authority(), amount)

@rpc("any_peer", "call_local", "reliable")
func _apply_damage(amount: int) -> void:
	if not is_multiplayer_authority() or is_dead: return
	
	var final_dmg = int(amount * 0.2) if is_blocking else amount
	_trigger_hit_vfx.rpc("block" if is_blocking else "damage")
	
	self.health -= final_dmg
	if is_blocking:
		sfx_impact.stream = load("res://sound/Sword/Sword Blocked.wav")
	else:
		sfx_impact.stream = load("res://sound/Sword/Sword Impact Hit.wav")
	sfx_impact.play()

@rpc("any_peer", "call_local", "reliable")
func _trigger_hit_vfx(type: String) -> void:
	var anim = "Impact" if type == "damage" else "Block_Impact"
	if not anim_player.has_animation(anim): anim = "Hit_Reaction"
	
	is_reacting = true
	is_attacking = false
	_play_animation(anim)

func _die() -> void:
	_sync_death.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_death():
	is_dead = true
	is_attacking = false
	is_reacting = false
	_play_animation("Death")

# --- [ АНИМАЦИИ ] ---

func _play_smart_animation(base_name: String) -> void:
	var anim = base_name
	if is_combat_mode and base_name in ["Idle", "Walk", "Run"]:
		var combat_anim = base_name + "_Sword_and_Shield"
		if anim_player.has_animation(combat_anim): anim = combat_anim
	_play_animation(anim)

func _play_animation(anim_name: String) -> void:
	if is_dead and anim_name != "Death": return 
	if current_anim != anim_name:
		anim_player.play(anim_name, 0.2)
		current_anim = anim_name

func _on_animation_finished(anim_name: String) -> void:
	if anim_name in ["Sword_Attack_Slash", "Punch", "Kick", "Hit_Reaction", "Impact", "Block_Impact"]:
		is_attacking = false
		is_reacting = false
		anim_player.speed_scale = 1.0

@rpc("any_peer", "call_local", "reliable")
func force_teleport(new_pos: Vector3):
	global_position = new_pos
	velocity = Vector3.ZERO
