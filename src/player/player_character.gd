class_name PlayerCharacter
extends CharacterBody3D
## Сетевой 3D-боец от 3-го лица: движение, спринт, рывок, рукопашный бой, холодное оружие (1H/2H),
## спартанский пинок с физическим отбрасыванием, блок/парирование, захват и метание оружия/предметов.

const MAX_HP: float = 100.0
const MAX_STAMINA: float = 100.0
const WALK_SPEED: float = 6.2
const SPRINT_SPEED: float = 9.4
const CARRY_SPEED_MULT: float = 0.78
const JUMP_VELOCITY: float = 9.2
const GRAVITY: float = 24.0
const DODGE_SPEED: float = 13.8

var peer_id: int = 1
var player_name: String = "Боец"
var char_class: String = "knight"
var accent_color: Color = Color(0.20, 0.58, 0.96)

var hp: float = MAX_HP
var stamina: float = MAX_STAMINA
var is_dead: bool = false
var is_blocking: bool = false
var block_started_msec: int = 0
var equipped_weapon_id: String = ""
var carried_prop_name: String = ""

var cam_yaw: float = 0.0
var cam_pitch: float = -0.22

var _camera_pivot: Node3D = null
var _spring_arm: SpringArm3D = null
var _camera: Camera3D = null
var _visual_root: Node3D = null
var _anim_player: AnimationPlayer = null
var _hand_slot_r: Node3D = null
var _hand_slot_l: Node3D = null
var _shield_node: Node3D = null
var _equipped_visual: Node3D = null
var _nameplate: Label3D = null

var _combo_index: int = 0
var _combo_reset_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _anim_lock_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _invuln_timer: float = 0.0
var _stamina_regen_delay: float = 0.0
var _respawn_timer: float = 0.0
var _last_attacker_id: int = 0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _wallsplat_cooldown: float = 0.0
var _shake_strength: float = 0.0

var _net_target_pos: Vector3 = Vector3.ZERO
var _net_target_yaw: float = 0.0
var _net_current_anim: String = "Unarmed_Idle"
var _sync_accum: float = 0.0


func setup_from_spawn_data(data: Dictionary) -> void:
	peer_id = int(data.get("peer_id", 1))
	name = "Player_%d" % peer_id
	player_name = String(data.get("name", "Боец_%d" % peer_id))
	char_class = String(data.get("char_class", "knight"))
	accent_color = data.get("color", Color(0.25, 0.62, 0.96))
	position = data.get("pos", Vector3(0.0, 2.0, 0.0))
	cam_yaw = float(data.get("yaw", 0.0))


func get_peer_id() -> int:
	return peer_id


func is_local_player() -> bool:
	return multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.30

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.84
	col.shape = cap
	col.position = Vector3(0.0, 0.92, 0.0)
	add_child(col)

	_net_target_pos = global_position
	_net_target_yaw = cam_yaw

	_build_visual_character()
	_build_camera_rig()
	_build_nameplate()
	_refresh_equipped_visual()


func _build_visual_character() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.scale = Vector3(0.82, 0.82, 0.82)
	_visual_root.rotation.y = cam_yaw
	add_child(_visual_root)

	var model := AssetCatalog.instantiate_character_model(char_class)
	if model != null:
		model.rotation.y = PI # В glTF KayKit персонажи смотрят в +Z, поворачиваем к -Z Godot
		_visual_root.add_child(model)
		_anim_player = _find_anim_player(model)
		_setup_character_slots_and_materials(model)
		_play_local_anim("Unarmed_Idle")
	else:
		var fallback := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.38
		cm.height = 1.84
		var mat := StandardMaterial3D.new()
		mat.albedo_color = accent_color
		cm.material = mat
		fallback.mesh = cm
		fallback.position = Vector3(0.0, 0.92, 0.0)
		_visual_root.add_child(fallback)


func _setup_character_slots_and_materials(model: Node3D) -> void:
	for n in model.find_children("*", "Node3D", true, false):
		if n.name == "handslot.r":
			_hand_slot_r = n
			for ch in n.get_children():
				if ch is Node3D:
					(ch as Node3D).visible = false
		elif n.name == "handslot.l":
			_hand_slot_l = n
			for ch in n.get_children():
				if ch is Node3D:
					(ch as Node3D).visible = false
					if _shield_node == null and ("Shield" in ch.name or "Knife_Offhand" in ch.name):
						_shield_node = ch as Node3D

		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var base_mat := mi.mesh.surface_get_material(0)
				if base_mat is StandardMaterial3D:
					var dup := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.roughness = 0.48
					dup.metallic = 0.18
					if "Cape" in mi.name or "Hat" in mi.name or "Hood" in mi.name:
						dup.albedo_color = accent_color.lerp(Color.WHITE, 0.25)
					mi.material_override = dup


