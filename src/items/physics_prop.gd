class_name PhysicsProp
extends RigidBody3D
## Интерактивный сетевой объект песочницы: ящики, обычные и взрывные бочки, валуны, сундуки,
## пружинные трамплины, рампы, огненные жаровни и фонари.

var prop_type: String = "wooden_crate"
var max_hp: float = 60.0
var hp: float = 60.0
var destructible: bool = true
var grabbable: bool = true
var is_static_structure: bool = false
var display_title: String = "Деревянный ящик"
var throw_speed_mult: float = 1.0

var held_by_peer_id: int = 0
var last_pusher_id: int = 0
var _lethal_timer: float = 0.0
var _hit_cooldown_ids: Dictionary = {}
var _exploded: bool = false

var _net_target_pos: Vector3 = Vector3.ZERO
var _net_target_rot: Quaternion = Quaternion.IDENTITY
var _has_net_target: bool = false
var _sync_accum: float = 0.0
var _hazard_accum: float = 0.0
var _hazard_area: Area3D = null


func setup_from_spawn_data(data: Dictionary) -> void:
	name = String(data.get("name", "Prop_%d" % Time.get_ticks_usec()))
	prop_type = String(data.get("prop_type", "wooden_crate"))
	position = data.get("pos", Vector3.ZERO)
	rotation = data.get("rot", Vector3.ZERO)


func _ready() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	_configure_by_type()
	body_entered.connect(_on_body_entered)

	if is_static_structure:
		collision_layer = 1
		collision_mask = 0
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
	else:
		collision_layer = 4
		collision_mask = 1 | 4
		if not multiplayer.is_server():
			freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			freeze = true
			_net_target_pos = global_position
			_net_target_rot = global_transform.basis.get_rotation_quaternion()
			_has_net_target = true


func _configure_by_type() -> void:
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.82
	phys_mat.bounce = 0.18

	match prop_type:
		"wooden_crate":
			display_title = "Деревянный ящик"
			mass = 15.0
			max_hp = 50.0
			destructible = true
			grabbable = true
			throw_speed_mult = 1.05
			_add_box_collider(Vector3(1.08, 0.48, 0.56), Vector3(0.0, 0.24, 0.0))
			_add_gltf_or_box("res://assets/downloaded/models/wooden_crate_01/model.gltf", Vector3(1.32, 1.35, 1.35), Vector3.ZERO, Vector3(1.08, 0.48, 0.56), "brown_planks_03")

		"wine_barrel":
			display_title = "Дубовая бочка"
			mass = 22.0
			max_hp = 80.0
			destructible = true
			grabbable = true
			throw_speed_mult = 0.98
			phys_mat.bounce = 0.28
			_add_cylinder_collider(0.38, 0.88, Vector3(0.0, 0.44, 0.0))
			_add_gltf_or_cyl("res://assets/downloaded/models/wine_barrel_01/model.gltf", Vector3.ONE, Vector3.ZERO, 0.38, 0.88, "brown_planks_03", Color.WHITE)

		"explosive_barrel":
			display_title = "Пороховая бочка"
			mass = 24.0
			max_hp = 26.0
			destructible = true
			grabbable = true
			throw_speed_mult = 0.96
			phys_mat.bounce = 0.24
			_add_cylinder_collider(0.39, 0.90, Vector3(0.0, 0.45, 0.0))
			_add_gltf_or_cyl("res://assets/downloaded/models/wine_barrel_01/model.gltf", Vector3(1.02, 1.02, 1.02), Vector3.ZERO, 0.39, 0.90, "brown_planks_03", Color(1.0, 0.35, 0.30))
			_add_explosive_band()

		"boulder":
			display_title = "Каменный валун"
			mass = 38.0
			max_hp = 9999.0
			destructible = false
			grabbable = true
			throw_speed_mult = 0.82
			phys_mat.bounce = 0.15
			var sph := CollisionShape3D.new()
			var s := SphereShape3D.new()
			s.radius = 0.34
			sph.shape = s
			sph.position = Vector3(0.0, 0.22, 0.0)
			add_child(sph)
			var rock := AssetCatalog.instantiate_model("res://assets/downloaded/models/boulder_01/model.gltf")
			if rock != null:
				rock.scale = Vector3(0.45, 0.45, 0.45)
				add_child(rock)
			else:
				var mi := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.34
				sm.height = 0.68
				sm.material = AssetCatalog.get_pbr_material("old_stone_wall_02")
				mi.mesh = sm
				mi.position = Vector3(0.0, 0.22, 0.0)
				add_child(mi)

		"treasure_chest":
			display_title = "Сундук с оружием"
			mass = 34.0
			max_hp = 85.0
			destructible = true
			grabbable = true
			throw_speed_mult = 0.85
			_add_box_collider(Vector3(0.96, 0.58, 0.76), Vector3(0.0, 0.22, 0.10))
			_add_gltf_or_box("res://assets/downloaded/models/treasure_chest/model.gltf", Vector3.ONE, Vector3(0.0, 0.17, 0.0), Vector3(0.96, 0.58, 0.76), "brown_planks_03")

		"launchpad":
			display_title = "Пружинный трамплин"
			is_static_structure = true
			destructible = false
			grabbable = false
			_build_launchpad()

		"wood_ramp":
			display_title = "Деревянная рампа"
			is_static_structure = true
			destructible = false
			grabbable = false
			_build_wood_ramp()

		"fire_pit":
			display_title = "Огненная жаровня"
			is_static_structure = true
			destructible = false
			grabbable = false
			_build_fire_pit()

		"lantern_post":
			display_title = "Фонарный столб"
			is_static_structure = true
			destructible = false
			grabbable = false
			_build_lantern_post()

		"thicket_hedge":
			display_title = "Непролазные заросли"
			is_static_structure = true
			destructible = false
			grabbable = false
			_build_thicket_hedge()

	hp = max_hp
	physics_material_override = phys_mat


