class_name TerrainBuilder
extends RefCounted
## Генератор реалистичного рельефа Восточной Европы (232×232 м, игровая зона 180×180 м без обрывов)
## с кастомным 4-слойным PBR Splatmap-шейдером (луговая трава, просёлочная грунтовка с колеёй и кюветами,
## утоптанные дворовые/лесные тропинки и хвойно-лиственная лесная подстилка).

const TERRAIN_EXTENT: float = 116.0 # Детальная игровая сетка с мелким шагом (-104..+104 м)
const VISTA_EXTENT: float = 420.0   # Бесшовное продолжение рельефа до горизонта (840×840 м — 0 обрывов!)
const COLLIDER_LIMIT: float = 98.0  # Физический коллайдер нужен только внутри периметра с запасом
const GRID_STEP: float = 1.6        # Шаг детальной сетки в игровой зоне
const PLAYABLE_LIMIT: float = 87.0  # Внутренний периметр заборов и непролазного бурелома

## Участки сельских домов и ключевых полян (выровненные площадки с плавным сопряжением рельефа)
const HOUSE_PLOTS: Array[Dictionary] = [
	# Западная сторона просёлочной дороги
	{"id": "house_1", "pos": Vector2(-49.0, 48.0), "yaw": PI * 0.5, "flat_r": 10.5, "blend_r": 16.5, "style": "blue_wood"},
	{"id": "house_2", "pos": Vector2(-51.0, 10.0), "yaw": PI * 0.5, "flat_r": 11.0, "blend_r": 17.0, "style": "white_plaster"},
	{"id": "house_3", "pos": Vector2(-49.0, -32.0), "yaw": PI * 0.5, "flat_r": 10.5, "blend_r": 16.5, "style": "log_cabin"},
	# Восточная сторона просёлочной дороги (между дорогой и лесом)
	{"id": "house_4", "pos": Vector2(-3.0, 52.0), "yaw": -PI * 0.5, "flat_r": 10.5, "blend_r": 16.5, "style": "green_wood"},
	{"id": "house_5", "pos": Vector2(-1.5, 16.0), "yaw": -PI * 0.5, "flat_r": 10.0, "blend_r": 16.0, "style": "blue_plaster"},
	{"id": "house_6", "pos": Vector2(-2.5, -28.0), "yaw": -PI * 0.5, "flat_r": 10.5, "blend_r": 16.5, "style": "brick_cottage"},
	# Северная околица
	{"id": "house_7", "pos": Vector2(-35.0, -66.0), "yaw": 0.25, "flat_r": 10.0, "blend_r": 16.0, "style": "log_cabin"},
	# Лесная избушка лесника в восточной чаще
	{"id": "forest_hut", "pos": Vector2(56.0, -18.0), "yaw": -PI * 0.72, "flat_r": 7.5, "blend_r": 13.5, "style": "forester_hut"},
]

const FLAT_CLEARINGS: Array[Dictionary] = [
	{"pos": Vector2(14.0, -4.0), "flat_r": 8.5, "blend_r": 15.0},   # Главная поляна с костром у опушки
	{"pos": Vector2(-15.0, -6.0), "flat_r": 5.5, "blend_r": 10.5},  # Площадка у деревенского колодца
	{"pos": Vector2(45.0, 42.0), "flat_r": 7.0, "blend_r": 13.0},   # Лесная поляна с валунами
]

