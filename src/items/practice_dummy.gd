class_name PracticeDummy
extends CharacterBody3D
## Интерактивный боевой манекен (CharacterBody3D) для отработки рукопашной, оружия, пинков и метания.

const MAX_HP: float = 150.0
const GRAVITY: float = 24.0

var hp: float = MAX_HP
var is_dead: bool = false
var home_position: Vector3 = Vector3.ZERO
var home_yaw: float = 0.0
var last_attacker_id: int = 0

var _visual_root: Node3D = null
var _anim_player: AnimationPlayer = null
var _hp_label: Label3D = null
var _respawn_timer: float = 0.0
var _stagger_timer: float = 0.0
var _net_target_pos: Vector3 = Vector3.ZERO
var _net_target_yaw: float = 0.0
var _sync_accum: float = 0.0


func setup_from_spawn_data(data: Dictionary) -> void:
	name = String(data.get("name", "Dummy_%d" % Time.get_ticks_usec()))
	position = data.get("pos", Vector3.ZERO)
	rotation = data.get("rot", Vector3.ZERO)
	home_position = position
	home_yaw = rotation.y


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	home_position = position
	home_yaw = rotation.y
	_net_target_pos = global_position
	_net_target_yaw = global_rotation.y

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.40
	cap.height = 1.85
	col.shape = cap
	col.position = Vector3(0.0, 0.925, 0.0)
	add_child(col)

	_visual_root = Node3D.new()
	_visual_root.scale = Vector3(0.82, 0.82, 0.82)
	_visual_root.rotation.y = PI
	add_child(_visual_root)

	var model := AssetCatalog.instantiate_character_model("barbarian")
	if model != null:
		_visual_root.add_child(model)
		_hide_extra_slots(model)
		_tint_dummy(model, Color(0.92, 0.72, 0.45))
		_anim_player = _find_anim_player(model)
		_play_anim("Unarmed_Idle")
	else:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.40
		cm.height = 1.85
		mi.mesh = cm
		mi.position = Vector3(0.0, 0.925, 0.0)
		add_child(mi)

	if DisplayServer.get_name() != "headless":
		_hp_label = Label3D.new()
		_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hp_label.position = Vector3(0.0, 2.25, 0.0)
		_hp_label.font_size = 34
		_hp_label.outline_size = 10
		_hp_label.pixel_size = 0.0055
		add_child(_hp_label)
		_refresh_label()


func _hide_extra_slots(root: Node) -> void:
	for n in root.find_children("*", "Node3D", true, false):
		if n.name in ["handslot.l", "handslot.r"]:
			for ch in n.get_children():
				if ch is Node3D:
					(ch as Node3D).visible = (ch.name == "Barbarian_Round_Shield")