func _add_box_collider(sz: Vector3, offset: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	col.shape = box
	col.position = offset
	add_child(col)


func _add_cylinder_collider(radius: float, height: float, offset: Vector3) -> void:
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	col.shape = cyl
	col.position = offset
	add_child(col)


func _add_gltf_or_box(path: String, scl: Vector3, offset: Vector3, fallback_sz: Vector3, fallback_tex: String) -> void:
	var mdl := AssetCatalog.instantiate_model(path)
	if mdl != null:
		mdl.scale = scl
		mdl.position = offset
		add_child(mdl)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = fallback_sz
		bm.material = AssetCatalog.get_pbr_material(fallback_tex)
		mi.mesh = bm
		mi.position = Vector3(0.0, fallback_sz.y * 0.5, 0.0)
		add_child(mi)


func _add_gltf_or_cyl(path: String, scl: Vector3, offset: Vector3, radius: float, height: float, fallback_tex: String, tint: Color) -> void:
	var mdl := AssetCatalog.instantiate_model(path)
	if mdl != null:
		mdl.scale = scl
		mdl.position = offset
		if tint != Color.WHITE:
			_tint_hierarchy(mdl, tint)
		add_child(mdl)
	else:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = height
		cm.material = AssetCatalog.get_pbr_material(fallback_tex, Vector3.ONE, true, tint)
		mi.mesh = cm
		mi.position = Vector3(0.0, height * 0.5, 0.0)
		add_child(mi)


func _tint_hierarchy(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var orig := mi.mesh.surface_get_material(0)
			if orig is StandardMaterial3D:
				var dup := (orig as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.albedo_color = tint
				mi.material_override = dup
	for ch in node.get_children():
		_tint_hierarchy(ch, tint)


func _add_explosive_band() -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.405
	cyl.bottom_radius = 0.405
	cyl.height = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.14, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.18, 0.05)
	mat.emission_energy_multiplier = 0.9
	mat.roughness = 0.4
	cyl.material = mat
	ring.mesh = cyl
	ring.position = Vector3(0.0, 0.45, 0.0)
	add_child(ring)


func _build_launchpad() -> void:
	_add_box_collider(Vector3(2.0, 0.28, 2.0), Vector3(0.0, 0.14, 0.0))
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.24, 2.0)
	bm.material = AssetCatalog.get_pbr_material("metal_plate", Vector3(0.5, 0.5, 0.5))
	base.mesh = bm
	base.position = Vector3(0.0, 0.12, 0.0)
	add_child(base)

	var glow_pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.78
	cyl.bottom_radius = 0.84
	cyl.height = 0.10
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.15, 0.85, 1.0)
	gmat.emission_enabled = true
	gmat.emission = Color(0.15, 0.78, 1.0)
	gmat.emission_energy_multiplier = 2.2
	cyl.material = gmat
	glow_pad.mesh = cyl
	glow_pad.position = Vector3(0.0, 0.25, 0.0)
	add_child(glow_pad)

	_hazard_area = Area3D.new()
	_hazard_area.collision_layer = 0
	_hazard_area.collision_mask = 2 | 4
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(1.65, 0.65, 1.65)
	acol.shape = abox
	acol.position = Vector3(0.0, 0.50, 0.0)
	_hazard_area.add_child(acol)
	add_child(_hazard_area)
	_hazard_area.body_entered.connect(_on_launchpad_entered)