func _build_camera_rig() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.52, 0.0)
	_camera_pivot.rotation.y = cam_yaw
	add_child(_camera_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = 3.85
	_spring_arm.margin = 0.25
	_spring_arm.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	_spring_arm.shape = sphere
	_spring_arm.position = Vector3(0.42, 0.16, 0.0) # Лёгкое смещение через правое плечо
	_spring_arm.rotation.x = cam_pitch
	_camera_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.fov = 74.0
	_camera.near = 0.08
	_camera.far = 350.0
	_spring_arm.add_child(_camera)

	if is_local_player() and DisplayServer.get_name() != "headless":
		_camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _build_nameplate() -> void:
	if DisplayServer.get_name() == "headless" or is_local_player():
		return
	_nameplate = Label3D.new()
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.position = Vector3(0.0, 2.26, 0.0)
	_nameplate.font_size = 34
	_nameplate.outline_size = 10
	_nameplate.pixel_size = 0.0052
	add_child(_nameplate)
	_update_nameplate()


func _update_nameplate() -> void:
	if _nameplate == null:
		return
	if is_dead:
		_nameplate.text = "%s [Повержен]" % player_name
		_nameplate.modulate = Color(0.6, 0.6, 0.6)
	else:
		_nameplate.text = "%s\n♥ %d" % [player_name, ceili(hp)]
		_nameplate.modulate = accent_color.lerp(Color.WHITE, 0.40)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for ch in node.get_children():
		var found := _find_anim_player(ch)
		if found != null:
			return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player() or is_dead:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var sens := GraphicsSettings.mouse_sensitivity
		cam_yaw -= mm.relative.x * sens
		cam_pitch = clampf(cam_pitch - mm.relative.y * sens, deg_to_rad(-68.0), deg_to_rad(52.0))


func _physics_process(delta: float) -> void:
	_update_carried_prop_attachment(delta)

	if is_local_player():
		_process_local_player(delta)
	else:
		_process_remote_player(delta)

	if multiplayer.is_server():
		_process_server_authority(delta)


func _process_local_player(delta: float) -> void:
	if _camera_pivot != null:
		_camera_pivot.rotation.y = cam_yaw
		var target_len := 2.45 if is_blocking else 3.85
		var target_fov := 62.0 if is_blocking else 74.0
		_spring_arm.spring_length = lerpf(_spring_arm.spring_length, target_len, clampf(delta * 12.0, 0.0, 1.0))
		_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 12.0, 0.0, 1.0))

		if _shake_strength > 0.001:
			_shake_strength = move_toward(_shake_strength, 0.0, delta * 2.4)
			_spring_arm.rotation.x = cam_pitch + randf_range(-_shake_strength, _shake_strength)
			_spring_arm.rotation.y = randf_range(-_shake_strength, _shake_strength)
		else:
			_spring_arm.rotation.x = cam_pitch
			_spring_arm.rotation.y = 0.0

	if is_dead:
		return

	if _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			_combo_index = 0
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _anim_lock_timer > 0.0:
		_anim_lock_timer -= delta
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
	if _stamina_regen_delay > 0.0:
		_stamina_regen_delay -= delta
	elif not is_blocking:
		stamina = minf(MAX_STAMINA, stamina + 24.0 * delta)

	var ui_free := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

	# Блок / Прицеливание (ПКМ)
	var want_block := ui_free and Input.is_action_pressed("block_aim") and _dodge_timer <= 0.0 and carried_prop_name.is_empty()
	if want_block != is_blocking:
		is_blocking = want_block
		if _shield_node != null:
			_shield_node.visible = is_blocking or (not equipped_weapon_id.is_empty() and _get_equipped_grip() == "1h")
		_server_set_blocking.rpc_id(1, is_blocking)

	# Обработка кнопок боя и взаимодействия
	if ui_free:
		if Input.is_action_just_pressed("interact"):
			_try_interact()
		elif Input.is_action_just_pressed("drop_throw"):
			_try_throw()
		elif Input.is_action_just_pressed("kick"):
			_try_kick()
		elif Input.is_action_just_pressed("attack_light"):
			if not carried_prop_name.is_empty():
				_try_throw()
			else:
				_try_melee_attack(false)
		elif Input.is_action_just_pressed("attack_heavy"):
			if not carried_prop_name.is_empty():
				_try_throw()
			else:
				_try_melee_attack(true)
		elif Input.is_action_just_pressed("dodge"):
			_try_dodge()

	# Физика перемещения
	var input_vec := Vector2.ZERO
	if ui_free:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var cam_basis := Basis(Vector3.UP, cam_yaw)
	var move_dir := (cam_basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()

	var is_sprinting := ui_free and Input.is_action_pressed("sprint") and move_dir.length() > 0.1 and not is_blocking and stamina > 4.0
	if is_sprinting:
		stamina = maxf(0.0, stamina - 14.0 * delta)
		_stamina_regen_delay = 0.45

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif ui_free and Input.is_action_just_pressed("jump") and _dodge_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		SfxManager.play_3d("jump", global_position, 0.08, -3.0)

	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity.x = _dodge_dir.x * DODGE_SPEED
		velocity.z = _dodge_dir.z * DODGE_SPEED
	else:
		var spd := SPRINT_SPEED if is_sprinting else WALK_SPEED
		if is_blocking:
			spd *= 0.62
		if not carried_prop_name.is_empty():
			spd *= CARRY_SPEED_MULT
		if _anim_lock_timer > 0.05:
			spd *= 0.48

		var target_vx := move_dir.x * spd + _knockback_velocity.x
		var target_vz := move_dir.z * spd + _knockback_velocity.z
		var accel := 42.0 if is_on_floor() else 14.0
		velocity.x = move_toward(velocity.x, target_vx, accel * delta)
		velocity.z = move_toward(velocity.z, target_vz, accel * delta)

	var kb_speed_before := _knockback_velocity.length()
	if _wallsplat_cooldown > 0.0:
		_wallsplat_cooldown -= delta
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 26.0 * delta)
	move_and_slide()

	# Бонусный урон, если врага впечатали пинком/взрывом в каменную стену или заросли
	if kb_speed_before > 9.8 and is_on_wall() and _wallsplat_cooldown <= 0.0:
		_wallsplat_cooldown = 0.85
		_knockback_velocity = Vector3.ZERO
		_server_notify_wallsplat.rpc_id(1)

	# Толкание физических бочек и ящиков при набегании
	for i in range(get_slide_collision_count()):
		var sc := get_slide_collision(i)
		var col_obj := sc.get_collider()
		if col_obj is PhysicsProp and not (col_obj as PhysicsProp).is_static_structure:
			var push_dir := -sc.get_normal()
			push_dir.y = 0.05
			_server_nudge_prop.rpc_id(1, (col_obj as Node).name, push_dir.normalized() * 3.8)

	# Поворот модели персонажа
	var desired_yaw := _visual_root.rotation.y
	if is_blocking or _anim_lock_timer > 0.0 or not carried_prop_name.is_empty():
		desired_yaw = cam_yaw
	elif move_dir.length_squared() > 0.01:
		desired_yaw = atan2(-move_dir.x, -move_dir.z)
	_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, desired_yaw, clampf(delta * 15.0, 0.0, 1.0))

	# Локальный выбор анимации передвижения (если не идёт удар/рывок)
	if _anim_lock_timer <= 0.0 and _dodge_timer <= 0.0:
		var anim := _choose_locomotion_anim(move_dir, is_sprinting)
		_play_local_anim(anim)

	_sync_accum += delta
	if _sync_accum >= 0.04:
		_sync_accum = 0.0
		_server_receive_client_state.rpc_id(1, global_position, _visual_root.rotation.y, _net_current_anim)


