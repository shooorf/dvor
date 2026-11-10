extends Node3D
## Стартовый уровень-песочница: «Лесная Цитадель» (замкнутая арена без обрывов).
## По периметру уровень полностью закрыт крепостными стенами, башнями и непролазными лесными зарослями.

const MAX_SANDBOX_ENTITIES: int = 120

var _players_root: Node3D = null
var _entities_root: Node3D = null
var _player_spawner: MultiplayerSpawner = null
var _entity_spawner: MultiplayerSpawner = null
var _entity_seq: int = 100

var _spawn_points: Array[Vector3] = [
	Vector3(-8.0, 1.2, 8.0),
	Vector3(8.0, 1.2, 8.0),
	Vector3(-8.0, 1.2, -8.0),
	Vector3(8.0, 1.2, -8.0),
	Vector3(-15.5, 4.4, 0.0),
	Vector3(15.5, 4.4, 0.0),
	Vector3(0.0, 1.2, 10.5),
	Vector3(0.0, 1.5, -23.5),
]


func _ready() -> void:
	_players_root = $Players
	_entities_root = $Entities
	_player_spawner = $PlayerSpawner
	_entity_spawner = $EntitySpawner
	_player_spawner.spawn_function = _spawn_player_callback
	_entity_spawner.spawn_function = _spawn_entity_callback

	_build_environment_and_lighting()
	_build_citadel_geometry()

	var hud := GameHUD.new()
	hud.name = "GameHUD"
	add_child(hud)

	if not NetworkManager.is_joining_client and multiplayer.is_server():
		_server_populate_baseline_objects()
		for pid in NetworkManager.players.keys():
			server_ensure_player_spawned(int(pid))


func _spawn_player_callback(data: Dictionary) -> Node:
	var pc := PlayerCharacter.new()
	pc.setup_from_spawn_data(data)
	return pc


func _spawn_entity_callback(data: Dictionary) -> Node:
	var kind := String(data.get("kind", "prop"))
	match kind:
		"weapon":
			var ww := WorldWeapon.new()
			ww.setup_from_spawn_data(data)
			return ww
		"dummy":
			var dm := PracticeDummy.new()
			dm.setup_from_spawn_data(data)
			return dm
		_:
			var pp := PhysicsProp.new()
			pp.setup_from_spawn_data(data)
			return pp


# ============================================================================
# ОСВЕЩЕНИЕ И ОКРУЖЕНИЕ (ПОД RTX 4070 FORWARD+)
# ============================================================================