func _tint_dummy(node: Node, col: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var orig := mi.mesh.surface_get_material(0)
			if orig is StandardMaterial3D:
				var dup := (orig as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.albedo_color = col
				dup.roughness = 0.65
				mi.material_override = dup
	for ch in node.get_children():
		_tint_dummy(ch, col)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for ch in node.get_children():
		var found := _find_anim_player(ch)
		if found != null:
			return found
	return null


func _play_anim(anim_name: String) -> void:
	if _anim_player == null:
		return
	if _anim_player.has_animation(anim_name):
		if _anim_player.current_animation != anim_name:
			_anim_player.play(anim_name, 0.12)


func _refresh_label() -> void:
	if _hp_label == null:
		return
	if is_dead:
		_hp_label.text = "Боевой манекен [Сражён]"
		_hp_label.modulate = Color(0.65, 0.65, 0.65)
	else:
		_hp_label.text = "Боевой манекен\nHP: %d / %d" % [ceili(hp), int(MAX_HP)]
		var ratio := clampf(hp / MAX_HP, 0.0, 1.0)
		_hp_label.modulate = Color(1.0 - ratio * 0.65, 0.35 + ratio * 0.65, 0.30)


func apply_external_launch(launch_vel: Vector3) -> void:
	if is_dead:
		return
	velocity = launch_vel


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		global_position = global_position.lerp(_net_target_pos, clampf(delta * 16.0, 0.0, 1.0))
		global_rotation.y = lerp_angle(global_rotation.y, _net_target_yaw, clampf(delta * 14.0, 0.0, 1.0))
		return

	if is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_server_respawn()
		return

	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		if _stagger_timer <= 0.0:
			_sync_anim_rpc.rpc("Unarmed_Idle")

	var horiz_spd_before := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 22.0 * delta)

	move_and_slide()

	if horiz_spd_before > 9.5 and is_on_wall() and _stagger_timer > 0.15:
		velocity.x = 0.0
		velocity.z = 0.0
		_stagger_timer = 0.10
		SfxManager.play_3d("hit_blunt", global_position + Vector3(0.0, 1.0, 0.0), 0.08, 2.0)
		take_combat_hit(15.0, last_attacker_id, Vector3.ZERO, global_position + Vector3(0.0, 1.1, 0.0), "Впечатан в стену", true)
		return

	if global_position.y < -2.5:
		global_position = home_position + Vector3(0.0, 0.25, 0.0)
		velocity = Vector3.ZERO

	_sync_accum += delta
	if _sync_accum >= 0.05:
		_sync_accum = 0.0
		_client_sync_dummy.rpc(global_position, global_rotation.y)


func take_combat_hit(
	amount: float,
	attacker_id: int,
	knockback_vel: Vector3,
	hit_pos: Vector3,
	cause_label: String,
	_is_unblockable: bool = false
) -> bool:
	if not multiplayer.is_server() or is_dead:
		return false

	if attacker_id > 0:
		last_attacker_id = attacker_id
	hp = maxf(0.0, hp - amount)
	velocity += knockback_vel

	if knockback_vel.length() > 0.5:
		var flat := Vector3(-knockback_vel.x, 0.0, -knockback_vel.z)
		if flat.length_squared() > 0.01:
			global_rotation.y = atan2(-flat.x, -flat.z)

	_stagger_timer = 0.45
	var died := hp <= 0.0
	if died:
		is_dead = true
		_respawn_timer = 4.0
		collision_layer = 0
		NetworkManager.server_record_kill(last_attacker_id, -1, cause_label, "Боевой манекен")

	_dummy_hit_rpc.rpc(hp, is_dead, amount, hit_pos, died)
	return true


func _server_respawn() -> void:
	is_dead = false
	hp = MAX_HP
	last_attacker_id = 0
	velocity = Vector3.ZERO
	global_position = home_position + Vector3(0.0, 0.15, 0.0)
	global_rotation.y = home_yaw
	collision_layer = 2
	_dummy_respawn_rpc.rpc(global_position, global_rotation.y)


@rpc("authority", "call_local", "reliable")
func _dummy_hit_rpc(new_hp: float, dead_state: bool, dmg: float, hit_pos: Vector3, died: bool) -> void:
	hp = new_hp
	is_dead = dead_state
	if dead_state:
		collision_layer = 0
		_play_anim("Death_A")
	else:
		if _anim_player != null:
			_anim_player.stop()
		_play_anim("Hit_A" if randf() < 0.5 else "Hit_B")
	_refresh_label()
	VfxHelper.spawn_hit_sparks(get_tree().current_scene, hit_pos, Color(1.0, 0.72, 0.25), 16, 1.0)
	VfxHelper.spawn_damage_popup(get_tree().current_scene, hit_pos + Vector3(0.0, 0.35, 0.0), "-%d" % roundi(dmg), Color(1.0, 0.85, 0.30))


@rpc("authority", "call_local", "reliable")
func _dummy_respawn_rpc(pos: Vector3, yaw: float) -> void:
	is_dead = false
	hp = MAX_HP
	collision_layer = 2
	global_position = pos
	global_rotation.y = yaw
	_net_target_pos = pos
	_net_target_yaw = yaw
	_play_anim("Unarmed_Idle")
	_refresh_label()


@rpc("authority", "call_local", "reliable")
func _sync_anim_rpc(anim_name: String) -> void:
	_play_anim(anim_name)


@rpc("authority", "unreliable_ordered")
func _client_sync_dummy(pos: Vector3, yaw: float) -> void:
	if multiplayer.is_server():
		return
	_net_target_pos = pos
	_net_target_yaw = yaw