func _process_remote_player(delta: float) -> void:
	global_position = global_position.lerp(_net_target_pos, clampf(delta * 18.0, 0.0, 1.0))
	if _visual_root != null:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, _net_target_yaw, clampf(delta * 16.0, 0.0, 1.0))


func _process_server_authority(delta: float) -> void:
	if is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_server_respawn_player()
		return

	# Страховочный возврат на поверхность двора (обрывов на карте нет)
	if global_position.y < -2.5:
		var safe := Vector3(clampf(global_position.x, -14.0, 14.0), 1.5, clampf(global_position.z, -24.0, 12.0))
		global_position = safe
		_respawn_rpc.rpc(safe)


@rpc("any_peer", "call_local", "reliable")
func _server_notify_wallsplat() -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 0:
		return
	SfxManager.play_3d("hit_blunt", global_position + Vector3(0.0, 1.0, 0.0), 0.08, 2.0)
	take_combat_hit(14.0, _last_attacker_id, Vector3.ZERO, global_position + Vector3(0.0, 1.1, 0.0), "Впечатан в стену", true)


func _choose_locomotion_anim(move_dir: Vector3, sprinting: bool) -> String:
	if not is_on_floor():
		return "Jump_Idle"
	if is_blocking:
		return "Blocking"
	if move_dir.length_squared() > 0.02:
		return "Running_A" if sprinting else "Walking_A"
	if not equipped_weapon_id.is_empty():
		return "2H_Melee_Idle" if _get_equipped_grip() == "2h" else "Idle"
	return "Unarmed_Idle"


func _get_equipped_grip() -> String:
	if AssetCatalog.WEAPON_DEFS.has(equipped_weapon_id):
		return String(AssetCatalog.WEAPON_DEFS[equipped_weapon_id]["grip"])
	return "1h"


func _play_local_anim(anim_name: String, force_restart: bool = false) -> void:
	_net_current_anim = anim_name
	if _anim_player == null:
		return
	var target := anim_name
	if not _anim_player.has_animation(target):
		target = "Idle" if _anim_player.has_animation("Idle") else ""
	if target.is_empty():
		return
	if force_restart or _anim_player.current_animation != target:
		_anim_player.stop() if force_restart else null
		_anim_player.play(target, 0.10)


func get_aim_direction() -> Vector3:
	var basis := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch)
	return (-basis.z).normalized()


func get_look_interaction_prompt() -> String:
	if is_dead:
		return ""
	if not carried_prop_name.is_empty():
		return "[ЛКМ / G] Метнуть предмет   |   [F] Пнуть"
	var target := _find_best_interactable()
	if target != null and target.has_method("get_interaction_prompt"):
		return String(target.call("get_interaction_prompt"))
	return ""


