class_name WorldWeapon
extends RigidBody3D
## Оружие в мире: лежит на стойках/земле (можно подобрать на [E]) или летит как смертоносный брошенный снаряд.

var weapon_id: String = "sword_1h"
var is_thrown_projectile: bool = false
var thrower_peer_id: int = 0
var _thrown_grace_time: float = 0.0
var _already_hit_ids: Dictionary = {}

var _net_target_pos: Vector3 = Vector3.ZERO
var _net_target_rot: Quaternion = Quaternion.IDENTITY
var _has_net_target: bool = false
var _sync_accum: float = 0.0
var _ring_mesh: MeshInstance3D = null


func setup_from_spawn_data(data: Dictionary) -> void:
	name = String(data.get("name", "Weapon_%d" % Time.get_ticks_usec()))
	weapon_id = String(data.get("weapon_id", "sword_1h"))
	position = data.get("pos", Vector3.UP)
	rotation = data.get("rot", Vector3.ZERO)
	is_thrown_projectile = bool(data.get("thrown", false))
	thrower_peer_id = int(data.get("thrower_id", 0))
	if data.has("vel"):
		linear_velocity = data["vel"]
	if data.has("ang_vel"):
		angular_velocity = data["ang_vel"]


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	mass = 2.8 if _get_grip() == "1h" else 4.6
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4

	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.22
	phys_mat.friction = 0.80
	physics_material_override = phys_mat

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var length: float = 1.15 if _get_grip() == "1h" else 1.55
	box.size = Vector3(0.22, length, 0.22)
	col.shape = box
	col.position = Vector3(0.0, length * 0.42, 0.0)
	add_child(col)

	var vis := AssetCatalog.instantiate_weapon_visual(weapon_id)
	add_child(vis)

	_create_pickup_beacon()
	body_entered.connect(_on_body_entered)

	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		_net_target_pos = global_position
		_net_target_rot = global_transform.basis.get_rotation_quaternion()
		_has_net_target = true


func _get_grip() -> String:
	if AssetCatalog.WEAPON_DEFS.has(weapon_id):
		return String(AssetCatalog.WEAPON_DEFS[weapon_id]["grip"])
	return "1h"


func get_weapon_title() -> String:
	if AssetCatalog.WEAPON_DEFS.has(weapon_id):
		return String(AssetCatalog.WEAPON_DEFS[weapon_id]["title"])
	return weapon_id


func can_be_picked_up() -> bool:
	if is_thrown_projectile and _thrown_grace_time < 0.22:
		return false
	return linear_velocity.length() < 5.5


func get_interaction_prompt() -> String:
	if not can_be_picked_up():
		return ""
	return "[E] Подобрать: %s" % get_weapon_title()


func _create_pickup_beacon() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var accent: Color = Color(0.85, 0.78, 0.45)
	if AssetCatalog.WEAPON_DEFS.has(weapon_id):
		accent = AssetCatalog.WEAPON_DEFS[weapon_id]["accent_color"]

	_ring_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.40
	torus.rings = 24
	torus.ring_segments = 12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.55)
	torus.material = mat
	_ring_mesh.mesh = torus
	add_child(_ring_mesh)


func _physics_process(delta: float) -> void:
	if _ring_mesh != null:
		_ring_mesh.visible = not is_thrown_projectile and linear_velocity.length() < 1.5
		if _ring_mesh.visible:
			_ring_mesh.global_rotation = Vector3.ZERO
			_ring_mesh.global_position = global_position + Vector3(0.0, 0.06, 0.0)

	if not multiplayer.is_server():
		if _has_net_target:
			global_position = global_position.lerp(_net_target_pos, clampf(delta * 18.0, 0.0, 1.0))
			var cur_q := global_transform.basis.get_rotation_quaternion()
			var next_q := cur_q.slerp(_net_target_rot, clampf(delta * 18.0, 0.0, 1.0))
			global_transform.basis = Basis(next_q)
		return

	if global_position.y < -3.0:
		var cx := clampf(global_position.x, -82.0, 82.0)
		var cz := clampf(global_position.z, -82.0, 82.0)
		global_position = Vector3(cx, TerrainBuilder.get_height(cx, cz) + 1.2, cz)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

	if is_thrown_projectile:
		_thrown_grace_time += delta
		var speed := linear_velocity.length()
		if speed < 3.2 and _thrown_grace_time > 0.25:
			is_thrown_projectile = false
		else:
			_server_sweep_thrown_hits(delta)

	_sync_accum += delta
	if _sync_accum >= 0.05:
		_sync_accum = 0.0
		if not sleeping or is_thrown_projectile:
			_client_sync_xform.rpc(global_position, global_transform.basis.get_rotation_quaternion(), is_thrown_projectile)


func _server_sweep_thrown_hits(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + linear_velocity * delta * 0.5)
	query.collision_mask = 2 | 4
	query.exclude = [get_rid()]

	var hits := space.intersect_shape(query, 6)
	for h in hits:
		var collider: Object = h.get("collider")
		if collider == null or collider == self:
			continue
		var oid := collider.get_instance_id()
		if _already_hit_ids.has(oid):
			continue
		if collider.has_method("get_peer_id") and int(collider.call("get_peer_id")) == thrower_peer_id and _thrown_grace_time < 0.35:
			continue
		if collider.has_method("take_combat_hit"):
			_already_hit_ids[oid] = true
			var def: Dictionary = AssetCatalog.WEAPON_DEFS.get(weapon_id, {})
			var dmg: float = float(def.get("throw_damage", 50.0))
			var kb_dir := linear_velocity.normalized()
			kb_dir.y = maxf(kb_dir.y, 0.22)
			var kb := kb_dir.normalized() * float(def.get("knockback", 11.0)) * 1.25
			var cause := "%s (бросок)" % get_weapon_title()
			collider.call("take_combat_hit", dmg, thrower_peer_id, kb, global_position, cause, false)
			_play_thrown_impact_fx.rpc(global_position, String(def.get("hit_sfx", "hit_blade")))
			linear_velocity = -linear_velocity * 0.28 + Vector3(0.0, 2.8, 0.0)
			angular_velocity *= 0.35
			is_thrown_projectile = false
			break


func _on_body_entered(_body: Node) -> void:
	if not multiplayer.is_server():
		return
	if is_thrown_projectile and _thrown_grace_time > 0.06 and linear_velocity.length() < 6.0:
		is_thrown_projectile = false


@rpc("authority", "call_local", "reliable")
func _play_thrown_impact_fx(pos: Vector3, sfx_id: String) -> void:
	SfxManager.play_3d(sfx_id, pos, 0.08, 2.0)
	VfxHelper.spawn_hit_sparks(get_tree().current_scene, pos, Color(1.0, 0.78, 0.32), 24, 1.3)


@rpc("authority", "unreliable_ordered")
func _client_sync_xform(pos: Vector3, rot: Quaternion, thrown_state: bool) -> void:
	if multiplayer.is_server():
		return
	_net_target_pos = pos
	_net_target_rot = rot
	_has_net_target = true
	is_thrown_projectile = thrown_state