func _build_wood_ramp() -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 0.82, 0.0)
	pivot.rotation_degrees = Vector3(-24.0, 0.0, 0.0)
	add_child(pivot)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 0.22, 4.2)
	bm.material = AssetCatalog.get_pbr_material("brown_planks_03", Vector3(0.6, 0.6, 0.6))
	mi.mesh = bm
	pivot.add_child(mi)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 0.22, 4.2)
	col.shape = bs
	col.position = pivot.position
	col.rotation_degrees = pivot.rotation_degrees
	add_child(col)


func _build_fire_pit() -> void:
	_add_cylinder_collider(0.72, 0.42, Vector3(0.0, 0.21, 0.0))
	_add_gltf_or_cyl("res://assets/downloaded/models/stone_fire_pit/model.gltf", Vector3.ONE, Vector3(0.0, 0.19, 0.0), 0.72, 0.42, "old_stone_wall_02", Color.WHITE)
	VfxHelper.attach_fire_effect(self, 3.2, 13.0, 1.15)

	_hazard_area = Area3D.new()
	_hazard_area.collision_layer = 0
	_hazard_area.collision_mask = 2 | 4
	var acol := CollisionShape3D.new()
	var acyl := CylinderShape3D.new()
	acyl.radius = 0.75
	acyl.height = 1.25
	acol.shape = acyl
	acol.position = Vector3(0.0, 0.65, 0.0)
	_hazard_area.add_child(acol)
	add_child(_hazard_area)


func _build_lantern_post() -> void:
	_add_cylinder_collider(0.14, 2.8, Vector3(0.0, 1.4, 0.0))
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.11
	pm.height = 2.8
	pm.material = AssetCatalog.get_pbr_material("brown_planks_03", Vector3(1.0, 1.0, 1.0))
	post.mesh = pm
	post.position = Vector3(0.0, 1.4, 0.0)
	add_child(post)

	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.10, 0.10, 0.65)
	am.material = AssetCatalog.get_pbr_material("metal_plate")
	arm.mesh = am
	arm.position = Vector3(0.0, 2.72, 0.25)
	add_child(arm)

	var lantern := AssetCatalog.instantiate_model("res://assets/downloaded/models/wooden_lantern_01/model.gltf")
	if lantern != null:
		lantern.position = Vector3(0.0, 2.38, 0.50)
		add_child(lantern)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.36)
	light.light_energy = 2.4
	light.omni_range = 12.0
	light.shadow_enabled = true
	light.position = Vector3(0.0, 2.35, 0.50)
	add_child(light)