func _find_best_interactable() -> Node3D:
	var arena := get_tree().current_scene
	if arena == null:
		return null
	var entities := arena.get_node_or_null("Entities")
	if entities == null:
		return null

	var eye := global_position + Vector3(0.0, 1.35, 0.0)
	var look_dir := get_aim_direction()
	var best_node: Node3D = null
	var best_score: float = 999.0

	for ch in entities.get_children():
		if not (ch is Node3D):
			continue
		var can_use := false
		if ch is WorldWeapon and (ch as WorldWeapon).can_be_picked_up():
			can_use = true
		elif ch is PhysicsProp and (ch as PhysicsProp).can_be_grabbed():
			can_use = true
		if not can_use:
			continue

		var n3 := ch as Node3D
		var to_item := (n3.global_position + Vector3(0.0, 0.35, 0.0)) - eye
		var dist := to_item.length()
		if dist > 3.25:
			continue
		var dot := look_dir.dot(to_item.normalized())
		if dot < 0.42 and dist > 1.35:
			continue
		var score := dist - dot * 1.4
		if score < best_score:
			best_score = score
			best_node = n3

	return best_node


func _try_interact() -> void:
	if _attack_cooldown > 0.0:
		return
	var target := _find_best_interactable()
	if target == null:
		return
	_attack_cooldown = 0.28
	_anim_lock_timer = 0.25
	_play_local_anim("PickUp", true)
	_server_request_interact.rpc_id(1, target.name)


func _try_throw() -> void:
	if _attack_cooldown > 0.0:
		return
	if carried_prop_name.is_empty() and equipped_weapon_id.is_empty():
		return
	_attack_cooldown = 0.45
	_anim_lock_timer = 0.38
	_visual_root.rotation.y = cam_yaw
	_play_local_anim("Throw", true)
	add_camera_shake(0.03)
	var aim_dir := (get_aim_direction() + Vector3(0.0, 0.11, 0.0)).normalized()
	var origin := global_position + Vector3(0.0, 1.48, 0.0) + (-Basis(Vector3.UP, cam_yaw).z) * 1.25
	_server_request_throw.rpc_id(1, origin, aim_dir)


func _try_kick() -> void:
	if _attack_cooldown > 0.0 or stamina < 16.0:
		return
	stamina -= 16.0
	_stamina_regen_delay = 0.75
	_attack_cooldown = 0.56
	_anim_lock_timer = 0.46
	_visual_root.rotation.y = cam_yaw
	_play_local_anim("Unarmed_Melee_Attack_Kick", true)
	var fwd := -Basis(Vector3.UP, cam_yaw).z
	_knockback_velocity += fwd * 3.8
	_server_request_melee_strike.rpc_id(1, "kick", global_position, cam_yaw, 0, "Unarmed_Melee_Attack_Kick")


func _try_melee_attack(is_heavy: bool) -> void:
	if _attack_cooldown > 0.0:
		return

	var cost := 18.0 if is_heavy else 10.0
	var cd := 0.58 if is_heavy else 0.38
	var grip := _get_equipped_grip()
	if AssetCatalog.WEAPON_DEFS.has(equipped_weapon_id):
		var def: Dictionary = AssetCatalog.WEAPON_DEFS[equipped_weapon_id]
		cost = float(def["stamina_cost"]) * (1.35 if is_heavy else 1.0)
		cd = float(def["cooldown"]) * (1.30 if is_heavy else 1.0)

	if stamina < cost * 0.6:
		return
	stamina = maxf(0.0, stamina - cost)
	_stamina_regen_delay = 0.70
	_attack_cooldown = cd
	_anim_lock_timer = cd * 0.85
	_combo_reset_timer = 1.35
	_visual_root.rotation.y = cam_yaw

	var anim_name := "Unarmed_Melee_Attack_Punch_A"
	if equipped_weapon_id.is_empty():
		if is_heavy:
			anim_name = "Unarmed_Melee_Attack_Punch_B"
		else:
			anim_name = "Unarmed_Melee_Attack_Punch_A" if (_combo_index % 2 == 0) else "Unarmed_Melee_Attack_Punch_B"
	elif grip == "1h":
		if is_heavy:
			anim_name = "1H_Melee_Attack_Chop"
		else:
			var seq := ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop"]
			anim_name = seq[_combo_index % seq.size()]
	else:
		if is_heavy:
			anim_name = "2H_Melee_Attack_Chop"
		else:
			var seq2 := ["2H_Melee_Attack_Slice", "2H_Melee_Attack_Chop", "2H_Melee_Attack_Spin"]
			anim_name = seq2[_combo_index % seq2.size()]

	var used_combo := _combo_index
	_combo_index += 1
	_play_local_anim(anim_name, true)

	var fwd := -Basis(Vector3.UP, cam_yaw).z
	_knockback_velocity += fwd * (3.4 if is_heavy else 2.0)

	var kind := "heavy" if is_heavy else "light"
	_server_request_melee_strike.rpc_id(1, kind, global_position, cam_yaw, used_combo, anim_name)