## Полилинии утоптанных тропинок (дворовые дорожки + извилистая лесная тропа)
const FOOTPATH_CHAINS: Array[Array] = [
	# Главная кольцевая лесная тропинка (Поляна костра -> Избушка лесника -> Южная чаща -> Просёлок)
	[
		Vector2(-19.5, -6.0),
		Vector2(-15.0, -6.0),
		Vector2(0.0, -5.5),
		Vector2(14.0, -4.0),
		Vector2(29.0, -13.0),
		Vector2(43.0, -23.0),
		Vector2(56.0, -18.0),
		Vector2(66.0, 3.0),
		Vector2(62.0, 28.0),
		Vector2(45.0, 42.0),
		Vector2(22.0, 40.0),
		Vector2(-20.0, 35.0),
	],
	# Северная охотничья тропа через берёзово-еловую рощу
	[
		Vector2(29.0, -13.0),
		Vector2(38.0, -36.0),
		Vector2(46.0, -56.0),
		Vector2(20.0, -65.0),
		Vector2(-19.0, -54.0),
	],
	# Подходы от грунтовки к калиткам домов
	[Vector2(-27.0, 48.0), Vector2(-43.0, 48.0)],
	[Vector2(-24.0, 10.0), Vector2(-44.0, 10.0)],
	[Vector2(-18.0, -32.0), Vector2(-42.0, -32.0)],
	[Vector2(-25.0, 52.0), Vector2(-9.0, 52.0)],
	[Vector2(-22.0, 16.0), Vector2(-8.0, 16.0)],
	[Vector2(-17.0, -28.0), Vector2(-9.0, -28.0)],
	[Vector2(-21.0, -62.0), Vector2(-35.0, -61.0)],
]

static var _terrain_shader: Shader = null


## Центр главной просёлочной грунтовой дороги при заданном Z
static func get_road_center_x(z: float) -> float:
	var base_x := -23.5 + 6.8 * sin(z * 0.031) + 2.8 * cos(z * 0.058)
	# За шлагбаумами (±89 м) просёлок плавно уходит дугой в чащу дремучего леса
	var out_bend := smoothstep(89.0, 132.0, absf(z)) * 22.0
	return base_x + out_bend


## Расстояние до ближайшей точки просёлочной грунтовки
static func get_road_distance(x: float, z: float) -> float:
	var rx := get_road_center_x(z)
	var dx_dz := get_road_center_x(z + 0.5) - get_road_center_x(z - 0.5)
	var cos_norm := 1.0 / sqrt(1.0 + dx_dz * dx_dz)
	return absf(x - rx) * cos_norm


## Расстояние до ближайшей утоптанной тропинки (в лесу или к домам)
static func get_footpath_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var min_d := 999.0
	for chain in FOOTPATH_CHAINS:
		for i in range(chain.size() - 1):
			var a: Vector2 = chain[i]
			var b: Vector2 = chain[i + 1]
			var ab := b - a
			var len_sq := ab.length_squared()
			var t := clampf((p - a).dot(ab) / maxf(len_sq, 0.0001), 0.0, 1.0)
			var proj := a + ab * t
			var d := p.distance_to(proj)
			if d < min_d:
				min_d = d
	return min_d


## Коэффициент лесной зоны (0.0 — поле/деревня, 1.0 — густой восточный/северный лес и все внешние границы)
static func get_forest_factor(x: float, z: float) -> float:
	# Основной лесной массив начинается от поляны костра на восток (x > +6..+24 м), плюс перелески и все 4 границы карты
	var east_woods := smoothstep(6.0, 24.0, x + 5.0 * sin(z * 0.045))
	var north_edge := smoothstep(58.0, 80.0, -z) * smoothstep(-34.0, 8.0, x)
	var south_edge := smoothstep(60.0, 82.0, z) * smoothstep(-18.0, 20.0, x)
	var outer_ring := smoothstep(76.0, 88.5, maxf(absf(x), absf(z)))
	# Живописные лесные куртины и перелески вдоль околицы
	var copse := smoothstep(0.42, 0.82, sin(x * 0.058 + 0.7) * cos(z * 0.052 - 0.4)) * smoothstep(-16.0, 12.0, x) * 0.78
	return clampf(maxf(maxf(maxf(east_woods, north_edge), maxf(south_edge, outer_ring)), copse), 0.0, 1.0)