func _build_thicket_hedge() -> void:
	_add_box_collider(Vector3(3.1, 2.8, 1.5), Vector3(0.0, 1.4, 0.0))
	var shrub := AssetCatalog.instantiate_model("res://assets/downloaded/models/shrub_02/model.gltf")
	if shrub != null:
		shrub.scale = Vector3(1.35, 1.45, 1.15)
		shrub.position = Vector3(0.0, 0.25, 0.0)
		add_child(shrub)
	for x_off in [-0.95, 0.95]:
		var bush := AssetCatalog.instantiate_model("res://assets/downloaded/nature/BushBerries_1.glb")
		if bush != null:
			bush.scale = Vector3(1.55, 1.65, 1.45)
			bush.position = Vector3(float(x_off), 0.0, 0.05)
			bush.rotation_degrees.y = 45.0 * float(x_off)
			add_child(bush)
	if shrub == null:
		var fallback := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 2.4, 1.4)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.18, 0.36, 0.14)
		gmat.roughness = 0.92
		bm.material = gmat
		fallback.mesh = bm
		fallback.position = Vector3(0.0, 1.2, 0.0)
		add_child(fallback)


func get_interaction_prompt() -> String:
	if not grabbable or held_by_peer_id != 0:
		return ""
	return "[E] Схватить: %s" % display_title


func can_be_grabbed() -> bool:
	return grabbable and not is_static_structure and held_by_peer_id == 0 and not _exploded


func server_grab(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	held_by_peer_id = peer_id
	last_pusher_id = peer_id
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	collision_layer = 0
	collision_mask = 0
	_set_held_state_rpc.rpc(peer_id)


func server_release_and_throw(release_pos: Vector3, throw_vel: Vector3, thrower_id: int) -> void:
	if not multiplayer.is_server():
		return
	held_by_peer_id = 0
	last_pusher_id = thrower_id
	_lethal_timer = 2.4
	_hit_cooldown_ids.clear()

	global_position = release_pos
	collision_layer = 4
	collision_mask = 1 | 4
	freeze = false
	linear_velocity = throw_vel * throw_speed_mult
	angular_velocity = Vector3(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0), randf_range(-5.0, 5.0))
	_set_held_state_rpc.rpc(0)
	_client_sync_xform.rpc(global_position, global_transform.basis.get_rotation_quaternion())


@rpc("authority", "call_local", "reliable")
func _set_held_state_rpc(carrier_id: int) -> void:
	held_by_peer_id = carrier_id
	if carrier_id != 0:
		collision_layer = 0
		collision_mask = 0
	elif not is_static_structure:
		collision_layer = 4
		collision_mask = 1 | 4


func _physics_process(delta: float) -> void:
	if is_static_structure:
		if multiplayer.is_server() and prop_type == "fire_pit" and _hazard_area != null:
			_hazard_accum += delta
			if _hazard_accum >= 0.45:
				_hazard_accum = 0.0
				_server_tick_fire_hazard()
		return

	if not multiplayer.is_server():
		if held_by_peer_id == 0 and _has_net_target:
			global_position = global_position.lerp(_net_target_pos, clampf(delta * 16.0, 0.0, 1.0))
			var cur_q := global_transform.basis.get_rotation_quaternion()
			global_transform.basis = Basis(cur_q.slerp(_net_target_rot, clampf(delta * 16.0, 0.0, 1.0)))
		return

	if global_position.y < -2.5:
		global_position = Vector3(clampf(global_position.x, -14.0, 14.0), 1.2, clampf(global_position.z, -24.0, 12.0))
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return

	if held_by_peer_id != 0:
		return

	if _lethal_timer > 0.0:
		_lethal_timer -= delta
		var speed := linear_velocity.length()
		if speed > 5.8:
			_server_sweep_flying_prop_hits(speed, delta)

	_sync_accum += delta
	if _sync_accum >= 0.05:
		_sync_accum = 0.0
		if not sleeping or _lethal_timer > 0.0:
			_client_sync_xform.rpc(global_position, global_transform.basis.get_rotation_quaternion())


