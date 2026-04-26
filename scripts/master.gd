extends CharacterBody3D

enum State { DIALOGUE, IDLE, CHASE, ATTACK, STUNNED, DEAD, WALK_TO_OBJECT, BLOCK }

const SPEED = 4.0
const ATTACK_RANGE = 2.8
const GRAVITY = 30.0
const ROTATION_SPEED = 10.0 

@export var model_rotation_offset: float = -90.0 
@export var attack_dash_speed: float = 5.0 

var home_pos: Vector3 = Vector3(0.299, 3.116, 30.861)
var lever_pos: Vector3 = Vector3(2.5, 3.116, 23.5)
var current_move_target: Vector3
var is_returning_home: bool = false
var is_battle_started: bool = false
var is_transitioning_to_battle: bool = false
var current_state: State = State.IDLE
var sync_attack_name: String = ""
var is_first_attack_after_block: bool = false

var health: int = 200:
	set(v):
		health = clamp(v, 0, 200)
		if hp_bar: hp_bar.value = health
		
@onready var model: Node3D = $Boss
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var sfx_sword: AudioStreamPlayer3D = $Boss/boss/Skeleton3D/Sword_Hand/Sword/SfxSword
@onready var sfx_impact: AudioStreamPlayer3D = $Boss/boss/Skeleton3D/BoneAttachment3D/StaticBody3D/CollisionShape3D/SfxImpact

var hp_bar = null
var subtitle_label = null
var sword_node: Node3D = null
var target: CharacterBody3D = null
var is_dead: bool = false

func _ready():
	hp_bar = get_node_or_null("/root/World/CanvasLayer/Control/HPBarMaster")
	subtitle_label = get_node_or_null("/root/World/CanvasLayer/Control/BossSubtitle")
	sword_node = find_child("Sword", true, false)
	if sword_node: sword_node.visible = false
	if anim: anim.animation_finished.connect(_on_anim_finished)
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		get_tree().create_timer(0.1).timeout.connect(go_to_lever)

func hit_event():
	if multiplayer.multiplayer_peer == null: return
	if not multiplayer.is_server() or is_dead: return
	_deal_damage()

func _deal_damage():
	if is_instance_valid(target) and target.has_method("take_damage"):
		if global_position.distance_to(target.global_position) <= ATTACK_RANGE + 1.5:
			target.take_damage(15)

@rpc("any_peer", "call_local")
func go_to_lever():
	is_returning_home = false
	current_move_target = lever_pos
	current_state = State.WALK_TO_OBJECT

func _move_to_coordinate(dest: Vector3, delta: float):
	nav_agent.target_position = dest
	if nav_agent.is_navigation_finished(): return
	var next_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	dir.y = 0
	velocity.x = dir.x * (SPEED * 0.7)
	velocity.z = dir.z * (SPEED * 0.7)
	_smooth_look_at(next_pos, delta)

@rpc("any_peer", "call_local")
func start_opening_speech():
	current_state = State.DIALOGUE
	_play_anim("talk1")
	if multiplayer.is_server(): get_tree().create_timer(5.0).timeout.connect(_start_tutorial)

@rpc("any_peer", "call_local")
func _start_tutorial():
	if is_battle_started or is_dead: return
	current_state = State.DIALOGUE
	_play_anim("talk2")
	_show_message.rpc("Приготовься к уроку! Возьми оружие.")

@rpc("any_peer", "call_local", "reliable")
func _enable_battle_mode():
	if is_battle_started or is_transitioning_to_battle: return
	is_transitioning_to_battle = true
	current_state = State.DIALOGUE
	_play_anim("talk1")
	if multiplayer.is_server(): _show_message.rpc("Ну что ж, начнем обучение!")

@rpc("call_local", "reliable")
func _start_actual_combat():
	is_battle_started = true
	is_transitioning_to_battle = false
	if hp_bar: hp_bar.show()
	current_state = State.IDLE
	_set_sword_visibility(true)

@rpc("any_peer", "call_local", "reliable")
func _end_battle_victory():
	is_battle_started = false
	is_transitioning_to_battle = false
	current_state = State.DIALOGUE
	_play_anim("talk2")
	_set_sword_visibility(false)
	if hp_bar: hp_bar.hide()

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null: return
	if is_dead: return
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	if multiplayer.is_server():
		_process_server_logic(delta)
		move_and_slide()
	_handle_animations()

func _process_server_logic(delta):
	if is_battle_started:
		_smart_target_selection()
		if target == null:
			_end_battle_victory.rpc()
			return
		if current_state == State.ATTACK: _handle_attack_dash()
		elif current_state == State.STUNNED:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
		else:
			var dist = global_position.distance_to(target.global_position)
			if dist <= ATTACK_RANGE: _start_attack()
			else: _move_to_target(delta)
		return
	if current_state == State.WALK_TO_OBJECT:
		_move_to_coordinate(current_move_target, delta)
		if global_position.distance_to(current_move_target) < 0.8:
			if not is_returning_home:
				velocity = Vector3.ZERO
				current_state = State.DIALOGUE
				_play_anim.rpc("talk1")
				var world = get_tree().current_scene
				if world.has_method("_open_gate"): world._open_gate.rpc() 
				get_tree().create_timer(2.0).timeout.connect(func():
					is_returning_home = true
					current_move_target = home_pos
					current_state = State.WALK_TO_OBJECT
				)
			else:
				current_state = State.IDLE
				velocity = Vector3.ZERO
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		_find_target()
		if target: _smooth_look_at(target.global_position, delta)