## Базовая природная высота рельефа (без учёта выравнивания под дома)
static func _raw_natural_height(x: float, z: float) -> float:
	var hills := (
		0.85 * sin(x * 0.028 + 0.4) * cos(z * 0.026 - 0.2)
		+ 0.45 * sin(x * 0.062 - z * 0.048)
		+ 0.22 * cos(x * 0.11 + z * 0.095)
	)
	# Восточный лес плавно приподнимается холмами (+0.6..+2.4 м) — отличный рельеф для пряток!
	var forest_rise := smoothstep(12.0, 68.0, x) * (1.35 + 0.65 * sin(z * 0.052 + x * 0.035))
	# За границами игровой зоны (±89 м) рельеф плавно поднимается лесистыми увалами (+3..+14 м) со всех 4 сторон,
	# полностью исключая ощущение «летающего острова» и перекрывая горизонт под небом!
	var out_d := maxf(0.0, maxf(absf(x), absf(z)) - 89.0)
	var ridge_mod := 0.62 + 0.38 * sin(x * 0.019 + 0.7) * cos(z * 0.017 - 0.4) + 0.22 * sin((x - z) * 0.029)
	var outer_hills := smoothstep(0.0, 165.0, out_d) * (7.2 + 6.4 * ridge_mod)
	return 0.45 + hills + forest_rise + outer_hills


## Точная высота поверхности земли в любой точке (x, z) — O(1)
static func get_height(x: float, z: float) -> float:
	var h := _raw_natural_height(x, z)

	# Выравнивание площадок под дома и ключевые поляны
	var p := Vector2(x, z)
	for plot in HOUSE_PLOTS:
		var c: Vector2 = plot["pos"]
		var d := p.distance_to(c)
		var br: float = float(plot["blend_r"])
		if d < br:
			var target_h := _raw_natural_height(c.x, c.y)
			var w := 1.0 - smoothstep(float(plot["flat_r"]), br, d)
			h = lerpf(h, target_h, w)

	for clr in FLAT_CLEARINGS:
		var c2: Vector2 = clr["pos"]
		var d2 := p.distance_to(c2)
		var br2: float = float(clr["blend_r"])
		if d2 < br2:
			var target_h2 := _raw_natural_height(c2.x, c2.y)
			var w2 := 1.0 - smoothstep(float(clr["flat_r"]), br2, d2)
			h = lerpf(h, target_h2, w2)

	# Профиль просёлочной грунтовки: лёгкая колея в центре и придорожные кюветы по обочинам
	var rd := get_road_distance(x, z)
	var road_fade := 1.0 - smoothstep(104.0, 142.0, absf(z))
	if rd < 7.2 and road_fade > 0.01:
		var road_center_h := _raw_natural_height(get_road_center_x(z), z)
		var flatten := (1.0 - smoothstep(2.8, 6.8, rd)) * road_fade
		h = lerpf(h, road_center_h, flatten * 0.78)
		# Две автомобильные/тракторные колеи на расстоянии ±1.15 м от оси грунтовки
		var rut := exp(-pow((rd - 1.15) / 0.48, 2.0)) * 0.08 * road_fade
		# Неглубокий травяной кювет вдоль обочин (rd ~ 4.4 м)
		var ditch := exp(-pow((rd - 4.45) / 0.95, 2.0)) * 0.24 * road_fade
		h -= (rut + ditch)

	# Лёгкая ложбинка утоптанной лесной тропинки
	var pd := get_footpath_distance(x, z)
	if pd < 2.2:
		h -= (1.0 - smoothstep(0.4, 2.0, pd)) * 0.06

	return maxf(0.0, h)


## Нормаль рельефа методом конечных разностей
static func get_normal(x: float, z: float) -> Vector3:
	var eps := 0.55
	var hL := get_height(x - eps, z)
	var hR := get_height(x + eps, z)
	var hD := get_height(x, z - eps)
	var hU := get_height(x, z + eps)
	return Vector3(hL - hR, 2.0 * eps, hD - hU).normalized()


