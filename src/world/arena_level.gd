extends Node3D
## Реалистичный открытый уровень (180×180 м, x16 по площади от старой арены):
## Восточная Европа, конец августа — небольшой сельский посёлок из 7 открытых частных домов с дворами,
## сараями, колодцем, просёлочной грунтовой дорогой, ЛЭП с уличными фонарями, поляной с вечерним костром
## и большим смешанным лесом (берёзы, сосны, ели, валежник, извилистые тропинки и избушка лесника).
## По краям нет ни одного обрыва — периметр 100% замкнут заборами усадеб и непролазным лесным буреломом.

const MAX_SANDBOX_ENTITIES: int = 180

var _players_root: Node3D = null
var _entities_root: Node3D = null
var _player_spawner: MultiplayerSpawner = null
var _entity_spawner: MultiplayerSpawner = null
var _entity_seq: int = 100

var _spawn_points: Array[Vector3] = []


func _ready() -> void:
	_players_root = $Players
	_entities_root = $Entities
	_player_spawner = $PlayerSpawner
	_entity_spawner = $EntitySpawner
	_player_spawner.spawn_function = _spawn_player_callback
	_entity_spawner.spawn_function = _spawn_entity_callback

	_init_spawn_points()
	_build_environment_and_lighting()
	_build_eastern_european_world()

	var hud := GameHUD.new()
	hud.name = "GameHUD"
	add_child(hud)

	if not NetworkManager.is_joining_client and multiplayer.is_server():
		_server_populate_baseline_objects()
		for pid in NetworkManager.players.keys():
			server_ensure_player_spawned(int(pid))


func _ground_pt(x: float, z: float, y_offset: float = 0.55) -> Vector3:
	return Vector3(x, TerrainBuilder.get_height(x, z) + y_offset, z)