func _try_dodge() -> void:
	if _dodge_timer > 0.0 or stamina < 20.0 or not is_on_floor():
		return
	stamina -= 20.0
	_stamina_regen_delay = 0.80
	_dodge_timer = 0.32
	_invuln_timer = 0.34
	_anim_lock_timer = 0.34

	var in_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, cam_yaw)
	if in_vec.length_squared() < 0.05:
		_dodge_dir = -cam_basis.z
		_play_local_anim("Dodge_Forward", true)
	else:
		_dodge_dir = (cam_basis * Vector3(in_vec.x, 0.0, in_vec.y)).normalized()
		if absf(in_vec.x) > absf(in_vec.y):
			_play_local_anim("Dodge_Right" if in_vec.x > 0.0 else "Dodge_Left", true)
		else:
			_play_local_anim("Dodge_Backward" if in_vec.y > 0.0 else "Dodge_Forward", true)

	SfxManager.play_3d("swing_light", global_position + Vector3(0.0, 1.0, 0.0), 0.12, -3.0)
	_server_broadcast_action_anim.rpc_id(1, _net_current_anim)


func _update_carried_prop_attachment(delta: float) -> void:
	if carried_prop_name.is_empty():
		return
	var arena := get_tree().current_scene
	if arena == null:
		return
	var entities := arena.get_node_or_null("Entities")
	if entities == null:
		return
	var prop := entities.get_node_or_null(carried_prop_name)
	if prop == null or not (prop is Node3D):
		if multiplayer.is_server():
			carried_prop_name = ""
			_sync_inventory_rpc.rpc(equipped_weapon_id, "")
		return

	var yaw := cam_yaw if is_local_player() else _net_target_yaw
	var fwd := -Basis(Vector3.UP, yaw).z
	var target_pos := global_position + Vector3(0.0, 1.18, 0.0) + fwd * 0.92
	var p3 := prop as Node3D
	p3.global_position = p3.global_position.lerp(target_pos, clampf(delta * 28.0, 0.0, 1.0))
	p3.global_rotation = Vector3(0.0, yaw, 0.0)


func add_camera_shake(amount: float) -> void:
	if is_local_player():
		_shake_strength = minf(0.14, _shake_strength + amount)


func apply_external_launch(launch_vel: Vector3) -> void:
	if is_dead:
		return
	_client_apply_knockback_rpc.rpc(launch_vel, true)


func _refresh_equipped_visual() -> void:
	if _equipped_visual != null:
		_equipped_visual.queue_free()
		_equipped_visual = null

	if _shield_node != null:
		_shield_node.visible = is_blocking or (not equipped_weapon_id.is_empty() and _get_equipped_grip() == "1h")

	if not equipped_weapon_id.is_empty() and _hand_slot_r != null:
		_equipped_visual = AssetCatalog.instantiate_weapon_visual(equipped_weapon_id)
		_hand_slot_r.add_child(_equipped_visual)


# ============================================================================
# СЕРВЕРНЫЕ RPC И БОЕВАЯ ЛОГИКА
# ============================================================================