## Веса слоёв Splatmap: Color(road_mud, trodden_path, forest_litter, 1.0)
static func get_surface_weights(x: float, z: float) -> Color:
	var noise_jitter := 0.35 * sin(x * 0.43 + z * 0.37) + 0.20 * cos(x * 0.91 - z * 0.79)

	var rd := get_road_distance(x, z) + noise_jitter * 0.45
	var road_vis := 1.0 - smoothstep(104.0, 140.0, absf(z))
	var w_road := (1.0 - smoothstep(2.25, 3.65, rd)) * road_vis

	var pd := get_footpath_distance(x, z) + noise_jitter * 0.28
	var w_path := (1.0 - smoothstep(0.85, 1.85, pd)) * (1.0 - w_road)

	# Пятна вытоптанной земли во дворах и у костра
	var p := Vector2(x, z)
	var camp_wear := (1.0 - smoothstep(2.2, 6.2, p.distance_to(Vector2(14.0, -4.0)))) * 0.85
	var well_wear := (1.0 - smoothstep(1.8, 4.8, p.distance_to(Vector2(-15.0, -6.0)))) * 0.80
	w_path = clampf(maxf(w_path, maxf(camp_wear, well_wear)) * (1.0 - w_road), 0.0, 1.0)

	var w_forest := get_forest_factor(x, z) * (1.0 - w_road) * (1.0 - w_path * 0.85)
	w_forest = clampf(w_forest + noise_jitter * 0.15 * w_forest, 0.0, 1.0)

	return Color(clampf(w_road, 0.0, 1.0), clampf(w_path, 0.0, 1.0), clampf(w_forest, 0.0, 1.0), 1.0)


## Проверяет, занята ли точка домом (чтобы трава и деревья не росли сквозь пол домов)
static func is_inside_building_footprint(x: float, z: float, margin: float = 0.8) -> bool:
	var p := Vector2(x, z)
	for plot in HOUSE_PLOTS:
		var c: Vector2 = plot["pos"]
		var yaw: float = float(plot["yaw"])
		var rel := (p - c).rotated(yaw)
		var hx := 5.6 + margin
		var hz := 4.8 + margin
		if String(plot["style"]) == "forester_hut":
			hx = 3.8 + margin
			hz = 3.4 + margin
		if absf(rel.x) <= hx and absf(rel.y) <= hz:
			return true
		# Также проверяем хозяйственный сарай на участке (смещён вглубь двора)
		if String(plot["style"]) != "forester_hut":
			var shed_rel := rel - Vector2(-1.5, -7.2)
			if absf(shed_rel.x) <= (2.6 + margin) and absf(shed_rel.y) <= (2.2 + margin):
				return true
	return false


static func _build_axis_coords() -> PackedFloat32Array:
	var coords := PackedFloat32Array()
	var outer_offsets: Array[float] = [
		316.0, 268.0, 222.0, 180.0, 144.0, 114.0, 89.0,
		68.0, 50.5, 36.5, 25.5, 17.0, 10.6, 5.8, 2.4,
	]
	var core_half := 104.0
	for d: float in outer_offsets:
		coords.append(-core_half - d)

	var core_steps := int(round((core_half * 2.0) / GRID_STEP))
	for i in range(core_steps + 1):
		coords.append(-core_half + float(i) * GRID_STEP)

	for idx in range(outer_offsets.size() - 1, -1, -1):
		coords.append(core_half + float(outer_offsets[idx]))
	return coords