func _build_environment_and_lighting() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()

	var sky := Sky.new()
	var hdri := AssetCatalog.load_sky_hdri()
	if hdri != null:
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = hdri
		sky_mat.energy_multiplier = 1.05
		sky.sky_material = sky_mat
	else:
		var proc_sky := ProceduralSkyMaterial.new()
		proc_sky.sky_top_color = Color(0.18, 0.34, 0.62)
		proc_sky.sky_horizon_color = Color(0.88, 0.62, 0.42)
		proc_sky.ground_horizon_color = Color(0.32, 0.38, 0.24)
		proc_sky.ground_bottom_color = Color(0.12, 0.14, 0.10)
		sky.sky_material = proc_sky

	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.86, 0.70)
	sun.light_energy = 2.15
	sun.light_angular_distance = 0.65
	sun.rotation_degrees = Vector3(-34.0, 38.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	if DisplayServer.get_name() != "headless":
		var probe := ReflectionProbe.new()
		probe.size = Vector3(64.0, 26.0, 78.0)
		probe.position = Vector3(0.0, 6.0, -8.0)
		probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		add_child(probe)

	GraphicsSettings.register_scene_lighting(env, sun)


# ============================================================================
# АРХИТЕКТУРА УРОВНЯ: ЗАМКНУТЫЙ ДВОР ЦИТАДЕЛИ + НЕПРОЛАЗНАЯ ЛЕСНАЯ ЧАЩА
# ============================================================================

func _build_citadel_geometry() -> void:
	var geo := Node3D.new()
	geo.name = "StaticArchitecture"
	add_child(geo)

	var mat_cobble := AssetCatalog.get_pbr_material("cobblestone_05", Vector3(0.22, 0.22, 0.22), true)
	var mat_brick := AssetCatalog.get_pbr_material("castle_brick_07", Vector3(0.24, 0.24, 0.24), true)
	var mat_stone := AssetCatalog.get_pbr_material("old_stone_wall_02", Vector3(0.25, 0.25, 0.25), true)
	var mat_grass := AssetCatalog.get_pbr_material("aerial_grass_rock", Vector3(0.16, 0.16, 0.16), true)
	var mat_wood := AssetCatalog.get_pbr_material("brown_planks_03", Vector3(0.32, 0.32, 0.32), true)
	var mat_metal := AssetCatalog.get_pbr_material("metal_plate", Vector3(0.35, 0.35, 0.35), true)

	# 1. Сплошная твёрдая земля всей долины (140x140 м) — НИКАКИХ обрывов или пустот на карте!
	_add_static_box(geo, Vector3(140.0, 4.0, 140.0), Vector3(0.0, -2.02, -8.0), Vector3.ZERO, mat_grass)

	# 2. Каменная брусчатка главного двора крепости (40.4 x 30.0 м)
	_add_static_box(geo, Vector3(40.4, 2.0, 30.0), Vector3(0.0, -0.98, 1.5), Vector3.ZERO, mat_cobble)

	# Каменное кольцо вокруг центральной жаровни
	_add_static_cylinder(geo, 3.1, 3.5, 0.22, Vector3(0.0, 0.11, 0.0), mat_stone)

	# 3. Западный и Восточный верхние бастионы (высота +3.2 м)
	_add_static_box(geo, Vector3(7.5, 3.2, 27.6), Vector3(-16.5, 1.6, 1.8), Vector3.ZERO, mat_brick)
	_add_static_box(geo, Vector3(7.5, 3.2, 27.6), Vector3(16.5, 1.6, 1.8), Vector3.ZERO, mat_brick)

	# Торцевые каменные парапеты на северном крае бастионов + угловые сторожевые башни
	_add_static_box(geo, Vector3(7.5, 1.4, 0.9), Vector3(-16.5, 3.9, -11.6), Vector3.ZERO, mat_stone)
	_add_static_box(geo, Vector3(7.5, 1.4, 0.9), Vector3(16.5, 3.9, -11.6), Vector3.ZERO, mat_stone)
	_add_static_cylinder(geo, 1.9, 2.1, 8.6, Vector3(-19.6, 4.3, -12.4), mat_brick)
	_add_static_cylinder(geo, 1.9, 2.1, 8.6, Vector3(19.6, 4.3, -12.4), mat_brick)

	# Широкие ступенчатые пандусы на бастионы
	_add_static_box(geo, Vector3(6.2, 0.5, 5.5), Vector3(-10.8, 1.45, -6.2), Vector3(0.0, 0.0, -29.5), mat_stone)
	_add_static_box(geo, Vector3(6.2, 0.5, 5.5), Vector3(-10.8, 1.45, 7.2), Vector3(0.0, 0.0, -29.5), mat_stone)
	_add_static_box(geo, Vector3(6.2, 0.5, 5.5), Vector3(10.8, 1.45, -6.2), Vector3(0.0, 0.0, 29.5), mat_stone)
	_add_static_box(geo, Vector3(6.2, 0.5, 5.5), Vector3(10.8, 1.45, 7.2), Vector3(0.0, 0.0, 29.5), mat_stone)

	# 4. ВНЕШНИЕ КРЕПОСТНЫЕ СТЕНЫ (Запад, Восток, Юг) + высокий коллайдер до y=20м
	# Западная и Восточная куртины
	_add_static_box(geo, Vector3(1.6, 7.2, 29.6), Vector3(-20.2, 3.6, 1.8), Vector3.ZERO, mat_brick)
	_add_static_box(geo, Vector3(1.6, 7.2, 29.6), Vector3(20.2, 3.6, 1.8), Vector3.ZERO, mat_brick)
	_add_invisible_blocker(geo, Vector3(2.0, 20.0, 30.0), Vector3(-20.4, 10.0, 1.8), 0.0)
	_add_invisible_blocker(geo, Vector3(2.0, 20.0, 30.0), Vector3(20.4, 10.0, 1.8), 0.0)

	for i in range(-6, 7):
		var z_crenel := 1.8 + float(i) * 2.15
		_add_static_box(geo, Vector3(1.7, 0.95, 1.15), Vector3(-20.2, 7.65, z_crenel), Vector3.ZERO, mat_stone)
		_add_static_box(geo, Vector3(1.7, 0.95, 1.15), Vector3(20.2, 7.65, z_crenel), Vector3.ZERO, mat_stone)

	# Южная крепостная стена и запертые окованные ворота цитадели (полностью закрывают южный край)
	_add_static_box(geo, Vector3(42.4, 6.8, 1.8), Vector3(0.0, 3.4, 16.0), Vector3.ZERO, mat_brick)
	_add_invisible_blocker(geo, Vector3(43.0, 20.0, 2.2), Vector3(0.0, 10.0, 16.2), 0.0)
	for i in range(-9, 10):
		_add_static_box(geo, Vector3(1.2, 0.95, 1.9), Vector3(float(i) * 2.15, 7.25, 16.0), Vector3.ZERO, mat_stone)

	# Надвратные башни и массивные дубовые ворота на южной стене
	_add_static_cylinder(geo, 1.55, 1.75, 8.6, Vector3(-4.0, 4.3, 15.1), mat_stone)
	_add_static_cylinder(geo, 1.55, 1.75, 8.6, Vector3(4.0, 4.3, 15.1), mat_stone)
	_add_static_box(geo, Vector3(5.8, 5.2, 0.55), Vector3(0.0, 2.6, 15.1), Vector3.ZERO, mat_wood)
	_add_static_box(geo, Vector3(5.9, 0.32, 0.68), Vector3(0.0, 1.5, 15.05), Vector3.ZERO, mat_metal)
	_add_static_box(geo, Vector3(5.9, 0.32, 0.68), Vector3(0.0, 3.6, 15.05), Vector3.ZERO, mat_metal)
	_add_static_box(geo, Vector3(8.8, 1.2, 1.8), Vector3(0.0, 5.8, 15.1), Vector3.ZERO, mat_stone)

	# Угловые южные башни
	_add_static_cylinder(geo, 2.0, 2.2, 9.0, Vector3(-19.8, 4.5, 15.8), mat_brick)
	_add_static_cylinder(geo, 2.0, 2.2, 9.0, Vector3(19.8, 4.5, 15.8), mat_brick)

	# Колонны во дворе для укрытий
	for pc in [
		Vector3(-6.8, 0.0, -6.8),
		Vector3(6.8, 0.0, -6.8),
		Vector3(-6.8, 0.0, 6.8),
		Vector3(6.8, 0.0, 6.8),
	]:
		_add_static_box(geo, Vector3(1.4, 0.45, 1.4), pc + Vector3(0.0, 0.225, 0.0), Vector3.ZERO, mat_stone)
		_add_static_cylinder(geo, 0.52, 0.56, 4.6, pc + Vector3(0.0, 2.5, 0.0), mat_brick)
		_add_static_box(geo, Vector3(1.5, 0.4, 1.5), pc + Vector3(0.0, 4.9, 0.0), Vector3.ZERO, mat_stone)

	# 5. Северная лесная поляна руин (на сплошной земле без пропастей)
	# Каменная дорожка и деревянный настил через травяную ложбину к древнему алтарю оружия
	_add_static_box(geo, Vector3(4.8, 0.14, 11.0), Vector3(0.0, 0.05, -18.5), Vector3.ZERO, mat_wood)
	_add_static_box(geo, Vector3(0.32, 0.28, 11.0), Vector3(-2.35, 0.14, -18.5), Vector3.ZERO, mat_stone)
	_add_static_box(geo, Vector3(0.32, 0.28, 11.0), Vector3(2.35, 0.14, -18.5), Vector3.ZERO, mat_stone)

	# Круглый каменный помост алтаря на поляне
	_add_static_cylinder(geo, 7.2, 7.6, 0.36, Vector3(0.0, 0.18, -27.2), mat_cobble)
	_add_static_box(geo, Vector3(1.1, 4.8, 1.1), Vector3(-3.2, 2.4, -30.8), Vector3.ZERO, mat_brick)
	_add_static_box(geo, Vector3(1.1, 4.8, 1.1), Vector3(3.2, 2.4, -30.8), Vector3.ZERO, mat_brick)
	_add_static_box(geo, Vector3(8.2, 1.0, 1.4), Vector3(0.0, 5.2, -30.8), Vector3.ZERO, mat_stone)

	# Пьедесталы оружия
	for ped_pos in [
		Vector3(-4.5, 0.0, 0.0),
		Vector3(4.5, 0.0, 0.0),
		Vector3(-15.5, 3.2, -5.0),
		Vector3(15.5, 3.2, -5.0),
		Vector3(0.0, 0.36, -27.2),
	]:
		_add_static_cylinder(geo, 0.65, 0.78, 0.48, ped_pos + Vector3(0.0, 0.24, 0.0), mat_stone)

	# 6. НЕПРОЛАЗНЫЕ ЛЕСНЫЕ ЗАРОСЛИ И ВАЛУНЫ (герметично замыкают всю северную чашу от Западной до Восточной стены)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261110
	var thicket_chain: Array[Vector2] = [
		Vector2(-19.8, -12.4),
		Vector2(-19.0, -22.0),
		Vector2(-14.2, -29.8),
		Vector2(-6.2, -33.4),
		Vector2(6.2, -33.4),
		Vector2(14.2, -29.8),
		Vector2(19.0, -22.0),
		Vector2(19.8, -12.4),
	]
	for idx in range(thicket_chain.size() - 1):
		_build_impassable_thicket_segment(geo, thicket_chain[idx], thicket_chain[idx + 1], rng)

	# Фоновый густой лес вокруг внешних стен крепости (чтобы за зубцами стен возвышались кроны деревьев)
	_populate_outer_forest_ring(geo, rng)

	# Настенные фонари на колоннах и у ворот для тёплых бликов на брусчатке
	for lp in [
		Vector3(-6.1, 2.7, -6.1),
		Vector3(6.1, 2.7, -6.1),
		Vector3(-6.1, 2.7, 6.1),
		Vector3(6.1, 2.7, 6.1),
		Vector3(-3.2, 3.4, 14.1),
		Vector3(3.2, 3.4, 14.1),
	]:
		var lant := AssetCatalog.instantiate_model("res://assets/downloaded/models/wooden_lantern_01/model.gltf")
		if lant != null:
			lant.position = lp
			geo.add_child(lant)
		var olight := OmniLight3D.new()
		olight.light_color = Color(1.0, 0.68, 0.32)
		olight.light_energy = 1.85
		olight.omni_range = 10.5
		olight.position = lp + Vector3(0.0, 0.1, 0.0)
		geo.add_child(olight)


func _build_impassable_thicket_segment(parent: Node3D, p_from: Vector2, p_to: Vector2, rng: RandomNumberGenerator) -> void:
	var delta2 := p_to - p_from
	var seg_len := delta2.length()
	var dir2 := delta2 / maxf(seg_len, 0.001)
	# Вектор наружу от центра поляны (0, -22)
	var mid2 := (p_from + p_to) * 0.5
	var outward2 := (mid2 - Vector2(0.0, -21.0)).normalized()
	var yaw := atan2(delta2.x, delta2.y)

	# Сплошная физическая преграда высотой 20 м вдоль кромки зарослей (с перехлёстом 1.8 м на стыках)
	var wall_center := Vector3(mid2.x + outward2.x * 0.7, 10.0, mid2.y + outward2.y * 0.7)
	_add_invisible_blocker(parent, Vector3(2.2, 20.0, seg_len + 1.8), wall_center, yaw)

	# Первый плотный ряд кустарников, папоротников и мшистых валунов прямо перед коллайдером
	var steps := maxi(2, int(ceil(seg_len / 1.65)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pt := p_from.lerp(p_to, t)

		var shrub := AssetCatalog.instantiate_model("res://assets/downloaded/models/shrub_02/model.gltf")
		if shrub != null:
			var sc := rng.randf_range(1.45, 1.95)
			shrub.scale = Vector3(sc, sc * 1.15, sc)
			shrub.position = Vector3(pt.x, 0.25, pt.y)
			shrub.rotation.y = rng.randf() * TAU
			parent.add_child(shrub)

		var bush_path := "res://assets/downloaded/nature/Bush_1.glb" if (i % 2 == 0) else "res://assets/downloaded/nature/BushBerries_1.glb"
		var bush := AssetCatalog.instantiate_model(bush_path)
		if bush != null:
			var bsc := rng.randf_range(1.85, 2.55)
			bush.scale = Vector3(bsc, bsc, bsc)
			bush.position = Vector3(pt.x + outward2.x * 0.55, 0.0, pt.y + outward2.y * 0.55)
			bush.rotation.y = rng.randf() * TAU
			parent.add_child(bush)

		if i % 2 == 0:
			var fern := AssetCatalog.instantiate_model("res://assets/downloaded/models/fern_02/model.gltf")
			if fern != null:
				var fsc := rng.randf_range(1.7, 2.3)
				fern.scale = Vector3(fsc, fsc, fsc)
				fern.position = Vector3(pt.x - outward2.x * 0.55, 0.02, pt.y - outward2.y * 0.55)
				fern.rotation.y = rng.randf() * TAU
				parent.add_child(fern)

		if i % 3 == 0:
			var rock := AssetCatalog.instantiate_model("res://assets/downloaded/models/boulder_01/model.gltf")
			if rock != null:
				rock.scale = Vector3(rng.randf_range(1.4, 2.1), rng.randf_range(1.3, 2.0), rng.randf_range(1.4, 2.1))
				rock.position = Vector3(pt.x + outward2.x * 0.35, 0.0, pt.y + outward2.y * 0.35)
				rock.rotation.y = rng.randf() * TAU
				parent.add_child(rock)

		# Высокие деревья в два эшелона позади кустарника (создают непроглядную лесную стену)
		if i % 2 == 0:
			var tree_paths := [
				"res://assets/downloaded/nature/PineTree_1.glb",
				"res://assets/downloaded/nature/CommonTree_1.glb",
				"res://assets/downloaded/nature/Willow_1.glb",
			]
			var tpath: String = tree_paths[(i + int(absf(pt.x))) % tree_paths.size()]
			var tree := AssetCatalog.instantiate_model(tpath)
			if tree != null:
				var tsc := rng.randf_range(3.3, 4.6)
				tree.scale = Vector3(tsc, tsc, tsc)
				tree.position = Vector3(pt.x + outward2.x * 2.4, 0.0, pt.y + outward2.y * 2.4)
				tree.rotation.y = rng.randf() * TAU
				parent.add_child(tree)

			var back_tree := AssetCatalog.instantiate_model(tree_paths[(i + 1) % tree_paths.size()])
			if back_tree != null:
				var btsc := rng.randf_range(4.0, 5.4)
				back_tree.scale = Vector3(btsc, btsc, btsc)
				var tang := Vector2(-dir2.y, dir2.x) * rng.randf_range(-1.5, 1.5)
				back_tree.position = Vector3(pt.x + outward2.x * 6.2 + tang.x, 0.0, pt.y + outward2.y * 6.2 + tang.y)
				back_tree.rotation.y = rng.randf() * TAU
				parent.add_child(back_tree)


func _populate_outer_forest_ring(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var tree_paths := [
		"res://assets/downloaded/nature/PineTree_1.glb",
		"res://assets/downloaded/nature/CommonTree_1.glb",
		"res://assets/downloaded/nature/Willow_1.glb",
	]
	for i in range(28):
		var angle := (float(i) / 28.0) * TAU
		var radius := rng.randf_range(25.5, 34.0)
		var center := Vector2(0.0, -4.0) + Vector2(cos(angle), sin(angle)) * radius
		# Не ставим деревья внутрь самой арены
		if absf(center.x) < 22.5 and center.y > -35.0 and center.y < 18.5:
			continue
		var tpath: String = tree_paths[i % tree_paths.size()]
		var tr := AssetCatalog.instantiate_model(tpath)
		if tr != null:
			var sc := rng.randf_range(3.8, 5.6)
			tr.scale = Vector3(sc, sc, sc)
			tr.position = Vector3(center.x, 0.0, center.y)
			tr.rotation.y = rng.randf() * TAU
			parent.add_child(tr)


func _add_invisible_blocker(parent: Node3D, sz: Vector3, pos: Vector3, yaw_rad: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation.y = yaw_rad

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col.shape = shape
	sb.add_child(col)
	parent.add_child(sb)


func _add_static_box(parent: Node3D, sz: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation_degrees = rot_deg

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col.shape = shape
	sb.add_child(col)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = sz
	mesh.material = mat
	mi.mesh = mesh
	sb.add_child(mi)

	parent.add_child(sb)


func _add_static_cylinder(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos

	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = maxf(r_top, r_bot)
	shape.height = h
	col.shape = shape
	sb.add_child(col)

	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = 24
	mesh.material = mat
	mi.mesh = mesh
	sb.add_child(mi)

	parent.add_child(sb)


# ============================================================================
# СЕРВЕРНЫЙ СПАВН ИГРОКОВ И ИНТЕРАКТИВНОГО НАПОЛНЕНИЯ
# ============================================================================

func get_random_spawn_point() -> Vector3:
	return _spawn_points[randi() % _spawn_points.size()]


func server_ensure_player_spawned(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var node_name := "Player_%d" % peer_id
	if _players_root.has_node(node_name):
		return

	var pinfo: Dictionary = NetworkManager.players.get(peer_id, {})
	var idx := (peer_id - 1) % _spawn_points.size()
	var sp := _spawn_points[idx]
	var yaw := atan2(-sp.x, -sp.z)

	var data := {
		"peer_id": peer_id,
		"name": String(pinfo.get("name", "Боец_%d" % peer_id)),
		"char_class": String(pinfo.get("char_class", "knight")),
		"color": pinfo.get("color", Color(0.25, 0.62, 0.96)),
		"pos": sp,
		"yaw": yaw,
	}
	_player_spawner.spawn(data)


func server_despawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var node := _players_root.get_node_or_null("Player_%d" % peer_id)
	if node != null:
		node.queue_free()


func _next_entity_name(prefix: String) -> String:
	_entity_seq += 1
	return "%s_%d" % [prefix, _entity_seq]


func server_spawn_world_weapon(
	weapon_id: String,
	pos: Vector3,
	initial_vel: Vector3 = Vector3.ZERO,
	is_thrown: bool = false,
	thrower_id: int = 0
) -> Node:
	if not multiplayer.is_server():
		return null
	_server_trim_entities_if_needed()
	var ang := Vector3(14.0, 3.0, 5.0) if is_thrown else Vector3.ZERO
	var data := {
		"kind": "weapon",
		"name": _next_entity_name("Wpn"),
		"weapon_id": weapon_id,
		"pos": pos,
		"rot": Vector3(0.0, randf() * TAU, 0.25 if not is_thrown else 0.0),
		"vel": initial_vel,
		"ang_vel": ang,
		"thrown": is_thrown,
		"thrower_id": thrower_id,
	}
	return _entity_spawner.spawn(data)


func server_spawn_random_loot_weapon(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var pool := ["warhammer_2h", "claymore_2h", "mace_1h", "axe_1h", "sword_1h", "club_1h"]
	var wid: String = pool[randi() % pool.size()]
	server_spawn_world_weapon(wid, pos, Vector3(randf_range(-2.0, 2.0), 5.5, randf_range(-2.0, 2.0)), false, 0)


func server_spawn_prop(prop_type: String, pos: Vector3, yaw: float = 0.0) -> Node:
	if not multiplayer.is_server():
		return null
	_server_trim_entities_if_needed()
	var data := {
		"kind": "prop",
		"name": _next_entity_name("Prop"),
		"prop_type": prop_type,
		"pos": pos,
		"rot": Vector3(0.0, yaw, 0.0),
	}
	return _entity_spawner.spawn(data)


func server_spawn_dummy(pos: Vector3, yaw: float = 0.0) -> Node:
	if not multiplayer.is_server():
		return null
	_server_trim_entities_if_needed()
	var data := {
		"kind": "dummy",
		"name": _next_entity_name("Dummy"),
		"pos": pos,
		"rot": Vector3(0.0, yaw, 0.0),
	}
	return _entity_spawner.spawn(data)


func _server_trim_entities_if_needed() -> void:
	if _entities_root.get_child_count() < MAX_SANDBOX_ENTITIES:
		return
	for ch in _entities_root.get_children():
		if ch is WorldWeapon or (ch is PhysicsProp and not (ch as PhysicsProp).is_static_structure and (ch as PhysicsProp).held_by_peer_id == 0):
			ch.queue_free()
			break


func _server_populate_baseline_objects() -> void:
	# Центральная огненная жаровня
	server_spawn_prop("fire_pit", Vector3(0.0, 0.22, 0.0))

	# Пружинные трамплины для запрыгивания на бастионы и манёвров в бою
	server_spawn_prop("launchpad", Vector3(0.0, 0.0, 10.8), PI)
	server_spawn_prop("launchpad", Vector3(0.0, 0.15, -22.8), 0.0)

	# Арсенал оружия на пьедесталах и в ключевых точках арены
	server_spawn_world_weapon("sword_1h", Vector3(-4.5, 0.9, 0.0))
	server_spawn_world_weapon("mace_1h", Vector3(4.5, 0.9, 0.0))
	server_spawn_world_weapon("club_1h", Vector3(-3.2, 0.6, 5.5))
	server_spawn_world_weapon("axe_1h", Vector3(3.2, 0.6, 5.5))
	server_spawn_world_weapon("claymore_2h", Vector3(-15.5, 4.1, -5.0))
	server_spawn_world_weapon("axe_1h", Vector3(15.5, 4.1, -5.0))
	server_spawn_world_weapon("warhammer_2h", Vector3(0.0, 1.25, -27.2))

	# Интерактивные ящики, бочки, пороховые бочки, валуны и сундук с оружием
	server_spawn_prop("wooden_crate", Vector3(-9.5, 0.2, 2.0), 0.3)
	server_spawn_prop("wooden_crate", Vector3(-9.5, 0.8, 2.0), -0.2)
	server_spawn_prop("wooden_crate", Vector3(9.5, 0.2, -2.5), 0.5)
	server_spawn_prop("wine_barrel", Vector3(9.2, 0.2, 3.2))
	server_spawn_prop("wine_barrel", Vector3(-14.8, 3.4, 4.5))
	server_spawn_prop("explosive_barrel", Vector3(-4.8, 0.2, -9.5))
	server_spawn_prop("explosive_barrel", Vector3(14.8, 3.4, 3.8))
	server_spawn_prop("boulder", Vector3(5.2, 0.3, -9.2))
	server_spawn_prop("treasure_chest", Vector3(0.0, 0.55, -29.2), 0.0)

	# Тренировочные манекены (у каменной стены и на лесной поляне — для отработки пинков в стену и костёр!)
	server_spawn_dummy(Vector3(0.0, 0.2, 12.6), PI)
	server_spawn_dummy(Vector3(6.2, 0.2, 1.5), -PI * 0.5)


@rpc("any_peer", "call_local", "reliable")
func request_sandbox_spawn(item_id: String, desired_pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var safe_pos := _clamp_inside_arena(desired_pos)

	# Привязка к полу лучом вниз для аккуратной установки построек
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(safe_pos + Vector3(0.0, 4.0, 0.0), safe_pos + Vector3(0.0, -8.0, 0.0), 1)
	var hit := space.intersect_ray(rq)
	var ground_pos := Vector3(safe_pos.x, float(hit["position"].y) if not hit.is_empty() else maxf(0.0, safe_pos.y), safe_pos.z)

	if item_id.begins_with("weapon:"):
		var wid := item_id.trim_prefix("weapon:")
		if AssetCatalog.WEAPON_DEFS.has(wid):
			server_spawn_world_weapon(wid, ground_pos + Vector3(0.0, 0.65, 0.0))
	elif item_id.begins_with("prop:"):
		var ptype := item_id.trim_prefix("prop:")
		var y_lift := 0.02 if ptype in ["launchpad", "wood_ramp", "fire_pit", "lantern_post", "thicket_hedge"] else 0.35
		server_spawn_prop(ptype, ground_pos + Vector3(0.0, y_lift, 0.0), yaw)
	elif item_id.begins_with("dummy:"):
		server_spawn_dummy(ground_pos + Vector3(0.0, 0.20, 0.0), yaw + PI)


func _clamp_inside_arena(pos: Vector3) -> Vector3:
	var out := pos
	out.x = clampf(out.x, -17.8, 17.8)
	out.y = clampf(out.y, 0.0, 12.0)
	out.z = clampf(out.z, -30.5, 13.8)
	# Сужение в северной лесной дуге зарослей
	if out.z < -20.0:
		var z_factor := clampf((-out.z - 20.0) / 11.0, 0.0, 1.0)
		var max_x := lerpf(17.0, 10.0, z_factor)
		out.x = clampf(out.x, -max_x, max_x)
	return out


@rpc("any_peer", "call_local", "reliable")
func request_reset_arena_props() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 and sender != 0:
		return
	for ch in _entities_root.get_children():
		ch.queue_free()
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_server_populate_baseline_objects()
			NetworkManager.broadcast_event("Хост перезагрузил объекты арены!", Color(0.45, 0.88, 1.0))
	)