@rpc("any_peer", "call_local", "unreliable_ordered")
func _server_receive_client_state(pos: Vector3, yaw: float, anim_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 0:
		return
	if not is_local_player():
		if global_position.distance_to(pos) < 12.0:
			global_position = pos
		_net_target_pos = pos
		_net_target_yaw = yaw
		if _visual_root != null:
			_visual_root.rotation.y = yaw
	_client_broadcast_state.rpc(pos, yaw, anim_name)


@rpc("authority", "unreliable_ordered")
func _client_broadcast_state(pos: Vector3, yaw: float, anim_name: String) -> void:
	if is_local_player():
		return
	_net_target_pos = pos
	_net_target_yaw = yaw
	if _anim_lock_timer <= 0.0:
		_play_local_anim(anim_name)


@rpc("any_peer", "call_local", "reliable")
func _server_set_blocking(state: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 0:
		return
	is_blocking = state
	if state:
		block_started_msec = Time.get_ticks_msec()
	_client_sync_blocking.rpc(state)


@rpc("authority", "call_local", "reliable")
func _client_sync_blocking(state: bool) -> void:
	is_blocking = state
	if state:
		block_started_msec = Time.get_ticks_msec()
	if _shield_node != null:
		_shield_node.visible = is_blocking or (not equipped_weapon_id.is_empty() and _get_equipped_grip() == "1h")


@rpc("any_peer", "call_local", "reliable")
func _server_broadcast_action_anim(anim_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 0:
		return
	_client_play_action_anim.rpc(anim_name, "swing_light")


@rpc("authority", "call_local", "reliable")
func _client_play_action_anim(anim_name: String, sfx_id: String) -> void:
	if not sfx_id.is_empty():
		SfxManager.play_3d(sfx_id, global_position + Vector3(0.0, 1.1, 0.0), 0.09)
	if not is_local_player():
		_anim_lock_timer = 0.42
		_play_local_anim(anim_name, true)


@rpc("any_peer", "call_local", "unreliable")
func _server_nudge_prop(prop_node_name: String, push_vel: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var arena := get_tree().current_scene
	if arena == null:
		return
	var entities := arena.get_node_or_null("Entities")
	if entities == null:
		return
	var node := entities.get_node_or_null(prop_node_name)
	if node is PhysicsProp:
		var pp := node as PhysicsProp
		if not pp.is_static_structure and pp.held_by_peer_id == 0:
			pp.freeze = false
			pp.linear_velocity.x = push_vel.x
			pp.linear_velocity.z = push_vel.z
			pp.last_pusher_id = peer_id


@rpc("any_peer", "call_local", "reliable")
func _server_request_interact(target_node_name: String) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 0:
		return

	var arena := get_tree().current_scene
	if arena == null:
		return
	var entities := arena.get_node_or_null("Entities")
	if entities == null:
		return
	var target := entities.get_node_or_null(target_node_name)
	if target == null or not (target is Node3D):
		return
	if (target as Node3D).global_position.distance_to(global_position) > 4.5:
		return

	if target is WorldWeapon:
		var ww := target as WorldWeapon
		if not ww.can_be_picked_up():
			return
		var new_wid := ww.weapon_id
		var drop_pos := ww.global_position + Vector3(0.0, 0.25, 0.0)
		ww.queue_free()
		if not equipped_weapon_id.is_empty() and arena.has_method("server_spawn_world_weapon"):
			arena.call("server_spawn_world_weapon", equipped_weapon_id, drop_pos, Vector3(0.0, 3.0, 0.0), false, 0)
		equipped_weapon_id = new_wid
		_sync_inventory_rpc.rpc(equipped_weapon_id, carried_prop_name)
		_client_play_action_anim.rpc("PickUp", "pickup")

	elif target is PhysicsProp:
		var pp := target as PhysicsProp
		if not pp.can_be_grabbed() or not carried_prop_name.is_empty():
			return
		pp.server_grab(peer_id)
		carried_prop_name = pp.name
		is_blocking = false
		_sync_inventory_rpc.rpc(equipped_weapon_id, carried_prop_name)
		_client_play_action_anim.rpc("PickUp", "pickup")


@rpc("any_peer", "call_local", "reliable")
func _server_request_throw(origin: Vector3, aim_dir: Vector3) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 0:
		return

	var arena := get_tree().current_scene
	if arena == null:
		return
	var clean_dir := aim_dir.normalized()
	if clean_dir.length_squared() < 0.1:
		clean_dir = Vector3.FORWARD

	# Защита от подмены координат броска
	var safe_origin := origin
	if safe_origin.distance_to(global_position + Vector3(0.0, 1.3, 0.0)) > 3.0:
		safe_origin = global_position + Vector3(0.0, 1.45, 0.0) + clean_dir * 0.9

	if not carried_prop_name.is_empty():
		var entities := arena.get_node_or_null("Entities")
		if entities != null:
			var prop := entities.get_node_or_null(carried_prop_name)
			if prop is PhysicsProp:
				var pp := prop as PhysicsProp
				add_collision_exception_with(pp)
				pp.server_release_and_throw(safe_origin, clean_dir * 19.5, peer_id)
				get_tree().create_timer(0.45).timeout.connect(func() -> void:
					if is_instance_valid(self) and is_instance_valid(pp):
						remove_collision_exception_with(pp)
				)
		carried_prop_name = ""
		_sync_inventory_rpc.rpc(equipped_weapon_id, "")
		_client_play_action_anim.rpc("Throw", "throw")

	elif not equipped_weapon_id.is_empty():
		var wid := equipped_weapon_id
		equipped_weapon_id = ""
		var throw_spd := 26.5 if wid == "axe_1h" else 23.5
		if arena.has_method("server_spawn_world_weapon"):
			var spawned: Node = arena.call("server_spawn_world_weapon", wid, safe_origin, clean_dir * throw_spd, true, peer_id)
			if spawned is PhysicsBody3D:
				var pb := spawned as PhysicsBody3D
				add_collision_exception_with(pb)
				get_tree().create_timer(0.45).timeout.connect(func() -> void:
					if is_instance_valid(self) and is_instance_valid(pb):
						remove_collision_exception_with(pb)
				)
		_sync_inventory_rpc.rpc("", carried_prop_name)
		_client_play_action_anim.rpc("Throw", "throw")


@rpc("authority", "call_local", "reliable")
func _sync_inventory_rpc(weapon_id: String, prop_name: String) -> void:
	equipped_weapon_id = weapon_id
	carried_prop_name = prop_name
	_refresh_equipped_visual()


@rpc("any_peer", "call_local", "reliable")
func _server_request_melee_strike(
	strike_kind: String,
	attacker_pos: Vector3,
	yaw: float,
	_combo_step: int,
	anim_name: String
) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 0:
		return

	var safe_pos := attacker_pos if attacker_pos.distance_to(global_position) < 4.0 else global_position
	var fwd := -Basis(Vector3.UP, yaw).z

	var dmg: float = 16.0
	var reach: float = 2.05
	var kb_power: float = 5.5
	var unblockable: bool = false
	var cause_label: String = "Рукопашный удар"
	var swing_sfx: String = "swing_light"
	var hit_sfx: String = "hit_punch"
	var is_whirlwind := (anim_name == "2H_Melee_Attack_Spin")

	if strike_kind == "kick":
		dmg = 18.0
		reach = 2.35
		kb_power = 17.5
		unblockable = true
		cause_label = "Спартанский пинок"
		swing_sfx = "swing_heavy"
		hit_sfx = "hit_kick"
	elif equipped_weapon_id.is_empty():
		if strike_kind == "heavy":
			dmg = 27.0
			kb_power = 9.0
			cause_label = "Тяжёлый хук"
			swing_sfx = "swing_heavy"
	elif AssetCatalog.WEAPON_DEFS.has(equipped_weapon_id):
		var def: Dictionary = AssetCatalog.WEAPON_DEFS[equipped_weapon_id]
		dmg = float(def["heavy_damage"] if strike_kind == "heavy" else def["damage"])
		reach = float(def["range"])
		kb_power = float(def["knockback"]) * (1.35 if strike_kind == "heavy" else 1.0)
		cause_label = String(def["title"])
		hit_sfx = String(def["hit_sfx"])
		swing_sfx = "swing_heavy" if (strike_kind == "heavy" or String(def["grip"]) == "2h") else "swing_light"

	_client_play_action_anim.rpc(anim_name, swing_sfx)

	# Небольшая задержка под кадр замаха анимации (0.11с) для честного и сочного тайминга удара
	get_tree().create_timer(0.11).timeout.connect(func() -> void:
		if not is_instance_valid(self) or is_dead:
			return
		_server_execute_melee_hitbox(safe_pos, fwd, reach, dmg, kb_power, unblockable, is_whirlwind, cause_label, hit_sfx, strike_kind == "kick")
	)


func _server_execute_melee_hitbox(
	origin_base: Vector3,
	fwd: Vector3,
	reach: float,
	dmg: float,
	kb_power: float,
	unblockable: bool,
	is_whirlwind: bool,
	cause_label: String,
	hit_sfx: String,
	is_kick: bool
) -> void:
	var space := get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = reach * (0.95 if is_whirlwind else 0.62)

	var center := origin_base + Vector3(0.0, 1.0, 0.0) + (Vector3.ZERO if is_whirlwind else fwd * (reach * 0.58))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sph
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 2 | 4
	query.exclude = [get_rid()]

	var hits := space.intersect_shape(query, 12)
	var hit_seen: Dictionary = {}

	for h in hits:
		var col: Object = h.get("collider")
		if col == null or col == self or not (col is Node3D):
			continue
		var oid := col.get_instance_id()
		if hit_seen.has(oid):
			continue
		hit_seen[oid] = true

		var target_node := col as Node3D
		var delta_vec := (target_node.global_position - origin_base)
		delta_vec.y = 0.0
		if not is_whirlwind and delta_vec.length_squared() > 0.04:
			if fwd.dot(delta_vec.normalized()) < -0.15:
				continue

		if col.has_method("take_combat_hit"):
			var push_dir := fwd if not is_whirlwind else delta_vec.normalized()
			if push_dir.length_squared() < 0.01:
				push_dir = fwd
			push_dir.y = 0.34 if is_kick else 0.20
			var kb_vel := push_dir.normalized() * kb_power
			var hit_point := target_node.global_position + Vector3(0.0, 1.05, 0.0)
			var connected: bool = bool(col.call("take_combat_hit", dmg, peer_id, kb_vel, hit_point, cause_label, unblockable))
			if connected:
				_melee_confirm_fx_rpc.rpc(hit_point, hit_sfx, is_kick)


@rpc("authority", "call_local", "reliable")
func _melee_confirm_fx_rpc(hit_pos: Vector3, sfx_id: String, heavy_shake: bool) -> void:
	SfxManager.play_3d(sfx_id, hit_pos, 0.08, 1.5)
	add_camera_shake(0.055 if heavy_shake else 0.028)


func take_combat_hit(
	amount: float,
	attacker_id: int,
	knockback_vel: Vector3,
	hit_pos: Vector3,
	cause_label: String,
	is_unblockable: bool = false
) -> bool:
	if not multiplayer.is_server() or is_dead:
		return false
	if _invuln_timer > 0.0 and amount < 500.0:
		return false

	if attacker_id > 0 and attacker_id != peer_id:
		_last_attacker_id = attacker_id

	var final_dmg := amount
	var popup_text := ""
	var popup_color := Color(1.0, 0.36, 0.28)
	var final_kb := knockback_vel

	# Проверка фронтального блока / идеального парирования
	if is_blocking and amount < 500.0:
		var my_fwd := -Basis(Vector3.UP, _visual_root.rotation.y if _visual_root != null else cam_yaw).z
		var incoming_dir := knockback_vel.normalized()
		var facing_attack := (incoming_dir.length_squared() < 0.01) or (my_fwd.dot(incoming_dir) < -0.15)
		if facing_attack:
			if is_unblockable:
				is_blocking = false
				popup_text = "ПРОБИТ БЛОК! -%d" % roundi(final_dmg)
				popup_color = Color(1.0, 0.55, 0.12)
				_client_sync_blocking.rpc(false)
			else:
				var elapsed_ms := Time.get_ticks_msec() - block_started_msec
				if elapsed_ms <= 260:
					final_dmg = 0.0
					final_kb = knockback_vel * 0.15
					popup_text = "ПАРИРОВАНИЕ!"
					popup_color = Color(0.35, 0.92, 1.0)
				else:
					final_dmg = amount * 0.18
					final_kb = knockback_vel * 0.35
					popup_text = "БЛОК -%d" % roundi(final_dmg)
					popup_color = Color(0.70, 0.85, 1.0)
				_block_fx_rpc.rpc(hit_pos, popup_text, popup_color)
				hp = maxf(1.0, hp - final_dmg)
				_client_apply_knockback_rpc.rpc(final_kb, false)
				_sync_hp_rpc.rpc(hp, is_dead)
				return true

	hp = maxf(0.0, hp - final_dmg)
	if popup_text.is_empty():
		popup_text = "-%d" % roundi(minf(final_dmg, 999.0))

	if hp <= 0.0:
		_server_handle_death(cause_label)
	else:
		_client_apply_knockback_rpc.rpc(final_kb, false)

	_player_hit_fx_rpc.rpc(hp, is_dead, hit_pos, popup_text, popup_color)
	return true


func _server_handle_death(cause_label: String) -> void:
	is_dead = true
	_respawn_timer = 3.5
	is_blocking = false

	var arena := get_tree().current_scene
	if not carried_prop_name.is_empty() and arena != null:
		var entities := arena.get_node_or_null("Entities")
		if entities != null:
			var prop := entities.get_node_or_null(carried_prop_name)
			if prop is PhysicsProp:
				(prop as PhysicsProp).server_release_and_throw(global_position + Vector3(0.0, 1.2, 0.0), Vector3(0.0, 3.5, 0.0), peer_id)
		carried_prop_name = ""

	if not equipped_weapon_id.is_empty() and arena != null and global_position.y > -12.0:
		if arena.has_method("server_spawn_world_weapon"):
			arena.call("server_spawn_world_weapon", equipped_weapon_id, global_position + Vector3(0.0, 0.8, 0.0), Vector3(randf_range(-2.0, 2.0), 4.0, randf_range(-2.0, 2.0)), false, 0)
		equipped_weapon_id = ""

	_sync_inventory_rpc.rpc(equipped_weapon_id, carried_prop_name)
	NetworkManager.server_record_kill(_last_attacker_id, peer_id, cause_label)


func _server_respawn_player() -> void:
	var spawn_pos := Vector3(0.0, 2.0, 0.0)
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("get_random_spawn_point"):
		spawn_pos = arena.call("get_random_spawn_point")

	is_dead = false
	hp = MAX_HP
	stamina = MAX_STAMINA
	_last_attacker_id = 0
	velocity = Vector3.ZERO
	global_position = spawn_pos
	_respawn_rpc.rpc(spawn_pos)


@rpc("authority", "call_local", "reliable")
func _block_fx_rpc(hit_pos: Vector3, text: String, col: Color) -> void:
	SfxManager.play_3d("block_clang", hit_pos, 0.06, 2.0)
	VfxHelper.spawn_hit_sparks(get_tree().current_scene, hit_pos, Color(0.45, 0.88, 1.0), 22, 1.2)
	VfxHelper.spawn_damage_popup(get_tree().current_scene, hit_pos + Vector3(0.0, 0.35, 0.0), text, col)
	add_camera_shake(0.03)


@rpc("authority", "call_local", "reliable")
func _sync_hp_rpc(new_hp: float, dead_state: bool) -> void:
	hp = new_hp
	is_dead = dead_state
	_update_nameplate()


@rpc("authority", "call_local", "reliable")
func _player_hit_fx_rpc(new_hp: float, dead_state: bool, hit_pos: Vector3, text: String, col: Color) -> void:
	hp = new_hp
	is_dead = dead_state
	_update_nameplate()
	VfxHelper.spawn_hit_sparks(get_tree().current_scene, hit_pos, Color(1.0, 0.42, 0.20), 18, 1.05)
	VfxHelper.spawn_damage_popup(get_tree().current_scene, hit_pos + Vector3(0.0, 0.35, 0.0), text, col)
	add_camera_shake(0.05)
	if dead_state:
		collision_layer = 0
		_play_local_anim("Death_A", true)
	else:
		_anim_lock_timer = 0.26
		_play_local_anim("Hit_A", true)


@rpc("authority", "call_local", "reliable")
func _client_apply_knockback_rpc(kb_vel: Vector3, override_vertical: bool) -> void:
	if not is_local_player():
		return
	if override_vertical:
		velocity.y = kb_vel.y
	else:
		velocity.y = maxf(velocity.y, kb_vel.y)
	_knockback_velocity = Vector3(kb_vel.x, 0.0, kb_vel.z)


@rpc("authority", "call_local", "reliable")
func _respawn_rpc(spawn_pos: Vector3) -> void:
	is_dead = false
	hp = MAX_HP
	stamina = MAX_STAMINA
	collision_layer = 2
	velocity = Vector3.ZERO
	_knockback_velocity = Vector3.ZERO
	global_position = spawn_pos
	_net_target_pos = spawn_pos
	_play_local_anim("Unarmed_Idle", true)
	_update_nameplate()