static func build_terrain_node(parent: Node3D) -> StaticBody3D:
	var axis := _build_axis_coords()
	var vert_row := axis.size()
	var steps := vert_row - 1

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var col_faces := PackedVector3Array()

	positions.resize(vert_row * vert_row)
	normals.resize(vert_row * vert_row)
	tangents.resize(vert_row * vert_row * 4)
	uvs.resize(vert_row * vert_row)
	colors.resize(vert_row * vert_row)

	var v_idx := 0
	for iz in range(vert_row):
		var wz := axis[iz]
		for ix in range(vert_row):
			var wx := axis[ix]
			var wy := get_height(wx, wz)
			var nrm := get_normal(wx, wz)
			positions[v_idx] = Vector3(wx, wy, wz)
			normals[v_idx] = nrm
			var t := (Vector3.RIGHT - nrm * nrm.x).normalized()
			var t_base := v_idx * 4
			tangents[t_base] = t.x
			tangents[t_base + 1] = t.y
			tangents[t_base + 2] = t.z
			tangents[t_base + 3] = -1.0
			uvs[v_idx] = Vector2(wx * 0.50, wz * 0.50)
			colors[v_idx] = get_surface_weights(wx, wz)
			v_idx += 1

	indices.resize(steps * steps * 6)
	var i_ptr := 0
	for iz in range(steps):
		var z_in := absf(axis[iz]) <= COLLIDER_LIMIT and absf(axis[iz + 1]) <= COLLIDER_LIMIT
		for ix in range(steps):
			var i00 := iz * vert_row + ix
			var i10 := i00 + 1
			var i01 := (iz + 1) * vert_row + ix
			var i11 := i01 + 1

			# Порядок вершин против часовой стрелки при взгляде сверху (+Y нормаль в Godot)
			indices[i_ptr] = i00
			indices[i_ptr + 1] = i10
			indices[i_ptr + 2] = i11

			indices[i_ptr + 3] = i00
			indices[i_ptr + 4] = i11
			indices[i_ptr + 5] = i01
			i_ptr += 6

			if z_in and absf(axis[ix]) <= COLLIDER_LIMIT and absf(axis[ix + 1]) <= COLLIDER_LIMIT:
				col_faces.append(positions[i00])
				col_faces.append(positions[i10])
				col_faces.append(positions[i11])
				col_faces.append(positions[i00])
				col_faces.append(positions[i11])
				col_faces.append(positions[i01])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.surface_set_material(0, _create_terrain_material())

	var sb := StaticBody3D.new()
	sb.name = "SculptedVillageTerrain"
	sb.collision_layer = 1
	sb.collision_mask = 0

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = arr_mesh
	sb.add_child(mi)

	var col := CollisionShape3D.new()
	col.name = "TerrainCollider"
	var tri_shape := ConcavePolygonShape3D.new()
	tri_shape.set_faces(col_faces)
	col.shape = tri_shape
	sb.add_child(col)

	parent.add_child(sb)
	return sb