func _server_sweep_flying_prop_hits(speed: float, delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 0.56
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sph
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.35, 0.0) + linear_velocity * delta * 0.5)
	query.collision_mask = 2 | 4
	query.exclude = [get_rid()]

	var hits := space.intersect_shape(query, 6)
	for h in hits:
		var collider: Object = h.get("collider")
		if collider == null or collider == self:
			continue
		var oid := collider.get_instance_id()
		if _hit_cooldown_ids.has(oid):
			continue
		if collider.has_method("get_peer_id") and int(collider.call("get_peer_id")) == last_pusher_id and _lethal_timer > 2.05:
			continue
		if collider.has_method("take_combat_hit"):
			_hit_cooldown_ids[oid] = true
			if prop_type == "explosive_barrel":
				_server_explode(last_pusher_id)
				return
			var dmg := clampf(speed * (mass / 11.0) * 2.1, 18.0, 72.0)
			var kb_dir := linear_velocity.normalized()
			kb_dir.y = maxf(kb_dir.y, 0.28)
			var kb := kb_dir.normalized() * clampf(speed * 0.95, 8.0, 20.0)
			collider.call("take_combat_hit", dmg, last_pusher_id, kb, global_position, display_title, false)
			linear_velocity *= 0.45
			if destructible:
				take_combat_hit(24.0, last_pusher_id, Vector3.ZERO, global_position, "Столкновение", true)
			break


func _on_body_entered(_body: Node) -> void:
	if not multiplayer.is_server() or _exploded:
		return
	var speed := linear_velocity.length()
	if prop_type == "explosive_barrel" and speed > 8.2 and _lethal_timer > 0.0:
		_server_explode(last_pusher_id)
	elif destructible and speed > 13.5 and _lethal_timer > 0.0:
		take_combat_hit(28.0, last_pusher_id, Vector3.ZERO, global_position, "Удар о стену", true)


func _on_launchpad_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if body == self:
		return
	var launch_dir := (-global_transform.basis.z * 0.35 + Vector3.UP).normalized()
	if body.has_method("apply_external_launch"):
		body.call("apply_external_launch", launch_dir * 16.5)
		_launchpad_fx_rpc.rpc(global_position + Vector3(0.0, 0.3, 0.0))
	elif body is RigidBody3D and not (body as RigidBody3D).freeze:
		(body as RigidBody3D).linear_velocity = launch_dir * 15.0
		_launchpad_fx_rpc.rpc(global_position + Vector3(0.0, 0.3, 0.0))


func _server_tick_fire_hazard() -> void:
	for body in _hazard_area.get_overlapping_bodies():
		if body == self:
			continue
		if body is PhysicsProp and (body as PhysicsProp).prop_type == "explosive_barrel":
			(body as PhysicsProp)._server_explode(0)
		elif body.has_method("take_combat_hit"):
			var up_push := Vector3(randf_range(-2.0, 2.0), 4.5, randf_range(-2.0, 2.0))
			body.call("take_combat_hit", 14.0, 0, up_push, global_position + Vector3(0.0, 0.4, 0.0), "Огненная жаровня", true)


func take_combat_hit(
	amount: float,
	attacker_id: int,
	knockback_vel: Vector3,
	hit_pos: Vector3,
	_cause_label: String,
	_is_unblockable: bool = false
) -> bool:
	if not multiplayer.is_server() or _exploded:
		return false

	if not is_static_structure and held_by_peer_id == 0 and knockback_vel.length() > 0.1:
		freeze = false
		linear_velocity += knockback_vel * clampf(22.0 / maxf(mass, 10.0), 0.55, 1.45)
		angular_velocity += Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
		last_pusher_id = attacker_id
		_lethal_timer = 2.0
		_hit_cooldown_ids.clear()

	if not destructible:
		_prop_hit_fx_rpc.rpc(hit_pos, "hit_blunt", false)
		return true

	hp -= amount
	if hp <= 0.0:
		if prop_type == "explosive_barrel":
			_server_explode(attacker_id)
		else:
			_server_shatter()
	else:
		_prop_hit_fx_rpc.rpc(hit_pos, "hit_blunt", true)
	return true