@rpc("any_peer", "call_local")
func _play_anim(anim_name: String):
	if anim and anim.has_animation(anim_name):
		# Если мы в блоке и анимация "block" уже стоит (даже на паузе) — не перезапускаем
		if current_state == State.BLOCK and anim.current_animation == "block":
			return
			
		if anim.current_animation != anim_name:
			anim.play(anim_name, 0.2)


func _handle_animations():
	if is_dead:
		if anim.current_animation != "dying": anim.play("dying")
		return
	match current_state:
		State.WALK_TO_OBJECT: _play_anim("walk")
		State.IDLE:
			if is_battle_started or is_transitioning_to_battle: _play_anim("idle-with-sword")
			else: _play_anim("idle")
		State.CHASE: _play_anim("run-with-sword")
		State.STUNNED: _play_anim("impact")
		State.ATTACK:
			if sync_attack_name != "": _play_anim(sync_attack_name)

func _on_anim_finished(anim_name: String):
	if anim_name == "block":
		anim.pause()
		return
	if anim_name.begins_with("attack"):
		sync_attack_name = ""
	if not multiplayer.is_server() or is_dead: return
	if anim_name == "talk1" and is_transitioning_to_battle:
		_set_sword_visibility.rpc(true)
		current_state = State.IDLE 
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_transitioning_to_battle and not is_battle_started: _enter_block_mode.rpc()
		)
	if anim_name.begins_with("attack") or anim_name == "impact" or anim_name.begins_with("talk"):
		if current_state != State.WALK_TO_OBJECT: current_state = State.IDLE

@rpc("call_local", "reliable")
func _enter_block_mode():
	current_state = State.BLOCK
	# Запускаем анимацию напрямую ОДИН РАЗ
	if anim and anim.has_animation("block"):
		anim.play("block", 0.2)
		anim.get_animation("block").loop_mode = Animation.LOOP_NONE



@rpc("call_local", "reliable")
func _set_attack_anim(a_name: String):
	sync_attack_name = a_name
	current_state = State.ATTACK

@rpc("any_peer", "call_local", "reliable")
func _set_sword_visibility(is_visible: bool):
	if not sword_node: sword_node = find_child("Sword", true, false)
	if sword_node: 
		sword_node.visible = is_visible
		var sound_path = "res://sound/Sword/Sword Unsheath.wav" if is_visible else "res://sound/Sword/Sword Sheath.wav"
		sfx_sword.stream = load(sound_path)
		sfx_sword.play()

@rpc("any_peer", "call_local")
func _show_message(txt: String):
	if subtitle_label: subtitle_label.text = txt

func take_damage(amount: int):
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server(): return
	if current_state == State.BLOCK:
		is_first_attack_after_block = true
		sfx_impact.stream = load("res://sound/Sword/Sword Blocked.wav")
		sfx_impact.play()
		_start_actual_combat.rpc()
		return
	if not is_battle_started: _start_actual_combat.rpc()
	health -= amount
	if health <= 0: _die()
	else:
		current_state = State.STUNNED
		_play_anim.rpc("impact")
		sfx_impact.stream = load("res://sound/Sword/Sword Impact Hit.wav")
		sfx_impact.play()

func _die():
	if is_dead: return
	_kill_boss_instantly.rpc()
	is_dead = true
	current_state = State.DEAD
	$CollisionShape3D.set_deferred("disabled", true)
	_play_anim.rpc("dying")

@rpc("call_local", "reliable")
func _kill_boss_instantly():
	is_dead = true
	current_state = State.DEAD
	$CollisionShape3D.set_deferred("disabled", true)
	if anim:
		anim.play("dying")
		var death_anim_length = anim.get_animation("dying").length
		get_tree().create_timer(death_anim_length - 0.1).timeout.connect(func():
			anim.stop(true)
			set_physics_process(false)
			set_process(false)
		)

func _start_attack():
	if current_state == State.ATTACK: return
	sfx_sword.stream = load("res://sound/Sword/Sword Attack.wav")
	sfx_sword.play()
	if is_instance_valid(target):
		var look_dir = target.global_position - global_position
		look_dir.y = 0
		rotation.y = atan2(look_dir.x, look_dir.z) + deg_to_rad(model_rotation_offset)
	velocity = Vector3.ZERO
	
	var a_name = "attack1"
	if is_first_attack_after_block:
		a_name = "attack3"
		is_first_attack_after_block = false
	else:
		var dist = global_position.distance_to(target.global_position)
		a_name = "attack1" if dist < 1.8 else "attack2"
	
	_set_attack_anim.rpc(a_name)

func _smart_target_selection():
	var players = get_tree().get_nodes_in_group("Player")
	var potential_target = null
	var min_dist = INF
	for p in players:
		if is_instance_valid(p) and p.get("health") != null and p.health > 0:
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				potential_target = p
	target = potential_target

func _move_to_target(delta):
	current_state = State.CHASE
	nav_agent.target_position = target.global_position
	var next_pos = nav_agent.get_next_path_position()
	var dir = global_position.direction_to(next_pos)
	dir.y = 0
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	_smooth_look_at(next_pos, delta)

func _smooth_look_at(target_pos: Vector3, delta: float):
	var look_dir = target_pos - global_position
	look_dir.y = 0
	if look_dir.length() > 0.01:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle + deg_to_rad(model_rotation_offset), delta * ROTATION_SPEED)

func _find_target():
	_smart_target_selection()

func _handle_attack_dash():
	var time_in_anim = anim.current_animation_position
	if time_in_anim < 0.5: 
		if is_instance_valid(target):
			var dir = global_position.direction_to(target.global_position)
			dir.y = 0
			velocity.x = dir.x * attack_dash_speed
			velocity.z = dir.z * attack_dash_speed
	else:
		velocity.x = move_toward(velocity.x, 0, 1.0)
		velocity.z = move_toward(velocity.z, 0, 1.0)