static func _create_terrain_material(force_shader: bool = false) -> Material:
	if DisplayServer.get_name() == "headless" and not force_shader:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.28, 0.36, 0.18)
		return fallback

	if _terrain_shader == null:
		_terrain_shader = Shader.new()
		_terrain_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D road_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D path_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_arm : filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D forest_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_arm : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Двухпроекционный острый сэмплинг (повёрнутый на 37° с резким переходом по высоте микрорельефа):
	// сохраняет 100% чёткость каждой веточки и трещины (как на референсе!), полностью убирая сетку повторов!
	vec2 uv_a = v_world_pos.xz * 0.38;
	vec2 p_rot = vec2(
		v_world_pos.x * 0.7986 - v_world_pos.z * 0.6018,
		v_world_pos.x * 0.6018 + v_world_pos.z * 0.7986
	);
	vec2 uv_b = p_rot * 0.35 + vec2(17.3, -9.1);
	float patch_n = vnoise(v_world_pos.xz * 0.36);

	float macro = vnoise(v_world_pos.xz * 0.055) * 0.65 + vnoise(v_world_pos.xz * 0.16) * 0.35;
	vec3 grass_tint = mix(vec3(0.42, 0.54, 0.30), vec3(0.60, 0.65, 0.40), smoothstep(0.28, 0.78, macro));
	vec3 forest_tint = mix(vec3(0.44, 0.48, 0.34), vec3(0.62, 0.65, 0.48), smoothstep(0.20, 0.82, macro));

	vec3 ga1 = texture(grass_alb, uv_a).rgb;
	vec3 ga2 = texture(grass_alb, uv_b).rgb;
	vec3 g_arm1 = texture(grass_arm, uv_a).rgb;
	vec3 g_arm2 = texture(grass_arm, uv_b).rgb;
	float gw = smoothstep(0.38, 0.62, patch_n + (g_arm2.r - g_arm1.r) * 0.35);
	vec3 g_alb = mix(ga1, ga2, gw) * grass_tint;
	vec3 g_nor = mix(texture(grass_nor, uv_a).rgb, texture(grass_nor, uv_b).rgb, gw);
	vec3 g_arm = mix(g_arm1, g_arm2, gw);

	vec3 r_alb = texture(road_alb, uv_a * 0.95).rgb * mix(vec3(0.56, 0.51, 0.43), vec3(0.72, 0.67, 0.57), macro);
	vec3 r_nor = texture(road_nor, uv_a * 0.95).rgb;
	vec3 r_arm = texture(road_arm, uv_a * 0.95).rgb;

	vec3 p_alb = texture(path_alb, uv_a * 1.12).rgb * mix(vec3(0.50, 0.51, 0.40), vec3(0.64, 0.64, 0.52), macro);
	vec3 p_nor = texture(path_nor, uv_a * 1.12).rgb;
	vec3 p_arm = texture(path_arm, uv_a * 1.12).rgb;

	vec3 fa1 = texture(forest_alb, uv_a).rgb;
	vec3 fa2 = texture(forest_alb, uv_b).rgb;
	vec3 f_arm1 = texture(forest_arm, uv_a).rgb;
	vec3 f_arm2 = texture(forest_arm, uv_b).rgb;
	float fw = smoothstep(0.38, 0.62, patch_n + (f_arm2.r - f_arm1.r) * 0.40);
	vec3 f_alb = mix(fa1, fa2, fw) * forest_tint;
	vec3 f_nor = mix(texture(forest_nor, uv_a).rgb, texture(forest_nor, uv_b).rgb, fw);
	vec3 f_arm = mix(f_arm1, f_arm2, fw);

	// Детальное смешивание по высоте микрорельефа (Height-blended Splatmap) с резкими границами мха и веточек
	float detail_n = vnoise(v_world_pos.xz * 2.1) * 0.26;
	float w_forest = clamp(COLOR.b * 1.15 + (f_arm.r - g_arm.r) * 0.34 + detail_n * 0.22, 0.0, 1.0);
	w_forest = smoothstep(0.14, 0.74, COLOR.b > 0.02 ? w_forest : 0.0);

	float w_path = clamp(COLOR.g + (p_arm.r - 0.5) * 0.28 + detail_n * 0.36, 0.0, 1.0);
	w_path = smoothstep(0.22, 0.76, COLOR.g > 0.02 ? w_path : 0.0);

	float w_road = clamp(COLOR.r + (r_arm.r - g_arm.r) * 0.35 + detail_n * 0.32, 0.0, 1.0);
	w_road = smoothstep(0.20, 0.74, COLOR.r > 0.02 ? w_road : 0.0);

	vec3 alb = mix(g_alb, f_alb, w_forest);
	vec3 nor = mix(g_nor, f_nor, w_forest);
	vec3 arm = mix(g_arm, f_arm, w_forest);

	alb = mix(alb, p_alb, w_path);
	nor = mix(nor, p_nor, w_path);
	arm = mix(arm, p_arm, w_path);

	alb = mix(alb, r_alb, w_road);
	nor = mix(nor, r_nor, w_road);
	arm = mix(arm, r_arm, w_road);

	ALBEDO = alb;
	NORMAL_MAP = nor;
	NORMAL_MAP_DEPTH = 1.45;
	AO = pow(clamp(arm.r, 0.06, 1.0), 1.25);
	AO_LIGHT_AFFECT = 0.82;
	ROUGHNESS = clamp(arm.g * mix(1.04, 0.90, w_forest), 0.38, 0.96);
	SPECULAR = mix(0.22, 0.30, w_forest);
}
"""

	var sm := ShaderMaterial.new()
	sm.shader = _terrain_shader
	_assign_tex_triplet(sm, "grass", "leafy_grass")
	_assign_tex_triplet(sm, "road", "brown_mud_leaves_01")
	_assign_tex_triplet(sm, "path", "grass_path_2")
	_assign_tex_triplet(sm, "forest", "forest_leaves_02")
	return sm


static func _assign_tex_triplet(sm: ShaderMaterial, prefix: String, tex_id: String) -> void:
	var base := "res://assets/downloaded/textures/%s" % tex_id
	var d := AssetCatalog._load_texture_safe("%s/diff.jpg" % base)
	var n := AssetCatalog._load_texture_safe("%s/nor_gl.jpg" % base)
	var a := AssetCatalog._load_texture_safe("%s/arm.jpg" % base)
	if d != null:
		sm.set_shader_parameter("%s_alb" % prefix, d)
	if n != null:
		sm.set_shader_parameter("%s_nor" % prefix, n)
	if a != null:
		sm.set_shader_parameter("%s_arm" % prefix, a)