func _server_shatter() -> void:
	if _exploded:
		return
	_exploded = true
	if prop_type == "treasure_chest":
		var arena := get_tree().current_scene
		if arena != null and arena.has_method("server_spawn_random_loot_weapon"):
			arena.call("server_spawn_random_loot_weapon", global_position + Vector3(0.0, 0.65, 0.0))
	_prop_break_fx_rpc.rpc(global_position + Vector3(0.0, 0.35, 0.0))
	queue_free()


func _server_explode(instigator_id: int) -> void:
	if _exploded:
		return
	_exploded = true
	var center := global_position + Vector3(0.0, 0.45, 0.0)
	_explosion_fx_rpc.rpc(center)

	var space := get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 6.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sph
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 2 | 4
	query.exclude = [get_rid()]

	var hits := space.intersect_shape(query, 24)
	var seen: Dictionary = {}
	for h in hits:
		var col: Object = h.get("collider")
		if col == null or col == self or not (col is Node3D):
			continue
		var oid := col.get_instance_id()
		if seen.has(oid):
			continue
		seen[oid] = true
		var target_node := col as Node3D
		var delta_vec := (target_node.global_position + Vector3(0.0, 0.7, 0.0)) - center
		var dist := maxf(delta_vec.length(), 0.5)
		var falloff := clampf(1.0 - (dist / 7.2), 0.20, 1.0)
		var blast_dir := delta_vec.normalized()
		blast_dir.y = maxf(blast_dir.y + 0.45, 0.45)
		blast_dir = blast_dir.normalized()
		if col.has_method("take_combat_hit"):
			col.call(
				"take_combat_hit",
				88.0 * falloff,
				instigator_id,
				blast_dir * (21.0 * falloff),
				target_node.global_position + Vector3(0.0, 0.8, 0.0),
				"Пороховая бочка",
				true
			)

	queue_free()


@rpc("authority", "call_local", "reliable")
func _launchpad_fx_rpc(pos: Vector3) -> void:
	SfxManager.play_3d("pickup", pos, 0.06, 1.0)
	VfxHelper.spawn_hit_sparks(get_tree().current_scene, pos, Color(0.2, 0.9, 1.0), 16, 1.1)


@rpc("authority", "call_local", "reliable")
func _prop_hit_fx_rpc(pos: Vector3, sfx_id: String, wood_sparks: bool) -> void:
	SfxManager.play_3d(sfx_id, pos, 0.1)
	var col := Color(0.88, 0.68, 0.42) if wood_sparks else Color(0.85, 0.85, 0.85)
	VfxHelper.spawn_hit_sparks(get_tree().current_scene, pos, col, 12, 0.85)


@rpc("authority", "call_local", "reliable")
func _prop_break_fx_rpc(pos: Vector3) -> void:
	SfxManager.play_3d("wood_break", pos, 0.08, 2.0)
	VfxHelper.spawn_wood_debris(get_tree().current_scene, pos)


@rpc("authority", "call_local", "reliable")
func _explosion_fx_rpc(pos: Vector3) -> void:
	SfxManager.play_3d("explosion", pos, 0.05, 5.0)
	VfxHelper.spawn_explosion_vfx(get_tree().current_scene, pos)


@rpc("authority", "unreliable_ordered")
func _client_sync_xform(pos: Vector3, rot: Quaternion) -> void:
	if multiplayer.is_server():
		return
	_net_target_pos = pos
	_net_target_rot = rot
	_has_net_target = true