func _init_spawn_points() -> void:
	var coords: Array[Vector2] = [
		Vector2(8.5, -3.5),                                   # У поляны вечернего костра
		Vector2(18.5, -7.0),                                  # Восточный край поляны у лесной тропы
		Vector2(-18.5, -6.0),                                 # Просёлочная дорога у деревенского колодца
		Vector2(TerrainBuilder.get_road_center_x(18.0), 18.0),# Центральная улица посёлка
		Vector2(TerrainBuilder.get_road_center_x(46.0), 46.0),# Южная часть грунтовки между домами
		Vector2(TerrainBuilder.get_road_center_x(-30.0), -30.0), # Северная часть грунтовки
		Vector2(-38.0, 10.0),                                 # У калитки белёной хаты (Запад)
		Vector2(-12.0, 16.0),                                 # У калитки голубого дома (Восток)
		Vector2(31.0, -14.0),                                 # Развилка лесной тропинки
		Vector2(49.5, -19.5),                                 # Поляна у избушки лесника в чаще
		Vector2(43.0, 39.0),                                  # Юго-восточная лесная поляна с валунами
		Vector2(-24.0, -56.0),                                # Северная околица посёлка
	]
	_spawn_points.clear()
	for c in coords:
		_spawn_points.append(_ground_pt(c.x, c.y, 0.55))


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
# ОСВЕЩЕНИЕ И АТМОСФЕРА АВГУСТОВСКОГО ВЕЧЕРА (ПОД RTX 4070 FORWARD+)
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
		sky_mat.energy_multiplier = 1.02
		sky.sky_material = sky_mat
	else:
		var proc_sky := ProceduralSkyMaterial.new()
		proc_sky.sky_top_color = Color(0.24, 0.44, 0.72)
		proc_sky.sky_horizon_color = Color(0.94, 0.74, 0.52)
		proc_sky.ground_horizon_color = Color(0.36, 0.40, 0.26)
		proc_sky.ground_bottom_color = Color(0.14, 0.16, 0.11)
		sky.sky_material = proc_sky

	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.82
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world_env.environment = env
	add_child(world_env)

	# Низкое тёплое солнце конца августа (длинные мягкие тени от берёз, сосен и крыш домов)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 2.25
	sun.light_angular_distance = 0.65
	sun.rotation_degrees = Vector3(-24.0, -52.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	if DisplayServer.get_name() != "headless":
		var probe_village := ReflectionProbe.new()
		probe_village.name = "VillageReflectionProbe"
		probe_village.size = Vector3(110.0, 32.0, 180.0)
		probe_village.position = Vector3(-25.0, 8.0, 0.0)
		probe_village.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		add_child(probe_village)

		var probe_forest := ReflectionProbe.new()
		probe_forest.name = "ForestReflectionProbe"
		probe_forest.size = Vector3(105.0, 34.0, 180.0)
		probe_forest.position = Vector3(42.0, 9.0, 0.0)
		probe_forest.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		add_child(probe_forest)

	GraphicsSettings.register_scene_lighting(env, sun)


# ============================================================================
# ПОСТРОЕНИЕ РЕЛЬЕФА, ПОСЁЛКА, ДОРОГ И СМЕШАННОГО ЛЕСА (180×180 м)
# ============================================================================

func _build_eastern_european_world() -> void:
	var geo := Node3D.new()
	geo.name = "StaticArchitecture"
	add_child(geo)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260815

	# 1. Скульптурный рельеф 232×232 м с просёлочной грунтовкой, кюветами и лесными тропинками
	TerrainBuilder.build_terrain_node(geo)

	# 2. Частные дома (с открытыми комнатами и окнами), дворы, сараи, заборы, ЛЭП и замкнутый периметр
	VillageArchitecture.build_all(geo, rng)

	# 3. Ботанические деревья 4 пород, фотосканированные кусты/крапива/валежник и 56 000 пучков 3D-травы
	RealisticFoliage.populate_world_foliage(geo, rng)


# ============================================================================
# СЕРВЕРНЫЙ СПАВН ИГРОКОВ И ИНТЕРАКТИВНЫХ ПРЕДМЕТОВ ПЕСОЧНИЦЫ
# ============================================================================

func get_random_spawn_point() -> Vector3:
	if _spawn_points.is_empty():
		_init_spawn_points()
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
	# Смотрим по умолчанию в сторону центра карты / поляны костра
	var to_center := Vector3(0.0, sp.y, -4.0) - sp
	var yaw := atan2(-to_center.x, -to_center.z)

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
	# 1. Главный вечерний костёр на поляне у лесной опушки (с реалистичным шейдерным пламенем и дымом)
	server_spawn_prop("fire_pit", _ground_pt(14.0, -4.0, 0.02))
	# Второй небольшой костёр у лесной избушки лесника
	server_spawn_prop("fire_pit", _ground_pt(50.5, -22.0, 0.02))

	# 2. Оружие во дворах, у поленниц, у колодца, на поляне костра и в лесу
	server_spawn_world_weapon("axe_1h", _ground_pt(11.2, -1.8, 0.65))       # У брёвен костра
	server_spawn_world_weapon("sword_1h", _ground_pt(16.8, -6.2, 0.65))     # На поляне костра
	server_spawn_world_weapon("club_1h", _ground_pt(-13.2, -5.2, 0.65))     # У деревенского колодца
	server_spawn_world_weapon("mace_1h", _ground_pt(-21.5, 12.0, 0.65))     # На обочине улицы
	server_spawn_world_weapon("axe_1h", _ground_pt(-42.5, 11.5, 0.65))      # Во дворе хаты №2
	server_spawn_world_weapon("sword_1h", _ground_pt(-9.5, 17.5, 0.65))     # Во дворе дома №5
	server_spawn_world_weapon("claymore_2h", _ground_pt(-41.5, 49.0, 0.65)) # Юго-западный двор
	server_spawn_world_weapon("warhammer_2h", _ground_pt(-9.5, -27.0, 0.65))# Северо-восточный двор
	server_spawn_world_weapon("axe_1h", _ground_pt(52.0, -17.5, 0.65))      # У избушки лесника
	server_spawn_world_weapon("warhammer_2h", _ground_pt(45.0, 42.0, 0.65)) # Поляна валунов в лесу
	server_spawn_world_weapon("mace_1h", _ground_pt(30.5, -13.5, 0.65))     # Развилка лесной тропы
	server_spawn_world_weapon("club_1h", _ground_pt(-31.0, -60.0, 0.65))    # Северная околица

	# 3. Физические предметы для метания и взрывов (ящики, дубовые бочки, бочки с горючим, канистры, сундуки)
	server_spawn_prop("wooden_crate", _ground_pt(10.4, -6.8, 0.35), 0.35)
	server_spawn_prop("wooden_crate", _ground_pt(-16.8, -8.2, 0.35), -0.25)
	server_spawn_prop("wooden_crate", _ground_pt(-40.5, 8.0, 0.35), 0.50)
	server_spawn_prop("wine_barrel", _ground_pt(-13.8, -8.0, 0.35))
	server_spawn_prop("wine_barrel", _ground_pt(-10.5, 14.0, 0.35))
	server_spawn_prop("explosive_barrel", _ground_pt(-18.5, 22.0, 0.35))
	server_spawn_prop("explosive_barrel", _ground_pt(18.8, -1.5, 0.35))
	server_spawn_prop("jerrycan", _ground_pt(12.2, -7.4, 0.32), 0.4)
	server_spawn_prop("jerrycan", _ground_pt(-41.0, 13.0, 0.32), -0.6)
	server_spawn_prop("jerrycan", _ground_pt(53.0, -20.5, 0.32), 0.8)
	server_spawn_prop("boulder", _ground_pt(21.5, -8.5, 0.35))
	server_spawn_prop("boulder", _ground_pt(43.2, 40.5, 0.35))

	# Сундуки с оружием в укромных уголках (у сараев и у избушки лесника)
	server_spawn_prop("treasure_chest", _ground_pt(53.8, -15.6, 0.35), -0.7)
	server_spawn_prop("treasure_chest", _ground_pt(-56.5, 14.5, 0.35), 1.57)
	server_spawn_prop("treasure_chest", _ground_pt(46.5, 43.8, 0.35), 2.4)

	# Пружинный трамплин во дворе для весёлых прыжков на крыши домиков (отличная позиция для засад!)
	server_spawn_prop("launchpad", _ground_pt(-11.5, 21.5, 0.04), -PI * 0.5)

	# 4. Тренировочные манекены (у поляны костра, на деревенской улице и у лесной избушки)
	server_spawn_dummy(_ground_pt(17.5, -3.2, 0.25), -PI * 0.5)
	server_spawn_dummy(_ground_pt(-19.5, 4.5, 0.25), PI)
	server_spawn_dummy(_ground_pt(49.2, -19.8, 0.25), PI * 0.35)


@rpc("any_peer", "call_local", "reliable")
func request_sandbox_spawn(item_id: String, desired_pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var safe_pos := _clamp_inside_arena(desired_pos)

	# Привязка к полу/земле лучом вниз (поддерживает спавн и на улице, и на полу внутри домов, и на крышах!)
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(safe_pos + Vector3(0.0, 4.5, 0.0), safe_pos + Vector3(0.0, -12.0, 0.0), 1)
	var hit := space.intersect_ray(rq)
	var ground_y := float(hit["position"].y) if not hit.is_empty() else TerrainBuilder.get_height(safe_pos.x, safe_pos.z)
	var ground_pos := Vector3(safe_pos.x, ground_y, safe_pos.z)

	if item_id.begins_with("weapon:"):
		var wid := item_id.trim_prefix("weapon:")
		if AssetCatalog.WEAPON_DEFS.has(wid):
			server_spawn_world_weapon(wid, ground_pos + Vector3(0.0, 0.65, 0.0))
	elif item_id.begins_with("prop:"):
		var ptype := item_id.trim_prefix("prop:")
		var y_lift := 0.02 if ptype in ["launchpad", "wood_ramp", "fire_pit", "lantern_post", "thicket_hedge"] else 0.35
		server_spawn_prop(ptype, ground_pos + Vector3(0.0, y_lift, 0.0), yaw)
	elif item_id.begins_with("dummy:"):
		server_spawn_dummy(ground_pos + Vector3(0.0, 0.22, 0.0), yaw + PI)


func _clamp_inside_arena(pos: Vector3) -> Vector3:
	var lim := TerrainBuilder.PLAYABLE_LIMIT - 2.5 # 84.5 м (внутри периметра 87 м)
	var out := pos
	out.x = clampf(out.x, -lim, lim)
	out.z = clampf(out.z, -lim, lim)
	out.y = clampf(out.y, TerrainBuilder.get_height(out.x, out.z) - 0.5, 16.0)
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
			NetworkManager.broadcast_event("Хост перезагрузил предметы посёлка и леса!", Color(0.45, 0.88, 1.0))
	)
