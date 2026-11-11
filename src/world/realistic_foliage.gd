class_name RealisticFoliage
extends RefCounted
## Реалистичная растительность Восточной Европы (конец августа, профиль RTX 4070):
## 1) 7 ботанических пород взрослых деревьев (берёза повислая, корабельная сосна, европейская ель,
##    садовая яблоня, черешчатый дуб, остролистный клён с красками конца августа, трепещущая осина)
##    с повышенной густотой ветвей и фотосканированными атласами листвы/хвои (1024² в 1K / 2048² в 4K).
## 2) Полнополигональные 3D-сканы молодых елей и сосен Poly Haven (fir_sapling, pine_sapling_small —
##    по 125 000–157 000 треугольников честной 3D-хвои на каждое деревце на уровне глаз игрока!).
## 3) 6 видов пышных многоствольных кустарников (включая 9-ствольный 156k shrub_01 и цветущий палисадник)
##    + папоротники, крапива, крупные кусты чистотела (4.3k), цветущие одуванчики (23.5k) и подушки мха.
## 4) Многослойный августовский луг: 56 000+ пучков 3D-травы + крупные кочки овсяницы (4.6k) +
##    высокие колоски мятлика (Foliage003) + приземистая дернина с метёлками (grass_bermuda_01).
## Все массивы разбиты на пространственные чанки MultiMesh для стабильных 50–60+ FPS на RTX 4070.

enum TreeSpecies {
	BIRCH = 0,
	PINE = 1,
	SPRUCE = 2,
	ORCHARD = 3,
	OAK = 4,
	MAPLE = 5,
	ASPEN = 6,
}

# 6-точечные трапециевидные UV-контуры реальных еловых лап Poly Haven fir_twig (0 утечек соседних островов):
# Порядок вершин: [base_L, base_R, mid_R, tip_R, tip_L, mid_L]
const FIR_BOUGH_POLYS: Array = [
	[
		Vector2(0.415, 0.780), Vector2(0.530, 0.780),
		Vector2(0.646, 0.565), Vector2(0.595, 0.405),
		Vector2(0.320, 0.405), Vector2(0.296, 0.590),
	],
	[
		Vector2(0.738, 0.836), Vector2(0.832, 0.836),
		Vector2(0.960, 0.645), Vector2(0.910, 0.450),
		Vector2(0.675, 0.450), Vector2(0.630, 0.665),
	],
	[
		Vector2(0.760, 0.374), Vector2(0.848, 0.374),
		Vector2(0.944, 0.200), Vector2(0.944, 0.034),
		Vector2(0.648, 0.034), Vector2(0.648, 0.210),
	],
	[
		Vector2(0.268, 0.316), Vector2(0.342, 0.316),
		Vector2(0.434, 0.165), Vector2(0.434, 0.038),
		Vector2(0.184, 0.038), Vector2(0.184, 0.180),
	],
]

# Изолированные UV-контуры высоких колосков мятлика (ambientCG Foliage003: левый и правый снопы)
const MEADOW_STALK_POLYS: Array = [
	[
		Vector2(0.060, 0.745), Vector2(0.135, 0.745),
		Vector2(0.185, 0.390), Vector2(0.182, 0.105),
		Vector2(0.018, 0.105), Vector2(0.018, 0.390),
	],
	[
		Vector2(0.855, 0.785), Vector2(0.945, 0.785),
		Vector2(0.976, 0.420), Vector2(0.972, 0.155),
		Vector2(0.734, 0.155), Vector2(0.732, 0.420),
	],
]

# Полный контур для собранных 1024²/2048² RGBA8-атласов ветвей лиственных деревьев и сосны
const FULL_SPRAY_POLY: Array = [
	Vector2(0.22, 0.99), Vector2(0.78, 0.99),
	Vector2(0.99, 0.50), Vector2(0.96, 0.01),
	Vector2(0.04, 0.01), Vector2(0.01, 0.50),
]

static var _birch_bark_mat: Material = null
static var _pine_bark_mat: Material = null
static var _dark_bark_mat: Material = null
static var _oak_bark_mat: Material = null
static var _maple_bark_mat: Material = null
static var _aspen_bark_mat: Material = null

static var _pbr_foliage_shader: Shader = null
static var _canopy_mats: Dictionary = {}
static var _meadow_grass_mat: Material = null
static var _meadow_stalks_mat: Material = null

static var _birch_spray_tex: Texture2D = null
static var _orchard_spray_tex: Texture2D = null
static var _pine_bough_tex: Texture2D = null
static var _oak_spray_tex: Texture2D = null
static var _maple_spray_tex: Texture2D = null
static var _aspen_spray_tex: Texture2D = null
static var _flat_normal_tex: Texture2D = null


static func populate_world_foliage(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "RealisticFoliageSystem"
	parent.add_child(root)

	_build_trees_and_trunks(root, rng)

	if DisplayServer.get_name() != "headless":
		_populate_young_conifer_saplings(root, rng)
		_build_photoscanned_undergrowth(root, rng)
		_build_gpu_meadow_grass(root, rng)


# ============================================================================
# 1. 7 ПОРОД ВЗРОСЛЫХ БОТАНИЧЕСКИХ ДЕРЕВЬЕВ + КОЛЛАЙДЕРЫ СТВОЛОВ
# ============================================================================

static func _build_trees_and_trunks(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var trunk_bodies := StaticBody3D.new()
	trunk_bodies.name = "TreeTrunkColliders"
	trunk_bodies.collision_layer = 1
	trunk_bodies.collision_mask = 0
	parent.add_child(trunk_bodies)

	var all_species: Array[int] = [
		TreeSpecies.BIRCH, TreeSpecies.PINE, TreeSpecies.SPRUCE,
		TreeSpecies.ORCHARD, TreeSpecies.OAK, TreeSpecies.MAPLE, TreeSpecies.ASPEN,
	]

	var species_variants: Dictionary = {}
	if DisplayServer.get_name() != "headless":
		for sp: int in all_species:
			var v0 := _generate_tree_mesh(sp, 100 + sp * 17)
			var v1 := _generate_tree_mesh(sp, 200 + sp * 31)
			species_variants[sp] = [v0, v1]

	var transforms_by_key: Dictionary = {}
	for sp: int in all_species:
		transforms_by_key["%d_0" % sp] = []
		transforms_by_key["%d_1" % sp] = []

	var placed_trees: Array[Vector2] = []

	# А) Усадьбы и деревенские дворы: садовые яблони, остролистные клёны и берёзы
	for plot in TerrainBuilder.HOUSE_PLOTS:
		var c: Vector2 = plot["pos"]
		var style := String(plot["style"])
		if style == "forester_hut":
			continue
		for k in range(4):
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(6.8, 11.6)
			var tp := c + Vector2(cos(ang), sin(ang)) * dist
			if not _can_place_tree_at(tp.x, tp.y, placed_trees, 3.6):
				continue
			var sp_yard: int = TreeSpecies.ORCHARD
			if k == 2:
				sp_yard = TreeSpecies.MAPLE
			elif k == 3:
				sp_yard = TreeSpecies.BIRCH
			var sc := rng.randf_range(0.88, 1.18)
			_register_tree_instance(tp, sp_yard, sc, rng, placed_trees, transforms_by_key, trunk_bodies)

	# Б) Вдоль просёлочной грунтовки и у поляны костра: старые дубы, берёзы, клёны и сосны
	for i in range(46):
		var tz := -80.0 + float(i) * 3.55 + rng.randf_range(-1.2, 1.2)
		var side := -1.0 if (i % 2 == 0) else 1.0
		var tx := TerrainBuilder.get_road_center_x(tz) + side * rng.randf_range(6.4, 12.2)
		if not _can_place_tree_at(tx, tz, placed_trees, 4.3):
			continue
		var r_road := rng.randf()
		var sp2: int = TreeSpecies.BIRCH
		if r_road < 0.36:
			sp2 = TreeSpecies.BIRCH
		elif r_road < 0.58:
			sp2 = TreeSpecies.MAPLE
		elif r_road < 0.80:
			sp2 = TreeSpecies.OAK
		else:
			sp2 = TreeSpecies.PINE
		var sc2 := rng.randf_range(0.95, 1.32)
		_register_tree_instance(Vector2(tx, tz), sp2, sc2, rng, placed_trees, transforms_by_key, trunk_bodies)

	# В) Густой смешанный восточноевропейский лес и опушки (~520 деревьев всех 7 пород)
	for _attempt in range(1550):
		if placed_trees.size() >= 585:
			break
		var tx := rng.randf_range(-85.0, 85.0)
		var tz := rng.randf_range(-85.0, 85.0)
		var ff := TerrainBuilder.get_forest_factor(tx, tz)
		var keep_prob := 0.05 + ff * 0.92
		if rng.randf() > keep_prob:
			continue
		var min_spacing := lerpf(5.4, 3.4, ff)
		if not _can_place_tree_at(tx, tz, placed_trees, min_spacing):
			continue

		var roll := rng.randf()
		var sp3: int = TreeSpecies.PINE
		if ff > 0.58:
			# Глухой хвойно-широколиственный массив: ель, сосна, дуб, осина, берёза, клён
			if roll < 0.28:
				sp3 = TreeSpecies.SPRUCE
			elif roll < 0.54:
				sp3 = TreeSpecies.PINE
			elif roll < 0.69:
				sp3 = TreeSpecies.OAK
			elif roll < 0.82:
				sp3 = TreeSpecies.ASPEN
			elif roll < 0.92:
				sp3 = TreeSpecies.BIRCH
			else:
				sp3 = TreeSpecies.MAPLE
		else:
			# Светлые опушки и перелески: берёза, осина, дуб, клён, сосна
			if roll < 0.34:
				sp3 = TreeSpecies.BIRCH
			elif roll < 0.54:
				sp3 = TreeSpecies.ASPEN
			elif roll < 0.72:
				sp3 = TreeSpecies.OAK
			elif roll < 0.87:
				sp3 = TreeSpecies.MAPLE
			else:
				sp3 = TreeSpecies.PINE

		var sc3 := rng.randf_range(0.90, 1.44)
		_register_tree_instance(Vector2(tx, tz), sp3, sc3, rng, placed_trees, transforms_by_key, trunk_bodies)

	# Г) Плотная лесная стена за внешним периметром карты (от ±88 до ±106 м)
	var border_pool: Array[int] = [
		TreeSpecies.PINE, TreeSpecies.SPRUCE, TreeSpecies.OAK,
		TreeSpecies.BIRCH, TreeSpecies.ASPEN, TreeSpecies.MAPLE,
	]
	for i in range(195):
		var side_idx := i % 4
		var along := rng.randf_range(-102.0, 102.0)
		var depth := rng.randf_range(88.5, 106.0)
		var bp := Vector2.ZERO
		match side_idx:
			0: bp = Vector2(along, -depth)
			1: bp = Vector2(along, depth)
			2: bp = Vector2(-depth, along)
			_: bp = Vector2(depth, along)
		var sp_b: int = border_pool[i % border_pool.size()]
		var sc_b := rng.randf_range(1.06, 1.55)
		var v_idx := i % 2
		var key := "%d_%d" % [sp_b, v_idx]
		var y_b := TerrainBuilder.get_height(bp.x, bp.y) - 0.12
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc_b, sc_b, sc_b)), Vector3(bp.x, y_b, bp.y))
		(transforms_by_key[key] as Array).append(xf)

	# Д) Поваленные лесные стволы, пни и сухостой Poly Haven + коллайдеры
	_populate_fallen_logs_and_stumps(parent, trunk_bodies, rng)

	if DisplayServer.get_name() == "headless":
		return

	var trees_group := Node3D.new()
	trees_group.name = "ForestTreeChunks"
	parent.add_child(trees_group)

	for sp: int in all_species:
		for v_idx in range(2):
			var key := "%d_%d" % [sp, v_idx]
			var xforms: Array = transforms_by_key[key]
			if xforms.is_empty():
				continue
			_add_multimesh_batch(
				trees_group,
				"Trees_Sp%d_V%d" % [sp, v_idx],
				species_variants[sp][v_idx],
				xforms,
				245.0,
				true,
				50.0
			)


static func _can_place_tree_at(x: float, z: float, existing: Array[Vector2], min_dist: float) -> bool:
	if absf(x) > 85.5 or absf(z) > 85.5:
		return false
	if TerrainBuilder.get_road_distance(x, z) < 5.0:
		return false
	if TerrainBuilder.get_footpath_distance(x, z) < 2.5:
		return false
	if TerrainBuilder.is_inside_building_footprint(x, z, 2.2):
		return false
	var p := Vector2(x, z)
	if p.distance_to(Vector2(14.0, -4.0)) < 6.8 or p.distance_to(Vector2(-15.0, -6.0)) < 5.0:
		return false
	var min_sq := min_dist * min_dist
	for e in existing:
		if p.distance_squared_to(e) < min_sq:
			return false
	return true


static func _register_tree_instance(
	pos2: Vector2,
	species: int,
	scale_val: float,
	rng: RandomNumberGenerator,
	placed_trees: Array[Vector2],
	transforms_by_key: Dictionary,
	trunk_bodies: StaticBody3D
) -> void:
	placed_trees.append(pos2)
	var wy := TerrainBuilder.get_height(pos2.x, pos2.y) - 0.08
	var yaw := rng.randf() * TAU
	var tilt := Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.03, 0.03))
	var basis := (Basis.from_euler(tilt) * Basis(Vector3.UP, yaw)).scaled(Vector3(scale_val, scale_val, scale_val))
	var xf := Transform3D(basis, Vector3(pos2.x, wy, pos2.y))

	var v_idx := rng.randi() % 2
	(transforms_by_key["%d_%d" % [species, v_idx]] as Array).append(xf)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	var base_r := 0.28
	match species:
		TreeSpecies.BIRCH, TreeSpecies.ASPEN:
			base_r = 0.25
		TreeSpecies.PINE, TreeSpecies.MAPLE:
			base_r = 0.31
		TreeSpecies.OAK:
			base_r = 0.43
		_:
			base_r = 0.27
	cyl.radius = base_r * scale_val
	cyl.height = 5.6 * scale_val
	col.shape = cyl
	col.position = Vector3(pos2.x, wy + cyl.height * 0.5, pos2.y)
	trunk_bodies.add_child(col)


## Полнополигональный 3D-молодняк елей и сосен Poly Haven (125k–157k треугольников честной 3D-хвои на деревце!)
static func _populate_young_conifer_saplings(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var fir_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/fir_sapling/model.gltf")
	var pine_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/pine_sapling_small/model.gltf")

	var fir_buckets: Array = [[], [], []]
	var pine_buckets: Array = [[], [], []]

	for _i in range(280):
		var sx := rng.randf_range(-84.0, 84.0)
		var sz := rng.randf_range(-84.0, 84.0)
		var ff := TerrainBuilder.get_forest_factor(sx, sz)
		if ff < 0.22 or rng.randf() > (0.18 + ff * 0.72):
			continue
		if TerrainBuilder.get_road_distance(sx, sz) < 4.8 or TerrainBuilder.get_footpath_distance(sx, sz) < 1.9:
			continue
		if TerrainBuilder.is_inside_building_footprint(sx, sz, 2.2):
			continue
		if Vector2(sx, sz).distance_to(Vector2(14.0, -4.0)) < 6.0:
			continue

		var sy := TerrainBuilder.get_height(sx, sz) - 0.04
		var sc := rng.randf_range(2.05, 3.35)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(sx, sy, sz))
		var v_idx := rng.randi() % 3
		if rng.randf() < 0.54:
			(fir_buckets[v_idx] as Array).append(xf)
		else:
			(pine_buckets[v_idx] as Array).append(xf)

	var sapling_group := Node3D.new()
	sapling_group.name = "PhotoscannedYoungConifers"
	parent.add_child(sapling_group)

	for v in range(mini(3, fir_meshes.size())):
		if not (fir_buckets[v] as Array).is_empty():
			_add_multimesh_batch(sapling_group, "YoungFir_V%d" % v, fir_meshes[v], fir_buckets[v], 110.0, true, 38.0)

	for v2 in range(mini(3, pine_meshes.size())):
		if not (pine_buckets[v2] as Array).is_empty():
			_add_multimesh_batch(sapling_group, "YoungPine_V%d" % v2, pine_meshes[v2], pine_buckets[v2], 110.0, true, 38.0)


static func _populate_fallen_logs_and_stumps(parent: Node3D, trunk_bodies: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var stump_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/tree_stump_01/model.gltf")
	var trunk_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/dead_tree_trunk/model.gltf")
	var branch_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/dry_branches_medium_01/model.gltf")
	var moss_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/moss_01/model.gltf")

	var stump_xforms: Array[Transform3D] = []
	var log_xforms: Array[Transform3D] = []
	var branch_xforms: Array[Transform3D] = []
	var moss_xforms: Array[Transform3D] = []

	for i in range(105):
		var lx := rng.randf_range(10.0, 84.0) if (i < 80) else rng.randf_range(-78.0, 12.0)
		var lz := rng.randf_range(-82.0, 82.0)
		if TerrainBuilder.get_road_distance(lx, lz) < 5.5 or TerrainBuilder.get_footpath_distance(lx, lz) < 2.6:
			continue
		if TerrainBuilder.is_inside_building_footprint(lx, lz, 2.5):
			continue
		var ly := TerrainBuilder.get_height(lx, lz)
		var yaw := rng.randf() * TAU

		if i % 3 == 0:
			var sc := rng.randf_range(1.15, 1.75)
			log_xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc * 1.25, sc * 1.25)), Vector3(lx, ly + 0.04, lz)))
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(2.9 * sc, 0.36 * sc, 0.36 * sc)
			col.shape = box
			col.position = Vector3(lx, ly + 0.18 * sc, lz)
			col.rotation.y = yaw
			trunk_bodies.add_child(col)
		elif i % 3 == 1:
			var sc2 := rng.randf_range(0.88, 1.38)
			stump_xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc2, sc2, sc2)), Vector3(lx, ly + 0.08, lz)))
		else:
			var sc3 := rng.randf_range(1.1, 1.8)
			branch_xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc3, sc3, sc3)), Vector3(lx, ly + 0.02, lz)))

		# Бархатные подушки лесного мха вокруг пней и поваленных стволов
		for m_k in range(3):
			var mang := rng.randf() * TAU
			var mdist := rng.randf_range(0.32, 0.95)
			var mx := lx + cos(mang) * mdist
			var mz := lz + sin(mang) * mdist
			var my := TerrainBuilder.get_height(mx, mz) - 0.015
			var msc := rng.randf_range(1.65, 2.75)
			moss_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(msc, msc, msc)), Vector3(mx, my, mz)))

	# Дополнительные мшистые кочки в глубине елово-дубового леса
	for _mi in range(420):
		var mx2 := rng.randf_range(-84.0, 84.0)
		var mz2 := rng.randf_range(-84.0, 84.0)
		if TerrainBuilder.get_forest_factor(mx2, mz2) < 0.42:
			continue
		if TerrainBuilder.get_road_distance(mx2, mz2) < 4.5 or TerrainBuilder.get_footpath_distance(mx2, mz2) < 1.5:
			continue
		var my2 := TerrainBuilder.get_height(mx2, mz2) - 0.015
		var msc2 := rng.randf_range(1.80, 3.10)
		moss_xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(msc2, msc2, msc2)), Vector3(mx2, my2, mz2)))

	if DisplayServer.get_name() == "headless":
		return

	if not stump_meshes.is_empty() and not stump_xforms.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedStumps", stump_meshes[0], stump_xforms, 100.0, true, 44.0)
	if not trunk_meshes.is_empty() and not log_xforms.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedFallenLogs", trunk_meshes[0], log_xforms, 110.0, true, 44.0)
	if not branch_meshes.is_empty() and not branch_xforms.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedDryBranches", branch_meshes[0], branch_xforms, 75.0, false, 40.0)
	if not moss_meshes.is_empty() and not moss_xforms.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedForestMoss", moss_meshes[0], moss_xforms, 62.0, false, 32.0)


# ============================================================================
# БОТАНИЧЕСКАЯ СБОРКА 7 ПОРОД ДЕРЕВЬЕВ ПОВЫШЕННОЙ ПЫШНОСТИ (ПОД RTX 4070)
# ============================================================================

static func _generate_tree_mesh(species: int, seed_val: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_leaf := SurfaceTool.new()
	st_leaf.begin(Mesh.PRIMITIVE_TRIANGLES)

	match species:
		TreeSpecies.BIRCH:
			var h := rng.randf_range(11.2, 14.2)
			var lean := Vector2(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.42, 0.42))
			var spine := _make_curved_spine(Vector3.ZERO, Vector3(lean.x, h, lean.y), 10, 0.24, rng)
			_append_tube_along_spine(st_wood, spine, 0.24, 0.032, 10, true)
			var crown_dome := Vector3(lean.x * 0.5, h * 0.42, lean.y * 0.5)

			for b in range(28):
				var t := lerpf(0.25, 0.96, float(b) / 27.0)
				var origin := _sample_spine(spine, t)
				var yaw := float(b) * 2.399 + rng.randf_range(-0.22, 0.22)
				var crown_profile := sin(clampf((t - 0.18) / 0.80, 0.0, 1.0) * PI * 0.88)
				var b_len := (1.20 + 2.45 * crown_profile) * rng.randf_range(0.88, 1.16)
				var end_pt := origin + Vector3(cos(yaw) * b_len, b_len * 0.34 - 0.20, sin(yaw) * b_len)
				var b_spine := _make_curved_spine(origin, end_pt, 5, 0.14, rng)
				b_spine[2].y += 0.28
				_append_tube_along_spine(st_wood, b_spine, lerpf(0.066, 0.022, t), 0.008, 6, false)

				if b % 2 == 0:
					var sub_orig := _sample_spine(b_spine, 0.46)
					var sub_yaw := yaw + (0.60 if (b % 4 == 0) else -0.60)
					var sub_len := b_len * 0.56
					var sub_end := sub_orig + Vector3(cos(sub_yaw) * sub_len, sub_len * 0.10 - 0.18, sin(sub_yaw) * sub_len)
					var sub_spine := _make_curved_spine(sub_orig, sub_end, 3, 0.08, rng)
					_append_tube_along_spine(st_wood, sub_spine, 0.028, 0.007, 4, false)
					_append_spray_rosette(st_leaf, sub_end, crown_dome, rng.randf_range(1.22, 1.56), true, 7, rng)

				for c_step: float in [0.50, 0.78, 1.0]:
					var cp := _sample_spine(b_spine, c_step)
					_append_spray_rosette(st_leaf, cp, crown_dome, rng.randf_range(1.28, 1.72), true, 8, rng)
			_append_spray_rosette(st_leaf, spine[spine.size() - 1], crown_dome, 1.60, true, 8, rng)

		TreeSpecies.PINE:
			var h2 := rng.randf_range(14.2, 18.0)
			var lean2 := Vector2(rng.randf_range(-0.52, 0.52), rng.randf_range(-0.52, 0.52))
			var spine2 := _make_curved_spine(Vector3.ZERO, Vector3(lean2.x, h2, lean2.y), 11, 0.28, rng)
			_append_tube_along_spine(st_wood, spine2, 0.34, 0.050, 10, true)
			var pine_dome := Vector3(lean2.x * 0.6, h2 * 0.56, lean2.y * 0.6)

			for b in range(28):
				var t2 := lerpf(0.51, 0.975, float(b) / 27.0)
				var origin2 := _sample_spine(spine2, t2)
				var yaw2 := float(b) * 2.399 + rng.randf_range(-0.26, 0.26)
				var spread := sin((t2 - 0.45) * PI * 1.45)
				var b_len2 := (1.40 + 2.55 * maxf(spread, 0.24)) * rng.randf_range(0.86, 1.18)
				var end_pt2 := origin2 + Vector3(cos(yaw2) * b_len2, b_len2 * 0.16, sin(yaw2) * b_len2)
				var b_spine2 := _make_curved_spine(origin2, end_pt2, 4, 0.14, rng)
				_append_tube_along_spine(st_wood, b_spine2, lerpf(0.092, 0.032, t2), 0.014, 6, false)

				if b % 2 == 1:
					var ps_orig := _sample_spine(b_spine2, 0.48)
					var ps_yaw := yaw2 + (0.64 if (b % 4 == 1) else -0.64)
					var ps_end := ps_orig + Vector3(cos(ps_yaw) * b_len2 * 0.50, 0.18, sin(ps_yaw) * b_len2 * 0.50)
					var ps_spine := _make_curved_spine(ps_orig, ps_end, 3, 0.06, rng)
					_append_tube_along_spine(st_wood, ps_spine, 0.038, 0.012, 4, false)
					_append_spray_rosette(st_leaf, ps_end, pine_dome, rng.randf_range(1.35, 1.74), false, 7, rng)

				for c_step2: float in [0.55, 0.94]:
					var cp2 := _sample_spine(b_spine2, c_step2)
					_append_spray_rosette(st_leaf, cp2, pine_dome, rng.randf_range(1.42, 1.88), false, 8, rng)
			_append_spray_rosette(st_leaf, spine2[spine2.size() - 1] + Vector3(0.0, 0.15, 0.0), pine_dome, 1.92, false, 8, rng)

		TreeSpecies.SPRUCE:
			var h3 := rng.randf_range(12.6, 16.4)
			var lean3 := Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
			var spine3 := _make_curved_spine(Vector3.ZERO, Vector3(lean3.x, h3, lean3.y), 10, 0.08, rng)
			_append_tube_along_spine(st_wood, spine3, 0.28, 0.025, 10, true)

			# 26 густых конических ярусов настоящих фотосканированных еловых лап
			var tiers := 26
			for tier in range(tiers):
				var t3 := lerpf(0.06, 0.968, float(tier) / float(tiers - 1))
				var origin3 := _sample_spine(spine3, t3)
				var branches_in_tier := 8 if t3 < 0.36 else (7 if t3 < 0.72 else 5)
				var b_len3 := lerpf(3.35, 0.44, pow(t3, 0.85)) * rng.randf_range(0.90, 1.12)
				var tier_dome := origin3 - Vector3(0.0, 1.5 + (1.0 - t3) * 1.2, 0.0)

				for k in range(branches_in_tier):
					var yaw3 := float(tier) * 0.68 + float(k) * (TAU / float(branches_in_tier)) + rng.randf_range(-0.13, 0.13)
					var dir_xz := Vector3(cos(yaw3), 0.0, sin(yaw3))
					var droop_y := -0.46 * (1.0 - t3 * 0.76) + 0.06
					var wood_mid := origin3 + dir_xz * (b_len3 * 0.38) + Vector3(0.0, droop_y * 0.55, 0.0)
					var wood_end := origin3 + dir_xz * (b_len3 * 0.72) + Vector3(0.0, droop_y * 0.88, 0.0)
					_append_tube_along_spine(st_wood, [origin3, wood_mid, wood_end], 0.048 * (1.12 - t3 * 0.65), 0.009, 5, false)

					var full_spine: Array[Vector3] = [
						origin3,
						origin3 + dir_xz * (b_len3 * 0.52) + Vector3(0.0, droop_y * 0.78, 0.0),
						origin3 + dir_xz * b_len3 + Vector3(0.0, droop_y + 0.10 * (1.0 - t3 * 0.5), 0.0),
					]
					_append_spruce_branch_boughs(st_leaf, full_spine, yaw3, b_len3, t3, tier_dome, rng)

			var top_pt := spine3[spine3.size() - 1]
			var top_dome := top_pt - Vector3(0.0, 1.2, 0.0)
			for s_idx in range(4):
				var syaw := float(s_idx) * (TAU / 4.0) + rng.randf_range(-0.18, 0.18)
				var sb := Basis(Vector3.UP, syaw) * Basis(Vector3.RIGHT, deg_to_rad(-56.0))
				var poly_top: Array = FIR_BOUGH_POLYS[2 + (s_idx % 2)]
				_append_curved_bough_card(st_leaf, top_pt - Vector3(0.0, 0.22, 0.0), sb, 0.58, 0.84, -0.05, 0.34, 0.75, poly_top, top_dome, rng.randf(), 0.98)

		TreeSpecies.OAK:
			# Дуб черешчатый (Quercus robur): могучий кряжистый ствол, толстые суковатые ветви и широкий шатёр кроны
			var h_oak := rng.randf_range(13.6, 17.0)
			var fork_oak := h_oak * 0.29
			var oak_trunk := _make_curved_spine(Vector3.ZERO, Vector3(rng.randf_range(-0.22, 0.22), fork_oak, rng.randf_range(-0.22, 0.22)), 6, 0.18, rng)
			_append_tube_along_spine(st_wood, oak_trunk, 0.45, 0.28, 11, true)
			var oak_fork_pt := oak_trunk[oak_trunk.size() - 1]
			var oak_dome := Vector3(0.0, h_oak * 0.38, 0.0)

			# Центральный узловатый ствол-лидер внутри кроны
			var leader_end := oak_fork_pt + Vector3(rng.randf_range(-0.4, 0.4), h_oak - fork_oak, rng.randf_range(-0.4, 0.4))
			var leader_spine := _make_curved_spine(oak_fork_pt, leader_end, 6, 0.32, rng)
			_append_tube_along_spine(st_wood, leader_spine, 0.26, 0.045, 8, false)
			_append_spray_rosette(st_leaf, leader_end, oak_dome, 2.05, false, 8, rng)

			for b_oak in range(11):
				var t_oak := float(b_oak) / 10.0
				var orig_oak := oak_fork_pt if b_oak < 4 else _sample_spine(leader_spine, lerpf(0.18, 0.86, float(b_oak - 3) / 7.0))
				var yaw_oak := float(b_oak) * 2.399 + rng.randf_range(-0.25, 0.25)
				var rad_oak := lerpf(4.6, 2.6, t_oak * 0.75) * rng.randf_range(0.88, 1.15)
				var rise_oak := lerpf(2.2, 3.6, 1.0 - absf(t_oak - 0.35)) + rng.randf_range(-0.4, 0.5)
				var b_end_oak := orig_oak + Vector3(cos(yaw_oak) * rad_oak, rise_oak, sin(yaw_oak) * rad_oak)
				var b_sp_oak := _make_curved_spine(orig_oak, b_end_oak, 6, 0.30, rng)
				_append_tube_along_spine(st_wood, b_sp_oak, lerpf(0.19, 0.085, t_oak), 0.024, 7, false)

				for sub_side: float in [-1.0, 1.0]:
					var so_t := 0.44 if sub_side < 0.0 else 0.70
					var so_pt := _sample_spine(b_sp_oak, so_t)
					var sy_oak: float = yaw_oak + sub_side * rng.randf_range(0.55, 0.85)
					var slen_oak := rad_oak * rng.randf_range(0.42, 0.56)
					var se_pt := so_pt + Vector3(cos(sy_oak) * slen_oak, rng.randf_range(0.35, 1.05), sin(sy_oak) * slen_oak)
					var ssp_oak := _make_curved_spine(so_pt, se_pt, 4, 0.16, rng)
					_append_tube_along_spine(st_wood, ssp_oak, 0.072, 0.018, 5, false)
					_append_spray_rosette(st_leaf, _sample_spine(ssp_oak, 0.65), oak_dome, rng.randf_range(1.55, 1.95), false, 7, rng)
					_append_spray_rosette(st_leaf, se_pt, oak_dome, rng.randf_range(1.70, 2.15), false, 8, rng)

				for c_oak: float in [0.58, 0.85, 1.0]:
					_append_spray_rosette(st_leaf, _sample_spine(b_sp_oak, c_oak), oak_dome, rng.randf_range(1.75, 2.25), false, 8, rng)

		TreeSpecies.MAPLE:
			# Клён остролистный (Acer platanoides): плотная округлая крона с первыми золотисто-рыжими листьями августа
			var h_map := rng.randf_range(11.6, 14.8)
			var lean_map := Vector2(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.28, 0.28))
			var sp_map := _make_curved_spine(Vector3.ZERO, Vector3(lean_map.x, h_map, lean_map.y), 10, 0.18, rng)
			_append_tube_along_spine(st_wood, sp_map, 0.31, 0.040, 10, true)
			var map_dome := Vector3(lean_map.x * 0.5, h_map * 0.44, lean_map.y * 0.5)

			for b_m in range(26):
				var tm := lerpf(0.26, 0.96, float(b_m) / 25.0)
				var orig_m := _sample_spine(sp_map, tm)
				var yaw_m := float(b_m) * 2.399 + rng.randf_range(-0.22, 0.22)
				var dome_prof := sin(clampf((tm - 0.22) / 0.76, 0.0, 1.0) * PI * 0.94)
				var blen_m := (1.35 + 2.65 * dome_prof) * rng.randf_range(0.90, 1.14)
				var end_m := orig_m + Vector3(cos(yaw_m) * blen_m, blen_m * (0.42 - tm * 0.22), sin(yaw_m) * blen_m)
				var bsp_m := _make_curved_spine(orig_m, end_m, 5, 0.14, rng)
				_append_tube_along_spine(st_wood, bsp_m, lerpf(0.088, 0.026, tm), 0.010, 6, false)

				if b_m % 2 == 0:
					var sub_om := _sample_spine(bsp_m, 0.48)
					var sub_ym := yaw_m + (0.62 if (b_m % 4 == 0) else -0.62)
					var sub_em := sub_om + Vector3(cos(sub_ym) * blen_m * 0.52, blen_m * 0.16, sin(sub_ym) * blen_m * 0.52)
					var sub_spm := _make_curved_spine(sub_om, sub_em, 3, 0.08, rng)
					_append_tube_along_spine(st_wood, sub_spm, 0.036, 0.010, 4, false)
					_append_spray_rosette(st_leaf, sub_em, map_dome, rng.randf_range(1.42, 1.80), false, 7, rng)

				for cm_step: float in [0.54, 0.82, 1.0]:
					_append_spray_rosette(st_leaf, _sample_spine(bsp_m, cm_step), map_dome, rng.randf_range(1.48, 1.92), false, 8, rng)
			_append_spray_rosette(st_leaf, sp_map[sp_map.size() - 1], map_dome, 1.82, false, 8, rng)

		TreeSpecies.ASPEN:
			# Осина обыкновенная (Populus tremula): высокий серо-зеленоватый ствол и трепещущая верхняя крона
			var h_asp := rng.randf_range(13.4, 16.8)
			var lean_asp := Vector2(rng.randf_range(-0.30, 0.30), rng.randf_range(-0.30, 0.30))
			var sp_asp := _make_curved_spine(Vector3.ZERO, Vector3(lean_asp.x, h_asp, lean_asp.y), 10, 0.16, rng)
			_append_tube_along_spine(st_wood, sp_asp, 0.25, 0.032, 10, true)
			var asp_dome := Vector3(lean_asp.x * 0.5, h_asp * 0.52, lean_asp.y * 0.5)

			for b_a in range(26):
				var ta := lerpf(0.36, 0.97, float(b_a) / 25.0)
				var orig_a := _sample_spine(sp_asp, ta)
				var yaw_a := float(b_a) * 2.399 + rng.randf_range(-0.24, 0.24)
				var prof_a := sin(clampf((ta - 0.32) / 0.68, 0.0, 1.0) * PI * 0.90)
				var blen_a := (1.05 + 1.95 * prof_a) * rng.randf_range(0.88, 1.15)
				var end_a := orig_a + Vector3(cos(yaw_a) * blen_a, blen_a * 0.38, sin(yaw_a) * blen_a)
				var bsp_a := _make_curved_spine(orig_a, end_a, 4, 0.11, rng)
				_append_tube_along_spine(st_wood, bsp_a, lerpf(0.062, 0.020, ta), 0.008, 5, false)

				if b_a % 2 == 1:
					var sub_oa := _sample_spine(bsp_a, 0.50)
					var sub_ya := yaw_a + (0.58 if (b_a % 4 == 1) else -0.58)
					var sub_ea := sub_oa + Vector3(cos(sub_ya) * blen_a * 0.50, blen_a * 0.18, sin(sub_ya) * blen_a * 0.50)
					_append_tube_along_spine(st_wood, [sub_oa, sub_ea], 0.026, 0.008, 4, false)
					_append_spray_rosette(st_leaf, sub_ea, asp_dome, rng.randf_range(1.22, 1.56), false, 7, rng)

				for ca_step: float in [0.56, 0.86, 1.0]:
					_append_spray_rosette(st_leaf, _sample_spine(bsp_a, ca_step), asp_dome, rng.randf_range(1.28, 1.66), false, 8, rng)
			_append_spray_rosette(st_leaf, sp_asp[sp_asp.size() - 1], asp_dome, 1.55, false, 8, rng)

		_: # ORCHARD (раскидистая садовая яблоня у деревенских домов)
			var h4 := rng.randf_range(6.0, 7.8)
			var fork_h := h4 * 0.35
			var trunk_spine := _make_curved_spine(Vector3.ZERO, Vector3(0.08, fork_h, -0.06), 5, 0.14, rng)
			_append_tube_along_spine(st_wood, trunk_spine, 0.25, 0.16, 9, true)
			var fork_pt := trunk_spine[trunk_spine.size() - 1]
			var orch_dome := Vector3(0.0, h4 * 0.36, 0.0)

			for limb in range(9):
				var yaw4 := float(limb) * (TAU / 9.0) + rng.randf_range(-0.22, 0.22)
				var rad4 := rng.randf_range(2.35, 3.35)
				var limb_end := fork_pt + Vector3(cos(yaw4) * rad4, h4 - fork_h + rng.randf_range(-0.55, 0.55), sin(yaw4) * rad4)
				var l_spine := _make_curved_spine(fork_pt, limb_end, 5, 0.18, rng)
				_append_tube_along_spine(st_wood, l_spine, 0.108, 0.020, 6, false)

				var sub_o := _sample_spine(l_spine, 0.50)
				var sub_y4 := yaw4 + (0.58 if limb % 2 == 0 else -0.58)
				var sub_e4 := sub_o + Vector3(cos(sub_y4) * rad4 * 0.48, 0.34, sin(sub_y4) * rad4 * 0.48)
				_append_tube_along_spine(st_wood, [sub_o, sub_e4], 0.042, 0.012, 4, false)
				_append_spray_rosette(st_leaf, sub_e4, orch_dome, rng.randf_range(1.32, 1.62), false, 7, rng)

				for c_step4: float in [0.46, 0.76, 1.0]:
					_append_spray_rosette(st_leaf, _sample_spine(l_spine, c_step4), orch_dome, rng.randf_range(1.38, 1.78), false, 8, rng)

	st_wood.generate_tangents()
	st_leaf.generate_tangents()

	var mesh := ArrayMesh.new()
	st_wood.commit(mesh)
	st_leaf.commit(mesh)

	match species:
		TreeSpecies.BIRCH:
			mesh.surface_set_material(0, _get_birch_bark_material())
		TreeSpecies.PINE:
			mesh.surface_set_material(0, _get_pine_bark_material())
		TreeSpecies.OAK:
			mesh.surface_set_material(0, _get_oak_bark_material())
		TreeSpecies.MAPLE:
			mesh.surface_set_material(0, _get_maple_bark_material())
		TreeSpecies.ASPEN:
			mesh.surface_set_material(0, _get_aspen_bark_material())
		_:
			mesh.surface_set_material(0, _get_dark_bark_material())

	mesh.surface_set_material(1, _get_canopy_material(species))
	return mesh


## Раскладывает веер настоящих фотосканированных еловых лап СТРОГО вдоль направления ветви ели
static func _append_spruce_branch_boughs(
	st: SurfaceTool,
	b_spine: Array[Vector3],
	branch_yaw: float,
	b_len: float,
	height_t: float,
	dome_origin: Vector3,
	rng: RandomNumberGenerator
) -> void:
	var align_yaw := PI * 0.5 - branch_yaw
	var size_scale := clampf(b_len * 0.54 + 0.44, 0.56, 1.74)

	if height_t < 0.78:
		var p_inner := _sample_spine(b_spine, 0.20)
		for side: float in [-1.0, 1.0]:
			var byaw: float = align_yaw + side * rng.randf_range(0.46, 0.64)
			var bpitch := deg_to_rad(rng.randf_range(12.0, 24.0))
			var broll: float = side * deg_to_rad(rng.randf_range(8.0, 16.0))
			var basis := Basis(Vector3.UP, byaw) * Basis(Vector3.RIGHT, bpitch) * Basis(Vector3.FORWARD, broll)
			var poly: Array = FIR_BOUGH_POLYS[rng.randi() % 4]
			var l := size_scale * rng.randf_range(0.84, 1.04)
			_append_curved_bough_card(st, p_inner, basis, l * 0.94, l, -0.13 * l, 0.34, 0.84, poly, dome_origin, rng.randf(), 0.66)

	var p_mid := _sample_spine(b_spine, 0.46)
	for side2: float in [-1.0, 1.0]:
		var myaw: float = align_yaw + side2 * rng.randf_range(0.32, 0.48)
		var mpitch := deg_to_rad(rng.randf_range(10.0, 20.0))
		var mroll: float = side2 * deg_to_rad(rng.randf_range(7.0, 14.0))
		var mbasis := Basis(Vector3.UP, myaw) * Basis(Vector3.RIGHT, mpitch) * Basis(Vector3.FORWARD, mroll)
		var mpoly: Array = FIR_BOUGH_POLYS[rng.randi() % 2]
		var ml := size_scale * rng.randf_range(0.90, 1.10)
		_append_curved_bough_card(st, p_mid, mbasis, ml * 0.96, ml, -0.14 * ml, 0.34, 0.84, mpoly, dome_origin, rng.randf(), 0.82)

	if height_t < 0.88:
		var cbasis := Basis(Vector3.UP, align_yaw + rng.randf_range(-0.08, 0.08)) * Basis(Vector3.RIGHT, deg_to_rad(8.0))
		var cl := size_scale * rng.randf_range(0.84, 1.02)
		_append_curved_bough_card(st, p_mid + Vector3(0.0, 0.04, 0.0), cbasis, cl * 0.92, cl, -0.10 * cl, 0.34, 0.84, FIR_BOUGH_POLYS[rng.randi() % 2], dome_origin, rng.randf(), 0.90)

	var p_tip := _sample_spine(b_spine, 0.68)
	var tbasis := Basis(Vector3.UP, align_yaw + rng.randf_range(-0.06, 0.06)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(2.0, 12.0)))
	var tl := size_scale * rng.randf_range(0.92, 1.12)
	_append_curved_bough_card(st, p_tip, tbasis, tl * 0.96, tl, -0.10 * tl, 0.32, 0.86, FIR_BOUGH_POLYS[rng.randi() % 2], dome_origin, rng.randf(), 0.98)


## Объёмная 3D-розетка из 7–8 многолистных фотосканированных ветвей
static func _append_spray_rosette(
	st: SurfaceTool,
	center: Vector3,
	dome_origin: Vector3,
	radius: float,
	drooping: bool,
	card_count: int,
	rng: RandomNumberGenerator
) -> void:
	var base_yaw := rng.randf() * TAU
	for c in range(card_count):
		var yaw := base_yaw + float(c) * (TAU / float(card_count)) + rng.randf_range(-0.22, 0.22)
		var tier := c % 3
		var pitch_deg: float
		if drooping:
			pitch_deg = rng.randf_range(-10.0, 10.0) if tier == 0 else (rng.randf_range(14.0, 32.0) if tier == 1 else rng.randf_range(30.0, 48.0))
		else:
			pitch_deg = rng.randf_range(-18.0, 4.0) if tier == 0 else (rng.randf_range(6.0, 22.0) if tier == 1 else rng.randf_range(18.0, 32.0))
		var roll := rng.randf_range(-0.30, 0.30)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(pitch_deg)) * Basis(Vector3.FORWARD, roll)

		var sz := radius * rng.randf_range(0.96, 1.18)
		var arch := (-0.16 if drooping else -0.10) * sz
		var card_origin := center + Vector3(
			cos(yaw) * radius * 0.10,
			(0.14 if tier == 0 else (0.02 if tier == 1 else -0.08)) * radius,
			sin(yaw) * radius * 0.10
		)
		var ao := 0.98 if tier == 0 else (0.86 if tier == 1 else 0.72)
		_append_curved_bough_card(st, card_origin, basis, sz, sz, arch, 0.56, 0.92, FULL_SPRAY_POLY, dome_origin, rng.randf(), ao)


static func _append_curved_bough_card(
	st: SurfaceTool,
	card_origin: Vector3,
	basis: Basis,
	w: float,
	l: float,
	arch_y: float,
	base_taper: float,
	tip_taper: float,
	uv_poly: Array,
	dome_origin: Vector3,
	seed_val: float,
	ao_val: float
) -> void:
	var hw_base := w * 0.5 * base_taper
	var hw_mid := w * 0.5
	var hw_tip := w * 0.5 * tip_taper

	var p00 := card_origin + basis * Vector3(-hw_base, 0.0, -l * 0.06)
	var p10 := card_origin + basis * Vector3(hw_base, 0.0, -l * 0.06)
	var p0m := card_origin + basis * Vector3(-hw_mid, arch_y * 0.35, l * 0.44)
	var p1m := card_origin + basis * Vector3(hw_mid, arch_y * 0.35, l * 0.44)
	var p01 := card_origin + basis * Vector3(-hw_tip, arch_y, l * 0.94)
	var p11 := card_origin + basis * Vector3(hw_tip, arch_y, l * 0.94)

	var n00 := (p00 - dome_origin).normalized()
	var n10 := (p10 - dome_origin).normalized()
	var n0m := (p0m - dome_origin).normalized()
	var n1m := (p1m - dome_origin).normalized()
	var n01 := (p01 - dome_origin).normalized()
	var n11 := (p11 - dome_origin).normalized()

	var uv00: Vector2 = uv_poly[0]
	var uv10: Vector2 = uv_poly[1]
	var uv1m: Vector2 = uv_poly[2]
	var uv11: Vector2 = uv_poly[3]
	var uv01: Vector2 = uv_poly[4]
	var uv0m: Vector2 = uv_poly[5]

	var base_col := Color(seed_val, 0.12, ao_val * 0.86, 1.0)
	var mid_col  := Color(seed_val, 0.52, ao_val * 0.94, 1.0)
	var tip_col  := Color(seed_val, 1.00, ao_val, 1.0)

	st.set_normal(n00); st.set_color(base_col); st.set_uv(uv00); st.add_vertex(p00)
	st.set_normal(n1m); st.set_color(mid_col);  st.set_uv(uv1m); st.add_vertex(p1m)
	st.set_normal(n0m); st.set_color(mid_col);  st.set_uv(uv0m); st.add_vertex(p0m)

	st.set_normal(n00); st.set_color(base_col); st.set_uv(uv00); st.add_vertex(p00)
	st.set_normal(n10); st.set_color(base_col); st.set_uv(uv10); st.add_vertex(p10)
	st.set_normal(n1m); st.set_color(mid_col);  st.set_uv(uv1m); st.add_vertex(p1m)

	st.set_normal(n0m); st.set_color(mid_col);  st.set_uv(uv0m); st.add_vertex(p0m)
	st.set_normal(n11); st.set_color(tip_col);  st.set_uv(uv11); st.add_vertex(p11)
	st.set_normal(n01); st.set_color(tip_col);  st.set_uv(uv01); st.add_vertex(p01)

	st.set_normal(n0m); st.set_color(mid_col);  st.set_uv(uv0m); st.add_vertex(p0m)
	st.set_normal(n1m); st.set_color(mid_col);  st.set_uv(uv1m); st.add_vertex(p1m)
	st.set_normal(n11); st.set_color(tip_col);  st.set_uv(uv11); st.add_vertex(p11)


# ============================================================================
# СБОРКА СОСТАВНЫХ RGBA8-ВЕТВЕЙ (АВТОМАСШТАБ: 1024² В 1K -> 2048² В 2K/4K ПОД RTX 4070!)
# ============================================================================

static func _load_image_any(res_path: String) -> Image:
	if ResourceLoader.exists(res_path):
		var tex := load(res_path)
		if tex is Texture2D:
			var img := (tex as Texture2D).get_image()
			if img != null and not img.is_empty():
				if img.is_compressed():
					img.decompress()
				return img
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		return Image.load_from_file(abs_p)
	return null


static func _get_spray_res_mult() -> int:
	var probe := AssetCatalog._load_texture_safe("res://assets/downloaded/textures/oak_leaf/diff.jpg")
	if probe != null and probe.get_width() >= 2048:
		return 2
	return 1


static func _extract_rgba_crop(
	diff_path: String,
	alpha_path: String,
	uv_rect: Rect2,
	target_w: int,
	target_h: int,
	bleed_rgb: Color,
	mask_pine_corner: bool = false,
	unpremultiply_black: bool = true
) -> Image:
	var d_img := _load_image_any(diff_path)
	var a_img := _load_image_any(alpha_path)
	if d_img == null or a_img == null or d_img.is_empty() or a_img.is_empty():
		var fallback := Image.create(target_w, target_h, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(bleed_rgb.r, bleed_rgb.g, bleed_rgb.b, 0.0))
		return fallback

	var rx := int(uv_rect.position.x * float(d_img.get_width()))
	var ry := int(uv_rect.position.y * float(d_img.get_height()))
	var rw := maxi(8, int(uv_rect.size.x * float(d_img.get_width())))
	var rh := maxi(8, int(uv_rect.size.y * float(d_img.get_height())))

	var dc := d_img.get_region(Rect2i(rx, ry, rw, rh))
	var ac := a_img.get_region(Rect2i(
		int(uv_rect.position.x * float(a_img.get_width())),
		int(uv_rect.position.y * float(a_img.get_height())),
		maxi(8, int(uv_rect.size.x * float(a_img.get_width()))),
		maxi(8, int(uv_rect.size.y * float(a_img.get_height())))
	))
	dc.resize(target_w, target_h, Image.INTERPOLATE_BILINEAR)
	ac.resize(target_w, target_h, Image.INTERPOLATE_BILINEAR)

	var out := Image.create(target_w, target_h, false, Image.FORMAT_RGBA8)
	for y in range(target_h):
		var v_norm := float(y) / float(target_h)
		for x in range(target_w):
			var a := ac.get_pixel(x, y).r
			if mask_pine_corner and v_norm > 0.80:
				var u_norm := float(x) / float(target_w)
				if u_norm < 0.24 or u_norm > 0.76:
					a = 0.0
			if a < 0.14:
				out.set_pixel(x, y, Color(bleed_rgb.r, bleed_rgb.g, bleed_rgb.b, 0.0))
			else:
				var c := dc.get_pixel(x, y)
				var inv := (1.0 / maxf(a, 0.38)) if unpremultiply_black else 1.0
				out.set_pixel(x, y, Color(
					clampf(c.r * inv, 0.0, 1.0),
					clampf(c.g * inv, 0.0, 1.0),
					clampf(c.b * inv, 0.0, 1.0),
					clampf((a - 0.12) / 0.88, 0.0, 1.0)
				))
	return out


static func _rotate_rgba_stamp(src: Image, angle_rad: float, bleed_rgb: Color) -> Image:
	var sw := src.get_width()
	var sh := src.get_height()
	var cs := cos(angle_rad)
	var sn := sin(angle_rad)
	var dw := int(ceil(absf(float(sw) * cs) + absf(float(sh) * sn))) + 2
	var dh := int(ceil(absf(float(sw) * sn) + absf(float(sh) * cs))) + 2
	var dst := Image.create(dw, dh, false, Image.FORMAT_RGBA8)
	dst.fill(Color(bleed_rgb.r, bleed_rgb.g, bleed_rgb.b, 0.0))

	var cx := float(sw) * 0.5
	var cy := float(sh) * 0.5
	var dcx := float(dw) * 0.5
	var dcy := float(dh) * 0.5

	for dy in range(dh):
		var ry := float(dy) - dcy
		for dx in range(dw):
			var rx := float(dx) - dcx
			var sx := int(round(rx * cs + ry * sn + cx))
			var sy := int(round(-rx * sn + ry * cs + cy))
			if sx >= 0 and sx < sw and sy >= 0 and sy < sh:
				var p := src.get_pixel(sx, sy)
				if p.a > 0.05:
					dst.set_pixel(dx, dy, p)
	return dst


static func _draw_wood_twig_segment(canvas: Image, p0: Vector2, p1: Vector2, r0: float, r1: float, col: Color) -> void:
	var steps := maxi(8, int(p0.distance_to(p1) * 0.5))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := p0.lerp(p1, t)
		var r := maxi(1, int(round(lerpf(r0, r1, t))))
		canvas.fill_rect(Rect2i(int(p.x) - r, int(p.y) - r, r * 2 + 1, r * 2 + 1), col)


static func _stamp_centered(canvas: Image, stamp: Image, center: Vector2i) -> void:
	var sw := stamp.get_width()
	var sh := stamp.get_height()
	var dst_pt := Vector2i(center.x - sw / 2, center.y - sh / 2)
	canvas.blit_rect_mask(stamp, stamp, Rect2i(0, 0, sw, sh), dst_pt)


static func _build_deciduous_branch_spray(
	stamps_up: Array[Image],
	bleed: Color,
	wood_col: Color,
	res_m: int,
	is_oak_clustered: bool = false
) -> Texture2D:
	var m := float(res_m)
	var base_img: Image = stamps_up[0]
	var alt_img: Image = stamps_up[1 % stamps_up.size()]
	var acc_img: Image = stamps_up[2 % stamps_up.size()]

	var r38 := _rotate_rgba_stamp(base_img, deg_to_rad(38.0), bleed)
	var l38 := r38.duplicate() as Image
	l38.flip_x()

	var r68 := _rotate_rgba_stamp(alt_img, deg_to_rad(68.0), bleed)
	var l68 := r68.duplicate() as Image
	l68.flip_x()

	var acc_r48 := _rotate_rgba_stamp(acc_img, deg_to_rad(48.0), bleed)
	var acc_l48 := acc_r48.duplicate() as Image
	acc_l48.flip_x()

	var csize := 1024 * res_m
	var canvas := Image.create(csize, csize, false, Image.FORMAT_RGBA8)
	canvas.fill(bleed)

	_draw_wood_twig_segment(canvas, Vector2(512, 990) * m, Vector2(502, 535) * m, 4.5 * m, 2.6 * m, wood_col)
	_draw_wood_twig_segment(canvas, Vector2(502, 535) * m, Vector2(514, 140) * m, 2.6 * m, 1.3 * m, wood_col)

	var side_specs := [
		[Vector2(508, 865), Vector2(195, 645), true],
		[Vector2(506, 825), Vector2(825, 605), false],
		[Vector2(503, 655), Vector2(155, 420), true],
		[Vector2(504, 615), Vector2(860, 390), false],
		[Vector2(507, 445), Vector2(225, 225), true],
		[Vector2(510, 410), Vector2(790, 205), false],
	]
	for sp_idx in range(side_specs.size()):
		var sp: Array = side_specs[sp_idx]
		var a: Vector2 = (sp[0] as Vector2) * m
		var b: Vector2 = (sp[1] as Vector2) * m
		var is_left: bool = sp[2]
		_draw_wood_twig_segment(canvas, a, b, 2.4 * m, 1.1 * m, wood_col)
		var fracs: Array = [0.42, 0.78, 1.0] if is_oak_clustered else [0.34, 0.66, 0.98]
		for f_idx in range(fracs.size()):
			var f: float = fracs[f_idx]
			var pt := a.lerp(b, f)
			var st_img: Image
			if f_idx == 2 and (sp_idx % 2 == 1):
				st_img = acc_l48 if is_left else acc_r48
			elif f > 0.62:
				st_img = l68 if is_left else r68
			else:
				st_img = l38 if is_left else r38
			_stamp_centered(canvas, st_img, Vector2i(int(pt.x), int(pt.y)))

	for c_pt in [
		[Vector2(470, 745), l38],
		[Vector2(555, 695), r38],
		[Vector2(460, 520), base_img],
		[Vector2(558, 490), acc_r48],
		[Vector2(465, 315), acc_l48],
		[Vector2(560, 290), r38],
		[Vector2(430, 168), l38],
		[Vector2(595, 168), r38],
		[Vector2(512, 142), alt_img],
	]:
		var p_scaled: Vector2 = (c_pt[0] as Vector2) * m
		_stamp_centered(canvas, c_pt[1], Vector2i(int(p_scaled.x), int(p_scaled.y)))

	canvas.generate_mipmaps()
	return ImageTexture.create_from_image(canvas)


static func _get_birch_spray_texture() -> Texture2D:
	if _birch_spray_tex != null:
		return _birch_spray_tex
	var rm := _get_spray_res_mult()
	var bleed := Color(0.22, 0.34, 0.09, 0.0)
	var t0 := _extract_rgba_crop("res://assets/downloaded/textures/leaf_twig/diff.jpg", "res://assets/downloaded/textures/leaf_twig/alpha.jpg", Rect2(0.014, 0.006, 0.400, 0.984), 136 * rm, 168 * rm, bleed, false, true)
	var t1 := t0.duplicate() as Image
	t1.flip_x()
	_birch_spray_tex = _build_deciduous_branch_spray([t0, t1, t0], bleed, Color(0.26, 0.20, 0.15, 1.0), rm, false)
	return _birch_spray_tex


static func _get_orchard_spray_texture() -> Texture2D:
	if _orchard_spray_tex != null:
		return _orchard_spray_tex
	var rm := _get_spray_res_mult()
	var bleed := Color(0.18, 0.31, 0.08, 0.0)
	var t0 := _extract_rgba_crop("res://assets/downloaded/textures/leaf_twig/diff.jpg", "res://assets/downloaded/textures/leaf_twig/alpha.jpg", Rect2(0.014, 0.006, 0.400, 0.984), 168 * rm, 206 * rm, bleed, false, true)
	var t1 := t0.duplicate() as Image
	t1.flip_x()
	_orchard_spray_tex = _build_deciduous_branch_spray([t0, t1, t0], bleed, Color(0.24, 0.18, 0.13, 1.0), rm, false)
	return _orchard_spray_tex


static func _get_oak_spray_texture() -> Texture2D:
	if _oak_spray_tex != null:
		return _oak_spray_tex
	var rm := _get_spray_res_mult()
	var bleed := Color(0.18, 0.28, 0.08, 0.0)
	var o0 := _extract_rgba_crop("res://assets/downloaded/textures/oak_leaf/diff.jpg", "res://assets/downloaded/textures/oak_leaf/alpha.jpg", Rect2(0.025, 0.020, 0.265, 0.450), 132 * rm, 210 * rm, bleed, false, true)
	var o1 := _extract_rgba_crop("res://assets/downloaded/textures/oak_leaf/diff.jpg", "res://assets/downloaded/textures/oak_leaf/alpha.jpg", Rect2(0.020, 0.540, 0.315, 0.435), 152 * rm, 205 * rm, bleed, false, true)
	var o2 := _extract_rgba_crop("res://assets/downloaded/textures/oak_leaf/diff.jpg", "res://assets/downloaded/textures/oak_leaf/alpha.jpg", Rect2(0.365, 0.555, 0.285, 0.415), 140 * rm, 198 * rm, bleed, false, true)
	_oak_spray_tex = _build_deciduous_branch_spray([o0, o1, o2], bleed, Color(0.22, 0.16, 0.11, 1.0), rm, true)
	return _oak_spray_tex


static func _get_maple_spray_texture() -> Texture2D:
	if _maple_spray_tex != null:
		return _maple_spray_tex
	var rm := _get_spray_res_mult()
	var bleed := Color(0.24, 0.34, 0.09, 0.0)
	var m0 := _extract_rgba_crop("res://assets/downloaded/textures/maple_leaf/diff.jpg", "res://assets/downloaded/textures/maple_leaf/alpha.jpg", Rect2(0.045, 0.030, 0.440, 0.445), 176 * rm, 182 * rm, bleed, false, true)
	var m1 := _extract_rgba_crop("res://assets/downloaded/textures/maple_leaf/diff.jpg", "res://assets/downloaded/textures/maple_leaf/alpha.jpg", Rect2(0.055, 0.485, 0.405, 0.495), 168 * rm, 192 * rm, bleed, false, true)
	# Августовский кленовый лист с первыми золотисто-оранжевыми прожилками (LeafSet027 — фон уже дилатирован!)
	var m_aug := _extract_rgba_crop("res://assets/downloaded/textures/maple_aug_leaf/diff.jpg", "res://assets/downloaded/textures/maple_aug_leaf/alpha.jpg", Rect2(0.350, 0.015, 0.300, 0.305), 172 * rm, 178 * rm, bleed, false, false)
	_maple_spray_tex = _build_deciduous_branch_spray([m0, m1, m_aug], bleed, Color(0.25, 0.18, 0.13, 1.0), rm, false)
	return _maple_spray_tex


static func _get_aspen_spray_texture() -> Texture2D:
	if _aspen_spray_tex != null:
		return _aspen_spray_tex
	var rm := _get_spray_res_mult()
	var bleed := Color(0.20, 0.33, 0.11, 0.0)
	var a0 := _extract_rgba_crop("res://assets/downloaded/textures/aspen_leaf/diff.jpg", "res://assets/downloaded/textures/aspen_leaf/alpha.jpg", Rect2(0.035, 0.005, 0.270, 0.330), 126 * rm, 156 * rm, bleed, false, false)
	var a1 := _extract_rgba_crop("res://assets/downloaded/textures/aspen_leaf/diff.jpg", "res://assets/downloaded/textures/aspen_leaf/alpha.jpg", Rect2(0.375, 0.005, 0.250, 0.325), 122 * rm, 152 * rm, bleed, false, false)
	var a2 := _extract_rgba_crop("res://assets/downloaded/textures/aspen_leaf/diff.jpg", "res://assets/downloaded/textures/aspen_leaf/alpha.jpg", Rect2(0.040, 0.338, 0.255, 0.325), 124 * rm, 154 * rm, bleed, false, false)
	_aspen_spray_tex = _build_deciduous_branch_spray([a0, a1, a2], bleed, Color(0.27, 0.26, 0.20, 1.0), rm, false)
	return _aspen_spray_tex


static func _get_pine_bough_texture() -> Texture2D:
	if _pine_bough_tex != null:
		return _pine_bough_tex
	var rm := _get_spray_res_mult()
	var m := float(rm)
	var bleed := Color(0.14, 0.24, 0.08, 0.0)
	var shoot0 := _extract_rgba_crop(
		"res://assets/downloaded/textures/pine_twig/diff.jpg",
		"res://assets/downloaded/textures/pine_twig/alpha.jpg",
		Rect2(0.028, 0.038, 0.192, 0.398),
		148 * rm, 296 * rm, bleed, true, true
	)
	var shoot_flip := shoot0.duplicate() as Image
	shoot_flip.flip_x()
	var shoot_r35 := _rotate_rgba_stamp(shoot0, deg_to_rad(35.0), bleed)
	var shoot_l35 := shoot_r35.duplicate() as Image
	shoot_l35.flip_x()
	var shoot_r65 := _rotate_rgba_stamp(shoot0, deg_to_rad(65.0), bleed)
	var shoot_l65 := shoot_r65.duplicate() as Image
	shoot_l65.flip_x()

	var csize := 1024 * rm
	var canvas := Image.create(csize, csize, false, Image.FORMAT_RGBA8)
	canvas.fill(bleed)

	var bark_col := Color(0.32, 0.21, 0.13, 1.0)
	_draw_wood_twig_segment(canvas, Vector2(512, 975) * m, Vector2(512, 260) * m, 6.0 * m, 2.5 * m, bark_col)
	_draw_wood_twig_segment(canvas, Vector2(512, 760) * m, Vector2(230, 480) * m, 4.0 * m, 2.0 * m, bark_col)
	_draw_wood_twig_segment(canvas, Vector2(512, 740) * m, Vector2(795, 470) * m, 4.0 * m, 2.0 * m, bark_col)
	_draw_wood_twig_segment(canvas, Vector2(512, 520) * m, Vector2(280, 260) * m, 3.2 * m, 1.8 * m, bark_col)
	_draw_wood_twig_segment(canvas, Vector2(512, 500) * m, Vector2(745, 250) * m, 3.2 * m, 1.8 * m, bark_col)

	for st_spec in [
		[Vector2(350, 660), shoot_l65], [Vector2(675, 650), shoot_r65],
		[Vector2(220, 500), shoot_l65], [Vector2(805, 490), shoot_r65],
		[Vector2(265, 410), shoot_l35], [Vector2(760, 400), shoot_r35],
		[Vector2(395, 540), shoot_l35], [Vector2(630, 530), shoot_r35],
		[Vector2(320, 290), shoot_l65], [Vector2(705, 285), shoot_r65],
		[Vector2(270, 220), shoot_l35], [Vector2(755, 215), shoot_r35],
		[Vector2(420, 350), shoot0],     [Vector2(605, 345), shoot_flip],
		[Vector2(435, 195), shoot_l35], [Vector2(590, 195), shoot_r35],
		[Vector2(512, 175), shoot0],     [Vector2(512, 390), shoot_flip],
		[Vector2(485, 610), shoot0],     [Vector2(540, 620), shoot_flip],
	]:
		var ps: Vector2 = (st_spec[0] as Vector2) * m
		_stamp_centered(canvas, st_spec[1], Vector2i(int(ps.x), int(ps.y)))

	canvas.generate_mipmaps()
	_pine_bough_tex = ImageTexture.create_from_image(canvas)
	return _pine_bough_tex


static func _get_flat_normal_texture() -> Texture2D:
	if _flat_normal_tex != null:
		return _flat_normal_tex
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.5, 0.5, 1.0, 1.0))
	_flat_normal_tex = ImageTexture.create_from_image(img)
	return _flat_normal_tex


static func _make_curved_spine(p_start: Vector3, p_end: Vector3, segments: int, wander: float, rng: RandomNumberGenerator) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var phase_x := rng.randf() * TAU
	var phase_z := rng.randf() * TAU
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := p_start.lerp(p_end, t)
		var env := sin(t * PI)
		p.x += sin(t * 4.2 + phase_x) * wander * env
		p.z += cos(t * 3.8 + phase_z) * wander * env
		pts.append(p)
	return pts


static func _sample_spine(spine: Array[Vector3], t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * float(spine.size() - 1)
	var i0 := int(floor(f))
	var i1 := mini(i0 + 1, spine.size() - 1)
	return spine[i0].lerp(spine[i1], f - float(i0))


static func _append_tube_along_spine(
	st: SurfaceTool,
	spine: Array[Vector3],
	r_base: float,
	r_tip: float,
	radial_segs: int,
	root_flare: bool
) -> void:
	var rings: Array = []
	var v_accum := 0.0
	var prev_right := Vector3.ZERO

	for i in range(spine.size()):
		var t := float(i) / float(max(1, spine.size() - 1))
		var center := spine[i]
		var tangent: Vector3
		if i == 0:
			tangent = (spine[1] - spine[0]).normalized()
		elif i == spine.size() - 1:
			tangent = (spine[i] - spine[i - 1]).normalized()
		else:
			tangent = (spine[i + 1] - spine[i - 1]).normalized()
		if i > 0:
			v_accum += spine[i].distance_to(spine[i - 1]) * 0.65

		var right: Vector3
		if i == 0 or prev_right.length_squared() < 0.01:
			var ref := Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.75 else Vector3.UP
			right = tangent.cross(ref).normalized()
		else:
			right = prev_right - tangent * prev_right.dot(tangent)
			if right.length_squared() < 0.001:
				var ref2 := Vector3.RIGHT if absf(tangent.dot(Vector3.UP)) > 0.75 else Vector3.UP
				right = tangent.cross(ref2).normalized()
			else:
				right = right.normalized()
		prev_right = right
		var forward := tangent.cross(right).normalized()

		var rad := lerpf(r_base, r_tip, pow(t, 0.82))
		if root_flare and t < 0.14:
			rad *= 1.0 + 0.42 * pow(1.0 - t / 0.14, 2.0)

		var ring_pts: Array[Vector3] = []
		var ring_nrms: Array[Vector3] = []
		for s in range(radial_segs + 1):
			var ang := (float(s) / float(radial_segs)) * TAU
			var lobe := 1.0 + (0.12 * sin(ang * 5.0) * (1.0 - t * 6.0) if (root_flare and t < 0.16) else 0.0)
			var unit_radial := (right * cos(ang) + forward * sin(ang)).normalized()
			var offset := unit_radial * (rad * lobe)
			ring_pts.append(center + offset)
			ring_nrms.append(unit_radial)
		rings.append({"pts": ring_pts, "nrms": ring_nrms, "v": v_accum, "t": t})

	for i in range(rings.size() - 1):
		var r0: Array = rings[i]["pts"]
		var r1: Array = rings[i + 1]["pts"]
		var n0: Array = rings[i]["nrms"]
		var n1: Array = rings[i + 1]["nrms"]
		var v0: float = rings[i]["v"]
		var v1: float = rings[i + 1]["v"]
		var col0 := Color(float(rings[i]["t"]), 0.0, 0.0, 1.0)
		var col1 := Color(float(rings[i + 1]["t"]), 0.0, 0.0, 1.0)

		for s in range(radial_segs):
			var u0 := float(s) / float(radial_segs)
			var u1 := float(s + 1) / float(radial_segs)

			st.set_normal(n0[s]);     st.set_color(col0); st.set_uv(Vector2(u0, v0)); st.add_vertex(r0[s])
			st.set_normal(n1[s]);     st.set_color(col1); st.set_uv(Vector2(u0, v1)); st.add_vertex(r1[s])
			st.set_normal(n1[s + 1]); st.set_color(col1); st.set_uv(Vector2(u1, v1)); st.add_vertex(r1[s + 1])

			st.set_normal(n0[s]);     st.set_color(col0); st.set_uv(Vector2(u0, v0)); st.add_vertex(r0[s])
			st.set_normal(n1[s + 1]); st.set_color(col1); st.set_uv(Vector2(u1, v1)); st.add_vertex(r1[s + 1])
			st.set_normal(n0[s + 1]); st.set_color(col0); st.set_uv(Vector2(u1, v0)); st.add_vertex(r0[s + 1])


# ============================================================================
# 4K PBR-МАТЕРИАЛЫ КОРЫ И ЛИСТВЫ ДЛЯ ВСЕХ 7 ПОРОД
# ============================================================================

static func _get_birch_bark_material() -> Material:
	if _birch_bark_mat != null:
		return _birch_bark_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D bark_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_arm : filter_linear_mipmap_anisotropic, repeat_enable;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float trunk_t = COLOR.r;
	float lenticels = vnoise(vec2(UV.x * 5.5, UV.y * 42.0));
	float patches = vnoise(vec2(UV.x * 3.2, UV.y * 6.5));
	float dark_marks = smoothstep(0.66, 0.78, lenticels) * 0.85 + smoothstep(0.72, 0.86, patches) * 0.65;
	float base_rough_bark = (1.0 - smoothstep(0.03, 0.19, trunk_t)) * smoothstep(0.28, 0.65, patches);

	vec3 white_bark = mix(vec3(0.86, 0.84, 0.79), vec3(0.74, 0.72, 0.66), patches * 0.5);
	vec3 black_bark = vec3(0.10, 0.09, 0.08);
	ALBEDO = mix(white_bark, black_bark, clamp(dark_marks + base_rough_bark, 0.0, 0.96));
	NORMAL_MAP = texture(bark_nor, UV * vec2(1.5, 1.0)).rgb;
	NORMAL_MAP_DEPTH = mix(1.3, 0.55, 1.0 - base_rough_bark);
	vec3 arm = texture(bark_arm, UV * vec2(1.5, 1.0)).rgb;
	AO = arm.r;
	ROUGHNESS = mix(0.76, 0.94, clamp(dark_marks + base_rough_bark, 0.0, 1.0));
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var nor := AssetCatalog._load_texture_safe("res://assets/downloaded/textures/bark_willow_02/nor_gl.jpg")
	var arm := AssetCatalog._load_texture_safe("res://assets/downloaded/textures/bark_willow_02/arm.jpg")
	if nor != null:
		sm.set_shader_parameter("bark_nor", nor)
	if arm != null:
		sm.set_shader_parameter("bark_arm", arm)
	_birch_bark_mat = sm
	return sm


static func _get_pine_bark_material() -> Material:
	if _pine_bark_mat != null:
		return _pine_bark_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D bark_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_arm : filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	float trunk_t = COLOR.r;
	vec3 base_c = texture(bark_alb, UV * vec2(1.4, 0.9)).rgb;
	vec3 upper_amber = base_c * vec3(1.32, 0.88, 0.56);
	ALBEDO = mix(base_c * 0.82, upper_amber, smoothstep(0.32, 0.78, trunk_t));
	NORMAL_MAP = texture(bark_nor, UV * vec2(1.4, 0.9)).rgb;
	NORMAL_MAP_DEPTH = 1.25;
	vec3 arm = texture(bark_arm, UV * vec2(1.4, 0.9)).rgb;
	AO = arm.r;
	ROUGHNESS = clamp(arm.g * 1.05, 0.65, 0.96);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	TerrainBuilder._assign_tex_triplet(sm, "bark", "knotted_pine_bark")
	_pine_bark_mat = sm
	return sm


static func _get_oak_bark_material() -> Material:
	if _oak_bark_mat != null:
		return _oak_bark_mat
	_oak_bark_mat = AssetCatalog.get_pbr_material("jolcham_oak_bark_01", Vector3(1.5, 0.9, 1.5), false, Color(0.88, 0.86, 0.82))
	return _oak_bark_mat


static func _get_maple_bark_material() -> Material:
	if _maple_bark_mat != null:
		return _maple_bark_mat
	_maple_bark_mat = AssetCatalog.get_pbr_material("trident_maple_bark", Vector3(1.3, 0.9, 1.3), false, Color(0.84, 0.80, 0.76))
	return _maple_bark_mat


static func _get_aspen_bark_material() -> Material:
	if _aspen_bark_mat != null:
		return _aspen_bark_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D bark_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_arm : filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	float trunk_t = COLOR.r;
	vec3 raw_b = texture(bark_alb, UV * vec2(1.3, 0.85)).rgb;
	vec3 smooth_grey_green = mix(vec3(0.46, 0.50, 0.41), vec3(0.58, 0.61, 0.52), raw_b.g);
	ALBEDO = mix(raw_b * 0.65, smooth_grey_green, smoothstep(0.10, 0.34, trunk_t));
	NORMAL_MAP = texture(bark_nor, UV * vec2(1.3, 0.85)).rgb;
	NORMAL_MAP_DEPTH = mix(1.25, 0.45, smoothstep(0.12, 0.38, trunk_t));
	vec3 arm = texture(bark_arm, UV * vec2(1.3, 0.85)).rgb;
	AO = arm.r;
	ROUGHNESS = mix(0.92, 0.74, smoothstep(0.12, 0.38, trunk_t));
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	TerrainBuilder._assign_tex_triplet(sm, "bark", "bark_willow")
	_aspen_bark_mat = sm
	return sm


static func _get_dark_bark_material() -> Material:
	if _dark_bark_mat != null:
		return _dark_bark_mat
	_dark_bark_mat = AssetCatalog.get_pbr_material("bark_willow_02", Vector3(1.2, 0.9, 1.2), false, Color(0.76, 0.72, 0.66))
	return _dark_bark_mat


static func _get_pbr_foliage_shader() -> Shader:
	if _pbr_foliage_shader != null:
		return _pbr_foliage_shader
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_alb : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_alpha : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_nor : hint_normal, filter_linear_mipmap_anisotropic;

uniform float use_embedded_rgba = 0.0;
uniform vec3 color_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 warm_var_tint : source_color = vec3(1.14, 1.06, 0.78);
uniform float alpha_scissor = 0.40;
uniform float roughness_val = 0.58;
uniform float backlight_strength = 0.62;
uniform float sky_normal_blend = 0.42;
uniform float wind_strength = 1.0;
uniform float flutter_speed = 4.6;
uniform float flutter_amp = 0.026;

varying vec3 v_wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wpos = wp;
	float flex = COLOR.g;
	float gust = sin(TIME * 1.55 + wp.x * 0.13 + wp.z * 0.10);
	float flutter = sin(TIME * flutter_speed + wp.x * 1.9 + wp.y * 2.3 + COLOR.r * 16.0) * flutter_amp;
	VERTEX.x += (gust * 0.12 + flutter) * flex * wind_strength;
	VERTEX.z += (cos(TIME * 1.28 + wp.z * 0.14) * 0.09 + flutter) * flex * wind_strength;
	VERTEX.y += flutter * 0.48 * flex * wind_strength;
}

void fragment() {
	vec4 sample_c = texture(tex_alb, UV);
	float a = (use_embedded_rgba > 0.5) ? sample_c.a : texture(tex_alpha, UV).r;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 sky_up_vs = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, sky_up_vs, sky_normal_blend));
	if (use_embedded_rgba < 0.5) {
		NORMAL_MAP = texture(tex_nor, UV).rgb;
		NORMAL_MAP_DEPTH = 0.72;
	}

	float tree_var = smoothstep(0.30, 0.92, sin(v_wpos.x * 0.08 + v_wpos.z * 0.07) * 0.5 + 0.5);
	vec3 tint = mix(color_tint, color_tint * warm_var_tint, clamp(tree_var * 0.58 + (COLOR.r - 0.5) * 0.26, 0.0, 1.0));
	vec3 final_col = sample_c.rgb * tint * mix(0.84, 1.06, COLOR.b);

	ALBEDO = final_col;
	AO = mix(0.64, 1.0, COLOR.b);
	AO_LIGHT_AFFECT = 0.35;
	ROUGHNESS = roughness_val;
	SPECULAR = 0.22;
	BACKLIGHT = final_col * backlight_strength;
}
"""
	_pbr_foliage_shader = sh
	return sh


static func _get_canopy_material(species: int) -> Material:
	if _canopy_mats.has(species):
		return _canopy_mats[species]

	var sm := ShaderMaterial.new()
	sm.shader = _get_pbr_foliage_shader()

	match species:
		TreeSpecies.SPRUCE:
			_assign_foliage_textures(sm, "fir_twig")
			sm.set_shader_parameter("use_embedded_rgba", 0.0)
			sm.set_shader_parameter("color_tint", Color(0.82, 0.92, 0.78))
			sm.set_shader_parameter("warm_var_tint", Color(1.06, 1.08, 0.88))
			sm.set_shader_parameter("alpha_scissor", 0.38)
			sm.set_shader_parameter("roughness_val", 0.64)
			sm.set_shader_parameter("backlight_strength", 0.42)
			sm.set_shader_parameter("sky_normal_blend", 0.34)
			sm.set_shader_parameter("wind_strength", 0.72)

		TreeSpecies.PINE:
			sm.set_shader_parameter("tex_alb", _get_pine_bough_texture())
			sm.set_shader_parameter("tex_nor", _get_flat_normal_texture())
			sm.set_shader_parameter("use_embedded_rgba", 1.0)
			sm.set_shader_parameter("color_tint", Color(0.94, 1.02, 0.86))
			sm.set_shader_parameter("warm_var_tint", Color(1.10, 1.06, 0.86))
			sm.set_shader_parameter("alpha_scissor", 0.36)
			sm.set_shader_parameter("roughness_val", 0.60)
			sm.set_shader_parameter("backlight_strength", 0.48)
			sm.set_shader_parameter("sky_normal_blend", 0.40)
			sm.set_shader_parameter("wind_strength", 0.85)

		TreeSpecies.BIRCH:
			sm.set_shader_parameter("tex_alb", _get_birch_spray_texture())
			sm.set_shader_parameter("tex_nor", _get_flat_normal_texture())
			sm.set_shader_parameter("use_embedded_rgba", 1.0)
			sm.set_shader_parameter("color_tint", Color(0.95, 1.04, 0.78))
			sm.set_shader_parameter("warm_var_tint", Color(1.24, 1.12, 0.68))
			sm.set_shader_parameter("alpha_scissor", 0.40)
			sm.set_shader_parameter("roughness_val", 0.54)
			sm.set_shader_parameter("backlight_strength", 0.78)
			sm.set_shader_parameter("sky_normal_blend", 0.46)
			sm.set_shader_parameter("wind_strength", 1.15)

		TreeSpecies.OAK:
			sm.set_shader_parameter("tex_alb", _get_oak_spray_texture())
			sm.set_shader_parameter("tex_nor", _get_flat_normal_texture())
			sm.set_shader_parameter("use_embedded_rgba", 1.0)
			sm.set_shader_parameter("color_tint", Color(0.72, 0.86, 0.62))
			sm.set_shader_parameter("warm_var_tint", Color(1.16, 1.06, 0.76))
			sm.set_shader_parameter("alpha_scissor", 0.40)
			sm.set_shader_parameter("roughness_val", 0.58)
			sm.set_shader_parameter("backlight_strength", 0.56)
			sm.set_shader_parameter("sky_normal_blend", 0.42)
			sm.set_shader_parameter("wind_strength", 0.82)

		TreeSpecies.MAPLE:
			sm.set_shader_parameter("tex_alb", _get_maple_spray_texture())
			sm.set_shader_parameter("tex_nor", _get_flat_normal_texture())
			sm.set_shader_parameter("use_embedded_rgba", 1.0)
			sm.set_shader_parameter("color_tint", Color(0.92, 0.98, 0.76))
			sm.set_shader_parameter("warm_var_tint", Color(1.32, 1.02, 0.64))
			sm.set_shader_parameter("alpha_scissor", 0.40)
			sm.set_shader_parameter("roughness_val", 0.52)
			sm.set_shader_parameter("backlight_strength", 0.74)
			sm.set_shader_parameter("sky_normal_blend", 0.44)
			sm.set_shader_parameter("wind_strength", 0.96)

		TreeSpecies.ASPEN:
			sm.set_shader_parameter("tex_alb", _get_aspen_spray_texture())
			sm.set_shader_parameter("tex_nor", _get_flat_normal_texture())
			sm.set_shader_parameter("use_embedded_rgba", 1.0)
			sm.set_shader_parameter("color_tint", Color(0.86, 0.98, 0.82))
			sm.set_shader_parameter("warm_var_tint", Color(1.20, 1.14, 0.72))
			sm.set_shader_parameter("alpha_scissor", 0.40)
			sm.set_shader_parameter("roughness_val", 0.48)
			sm.set_shader_parameter("backlight_strength", 0.80)
			sm.set_shader_parameter("sky_normal_blend", 0.45)
			sm.set_shader_parameter("wind_strength", 1.22)
			sm.set_shader_parameter("flutter_speed", 9.4)
			sm.set_shader_parameter("flutter_amp", 0.052)

		_: # ORCHARD
			sm.set_shader_parameter("tex_alb", _get_orchard_spray_texture())
			sm.set_shader_parameter("tex_nor", _get_flat_normal_texture())
			sm.set_shader_parameter("use_embedded_rgba", 1.0)
			sm.set_shader_parameter("color_tint", Color(0.80, 0.94, 0.74))
			sm.set_shader_parameter("warm_var_tint", Color(1.10, 1.06, 0.82))
			sm.set_shader_parameter("alpha_scissor", 0.40)
			sm.set_shader_parameter("roughness_val", 0.56)
			sm.set_shader_parameter("backlight_strength", 0.66)
			sm.set_shader_parameter("sky_normal_blend", 0.44)
			sm.set_shader_parameter("wind_strength", 0.92)

	_canopy_mats[species] = sm
	return sm


static func _assign_foliage_textures(sm: ShaderMaterial, tex_folder: String) -> void:
	var base := "res://assets/downloaded/textures/%s" % tex_folder
	var alb := AssetCatalog._load_texture_safe("%s/diff.jpg" % base)
	var alp := AssetCatalog._load_texture_safe("%s/alpha.jpg" % base)
	var nor := AssetCatalog._load_texture_safe("%s/nor_gl.jpg" % base)
	if alb != null:
		sm.set_shader_parameter("tex_alb", alb)
	if alp != null:
		sm.set_shader_parameter("tex_alpha", alp)
	if nor != null:
		sm.set_shader_parameter("tex_nor", nor)


# ============================================================================
# 2. 6 ВИДОВ ПЫШНЫХ КУСТАРНИКОВ + КРАПИВА, ЧИСТОТЕЛ 4.3K, ПАПОРОТНИК И ОДУВАНЧИКИ 23.5K
# ============================================================================

static func _build_photoscanned_undergrowth(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var shrub1 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_01/model.gltf")
	var shrub2 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_02/model.gltf")
	var shrub3 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_03/model.gltf")
	var shrub4 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_04/model.gltf")
	var periwinkle := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/periwinkle_plant/model.gltf")
	var weed_bush := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/weed_plant_02/model.gltf")
	var sorrel := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_sorrel_01/model.gltf")

	var nettles := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/nettle_plant/model.gltf")
	var celandines := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/celandine_01/model.gltf")
	var dandelions := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/dandelion_01/model.gltf")
	var ferns := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/fern_02/model.gltf")
	var grass_m1 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/grass_medium_01/model.gltf")
	var grass_m2 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/grass_medium_02/model.gltf")
	var grass_bermuda := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/grass_bermuda_01/model.gltf")

	# А) Лесные и луговые кустарники (shrub_01 156k, shrub_02, shrub_03, shrub_04, бурьян weed_plant_02)
	var shrub_buckets: Array = [[], [], [], [], []]
	for _i in range(1180):
		var sx := rng.randf_range(-85.0, 85.0)
		var sz := rng.randf_range(-85.0, 85.0)
		if TerrainBuilder.get_road_distance(sx, sz) < 4.1 or TerrainBuilder.get_footpath_distance(sx, sz) < 1.85:
			continue
		if TerrainBuilder.is_inside_building_footprint(sx, sz, 1.4):
			continue
		if Vector2(sx, sz).distance_to(Vector2(14.0, -4.0)) < 5.4:
			continue
		var sy := TerrainBuilder.get_height(sx, sz)
		var ff := TerrainBuilder.get_forest_factor(sx, sz)
		var roll := rng.randf()
		var b_idx := 0
		var sc := 1.0
		if roll < 0.22:
			b_idx = 0 # shrub_01 (156 012 треуг., 9-ствольный цветущий куст!)
			sc = rng.randf_range(1.30, 1.95)
		elif roll < 0.44:
			b_idx = 1 # shrub_02
			sc = rng.randf_range(0.88, 1.38)
		elif roll < 0.66:
			b_idx = 2 # shrub_03
			sc = rng.randf_range(1.15, 1.75)
		elif roll < 0.84:
			b_idx = 3 # shrub_04
			sc = rng.randf_range(1.65, 2.45)
		else:
			b_idx = 4 # weed_plant_02 (раскидистый бурьян)
			sc = rng.randf_range(2.60, 4.10) * (1.15 if ff < 0.35 else 0.88)

		(shrub_buckets[b_idx] as Array).append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(sx, sy - 0.04, sz))
		)

	if not shrub1.is_empty():
		_add_multimesh_batch(parent, "Shrubs_FloweringHero", shrub1[0], shrub_buckets[0], 110.0, true, 34.0)
	if not shrub2.is_empty():
		_add_multimesh_batch(parent, "Shrubs_Large", shrub2[0], shrub_buckets[1], 115.0, true, 36.0)
	if not shrub3.is_empty():
		_add_multimesh_batch(parent, "Shrubs_Mid", shrub3[0], shrub_buckets[2], 95.0, true, 36.0)
	if not shrub4.is_empty():
		_add_multimesh_batch(parent, "Shrubs_Low", shrub4[0], shrub_buckets[3], 90.0, false, 36.0)
	if not weed_bush.is_empty():
		_add_multimesh_batch(parent, "Shrubs_WildBurdock", weed_bush[0], shrub_buckets[4], 82.0, false, 34.0)

	# Б) Деревенские палисадники, заборы и обочины: цветущий periwinkle_plant, крапива, крупный чистотел и одуванчики 23.5k
	var periwinkle_xf: Array[Transform3D] = []
	var nettle_xf: Array[Transform3D] = []
	var celandine_xf: Array[Transform3D] = []
	var dandelion_hero_xf: Array[Transform3D] = []
	var dandelion_mid_xf: Array[Transform3D] = []

	for plot in TerrainBuilder.HOUSE_PLOTS:
		var c: Vector2 = plot["pos"]
		# Цветущие палисадниковые кусты у крылец и палисадников домов
		for _p in range(22):
			var p_off := Vector2(rng.randf_range(-10.2, 10.2), rng.randf_range(-10.2, 10.2))
			if absf(p_off.x) < 5.4 and absf(p_off.y) < 4.8:
				continue
			var pp := c + p_off
			if TerrainBuilder.get_road_distance(pp.x, pp.y) < 3.5 or TerrainBuilder.get_footpath_distance(pp.x, pp.y) < 1.25:
				continue
			if TerrainBuilder.is_inside_building_footprint(pp.x, pp.y, 0.65):
				continue
			var py := TerrainBuilder.get_height(pp.x, pp.y) - 0.03
			var psc := rng.randf_range(0.88, 1.38)
			periwinkle_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(psc, psc, psc)), Vector3(pp.x, py, pp.y)))

		for _k in range(145):
			var offset := Vector2(rng.randf_range(-11.8, 11.8), rng.randf_range(-11.8, 11.8))
			if absf(offset.x) < 6.0 and absf(offset.y) < 5.3:
				continue
			var np := c + offset
			if TerrainBuilder.get_road_distance(np.x, np.y) < 3.5 or TerrainBuilder.get_footpath_distance(np.x, np.y) < 1.35:
				continue
			if TerrainBuilder.is_inside_building_footprint(np.x, np.y, 0.5):
				continue
			var ny := TerrainBuilder.get_height(np.x, np.y)
			var r_yard := rng.randf()
			if r_yard < 0.46:
				var nsc := rng.randf_range(3.6, 5.6)
				nettle_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(nsc, nsc, nsc)), Vector3(np.x, ny, np.y)))
			elif r_yard < 0.78:
				var csc := rng.randf_range(2.2, 3.5)
				celandine_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(csc, csc, csc)), Vector3(np.x, ny, np.y)))
			else:
				var dsc := rng.randf_range(1.90, 2.85)
				dandelion_hero_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(dsc, dsc, dsc)), Vector3(np.x, ny, np.y)))

	# Обочины просёлочной грунтовки и солнечные лужайки: крапива + яркие жёлтые одуванчики (LOD0 23.5k!)
	for i in range(540):
		var dz := rng.randf_range(-84.0, 84.0)
		var side := -1.0 if (i % 2 == 0) else 1.0
		var dx := TerrainBuilder.get_road_center_x(dz) + side * rng.randf_range(3.6, 6.8)
		if TerrainBuilder.get_footpath_distance(dx, dz) < 1.25 or TerrainBuilder.is_inside_building_footprint(dx, dz, 0.6):
			continue
		var dy := TerrainBuilder.get_height(dx, dz)
		if i % 3 == 0:
			var dsc2 := rng.randf_range(1.85, 2.80)
			dandelion_hero_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(dsc2, dsc2, dsc2)), Vector3(dx, dy, dz)))
		else:
			var nsc2 := rng.randf_range(3.4, 5.2)
			nettle_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(nsc2, nsc2, nsc2)), Vector3(dx, dy, dz)))

	for _dm in range(750):
		var mx := rng.randf_range(-82.0, 82.0)
		var mz := rng.randf_range(-82.0, 82.0)
		if TerrainBuilder.get_forest_factor(mx, mz) > 0.55:
			continue
		if TerrainBuilder.get_road_distance(mx, mz) < 3.4 or TerrainBuilder.get_footpath_distance(mx, mz) < 1.1:
			continue
		if TerrainBuilder.is_inside_building_footprint(mx, mz, 0.6):
			continue
		var my := TerrainBuilder.get_height(mx, mz)
		var dsc3 := rng.randf_range(2.1, 3.2)
		dandelion_mid_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(dsc3, dsc3, dsc3)), Vector3(mx, my, mz)))

	if not periwinkle.is_empty() and not periwinkle_xf.is_empty():
		_add_multimesh_batch(parent, "Shrubs_GardenPeriwinkle", periwinkle[0], periwinkle_xf, 88.0, true, 32.0)
	if not nettles.is_empty() and not nettle_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedNettles", nettles[0], nettle_xf, 70.0, false, 34.0)
	if not celandines.is_empty() and not celandine_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedCelandine", celandines[0], celandine_xf, 68.0, false, 34.0)
	if not dandelions.is_empty():
		if not dandelion_hero_xf.is_empty():
			_add_multimesh_batch(parent, "PhotoscannedDandelionsHero", dandelions[0], dandelion_hero_xf, 64.0, false, 28.0)
		if dandelions.size() > 2 and not dandelion_mid_xf.is_empty():
			_add_multimesh_batch(parent, "PhotoscannedDandelionsMeadow", dandelions[2], dandelion_mid_xf, 68.0, false, 32.0)

	# В) Лесные папоротники и цветущие куртинки кислицы/клевера (shrub_sorrel_01) под пологом леса
	var fern_xf: Array[Transform3D] = []
	var sorrel_xf: Array[Transform3D] = []
	for _i in range(2400):
		var fx := rng.randf_range(-84.0, 86.0)
		var fz := rng.randf_range(-85.0, 85.0)
		var ff2 := TerrainBuilder.get_forest_factor(fx, fz)
		if ff2 < 0.24:
			continue
		if TerrainBuilder.get_road_distance(fx, fz) < 4.0 or TerrainBuilder.get_footpath_distance(fx, fz) < 1.35:
			continue
		if TerrainBuilder.is_inside_building_footprint(fx, fz, 1.0):
			continue
		var fy := TerrainBuilder.get_height(fx, fz)
		if rng.randf() < 0.68:
			var fsc := rng.randf_range(1.50, 2.45)
			fern_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(fsc, fsc, fsc)), Vector3(fx, fy, fz)))
		else:
			var ssc := rng.randf_range(1.75, 2.75)
			sorrel_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ssc, ssc, ssc)), Vector3(fx, fy - 0.01, fz)))

	if not ferns.is_empty() and not fern_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedFerns", ferns[0], fern_xf, 76.0, false, 34.0)
	if not sorrel.is_empty() and not sorrel_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedWoodSorrel", sorrel[0], sorrel_xf, 64.0, false, 32.0)

	# Г) 3 фотосканированных вида травы: крупные кочки овсяницы (grass_medium_01_large 4.6k!),
	#    луговые куртины (grass_medium_02) и густая дернина с метёлками (grass_bermuda_01)
	var gm1_xf: Array[Transform3D] = []
	var gm2_xf: Array[Transform3D] = []
	var bermuda_xf: Array[Transform3D] = []

	for _i in range(5200):
		var gx := rng.randf_range(-84.0, 84.0)
		var gz := rng.randf_range(-84.0, 84.0)
		var rd := TerrainBuilder.get_road_distance(gx, gz)
		var pd := TerrainBuilder.get_footpath_distance(gx, gz)
		if rd < 2.85 or pd < 0.92 or TerrainBuilder.is_inside_building_footprint(gx, gz, 0.5):
			continue
		var gy := TerrainBuilder.get_height(gx, gz)
		if pd < 2.6 or rd < 5.2 or Vector2(gx, gz).distance_to(Vector2(14.0, -4.0)) < 9.5:
			# У тропинок, обочин и вокруг костра — плотная дернина с тонкими звёздочками-метёлками
			var bsc := rng.randf_range(0.90, 1.48)
			bermuda_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bsc, bsc, bsc)), Vector3(gx, gy - 0.01, gz)))
		elif rng.randf() < 0.45:
			# Пышные тяжёлые кочки дикой овсяницы (4 626 треугольников на кочку!)
			var g1sc := rng.randf_range(3.1, 4.9)
			gm1_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(g1sc, g1sc, g1sc)), Vector3(gx, gy - 0.02, gz)))
		else:
			var g2sc := rng.randf_range(1.9, 3.2)
			gm2_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(g2sc, g2sc, g2sc)), Vector3(gx, gy, gz)))

	if not grass_m1.is_empty() and not gm1_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedFescueClumps", grass_m1[0], gm1_xf, 68.0, false, 30.0)
	if not grass_m2.is_empty() and not gm2_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedGrassClumps", grass_m2[0], gm2_xf, 66.0, false, 32.0)
	if not grass_bermuda.is_empty() and not bermuda_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedTurfSeedheads", grass_bermuda[0], bermuda_xf, 60.0, false, 30.0)


# ============================================================================
# 3. АВГУСТОВСКИЙ ЛУГ — 56 000+ ПУЧКОВ 3D-ТРАВЫ + 4 200 СНОПОВ ВЫСОКИХ КОЛОСКОВ (Foliage003)
# ============================================================================

static func _build_gpu_meadow_grass(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var tuft_mesh := _create_curved_grass_tuft_mesh()
	var stalks_mesh := _create_meadow_seed_stalks_mesh()
	var grass_xforms: Array[Transform3D] = []
	var stalk_xforms: Array[Transform3D] = []

	for i in range(68000):
		var gx := rng.randf_range(-86.5, 86.5)
		var gz := rng.randf_range(-86.5, 86.5)

		var weights := TerrainBuilder.get_surface_weights(gx, gz)
		if weights.r > 0.35 or weights.g > 0.42:
			continue
		if TerrainBuilder.is_inside_building_footprint(gx, gz, 0.35):
			continue
		if weights.b > 0.72 and rng.randf() < 0.62:
			continue

		var gy := TerrainBuilder.get_height(gx, gz)
		var wild_patch := sin(gx * 0.13 + 1.1) * cos(gz * 0.15 - 0.6)
		var h_scale := rng.randf_range(0.85, 1.55) if (wild_patch > 0.25) else rng.randf_range(0.48, 0.92)
		var w_scale := rng.randf_range(0.75, 1.20)

		grass_xforms.append(Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w_scale, h_scale, w_scale)),
			Vector3(gx, gy - 0.02, gz)
		))

		# Над открытыми солнечными полянами колышутся высокие золотисто-зелёные колоски мятлика!
		if i % 13 == 0 and weights.b < 0.55:
			var st_sc := rng.randf_range(0.88, 1.36) * (1.18 if wild_patch > 0.20 else 0.86)
			stalk_xforms.append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(st_sc, st_sc, st_sc)),
				Vector3(gx, gy - 0.03, gz)
			))

	_add_multimesh_batch(parent, "MeadowGrass", tuft_mesh, grass_xforms, 68.0, false, 30.0)
	_add_multimesh_batch(parent, "MeadowSeedStalks", stalks_mesh, stalk_xforms, 66.0, false, 30.0)


static func _create_meadow_seed_stalks_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260825
	var stalk_cards := 9
	var dome_orig := Vector3(0.0, -0.6, 0.0)

	for c in range(stalk_cards):
		var yaw := float(c) * (TAU / float(stalk_cards)) + rng.randf_range(-0.22, 0.22)
		var rad := rng.randf_range(0.04, 0.24)
		var orig := Vector3(cos(yaw) * rad, 0.0, sin(yaw) * rad)
		# Ось +Z карточки направляем вверх с лёгким природным наклоном наружу (pitch ~ -74°..-82°)
		var pitch := deg_to_rad(rng.randf_range(-82.0, -68.0))
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		var h := rng.randf_range(0.86, 1.24)
		var w := h * 0.42
		var poly: Array = MEADOW_STALK_POLYS[c % 2]
		_append_curved_bough_card(st, orig, basis, w, h, -0.08 * h, 0.42, 0.96, poly, dome_orig, rng.randf(), 0.96)

	st.generate_tangents()
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, _get_meadow_stalks_material())
	return mesh


static func _get_meadow_stalks_material() -> Material:
	if _meadow_stalks_mat != null:
		return _meadow_stalks_mat
	var sm := ShaderMaterial.new()
	sm.shader = _get_pbr_foliage_shader()
	_assign_foliage_textures(sm, "meadow_stalks")
	sm.set_shader_parameter("use_embedded_rgba", 0.0)
	sm.set_shader_parameter("color_tint", Color(0.72, 0.68, 0.40))
	sm.set_shader_parameter("warm_var_tint", Color(0.90, 0.78, 0.44))
	sm.set_shader_parameter("alpha_scissor", 0.32)
	sm.set_shader_parameter("roughness_val", 0.62)
	sm.set_shader_parameter("backlight_strength", 0.46)
	sm.set_shader_parameter("sky_normal_blend", 0.44)
	sm.set_shader_parameter("wind_strength", 1.35)
	_meadow_stalks_mat = sm
	return sm


static func _create_curved_grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng := RandomNumberGenerator.new()
	rng.seed = 8082026
	var blade_count := 8

	for b in range(blade_count):
		var yaw := float(b) * (TAU / float(blade_count)) + rng.randf_range(-0.25, 0.25)
		var radial := rng.randf_range(0.03, 0.22)
		var base := Vector3(cos(yaw) * radial, 0.0, sin(yaw) * radial)
		var dir := Vector3(cos(yaw + rng.randf_range(-0.4, 0.4)), 0.0, sin(yaw + rng.randf_range(-0.4, 0.4)))
		var side := Vector3(-dir.z, 0.0, dir.x)

		var h := rng.randf_range(0.62, 0.94)
		var droop := rng.randf_range(0.16, 0.34)
		var w0 := 0.027
		var w1 := 0.019
		var w2 := 0.009

		var p0 := base
		var p1 := base + Vector3(0.0, h * 0.42, 0.0) + dir * (droop * 0.25)
		var p2 := base + Vector3(0.0, h * 0.76, 0.0) + dir * (droop * 0.65)
		var p3 := base + Vector3(0.0, h, 0.0) + dir * droop

		var nrm := (Vector3.UP * 0.82 - dir * 0.18).normalized()
		var seed_r := rng.randf()

		var c0 := Color(seed_r, 0.0, 0.0, 1.0)
		var c1 := Color(seed_r, 0.42, 0.0, 1.0)
		var c2 := Color(seed_r, 0.76, 0.0, 1.0)
		var c3 := Color(seed_r, 1.0, 0.0, 1.0)

		st.set_normal(nrm)
		st.set_color(c0); st.add_vertex(p0 - side * w0)
		st.set_color(c1); st.add_vertex(p1 - side * w1)
		st.set_color(c1); st.add_vertex(p1 + side * w1)

		st.set_color(c0); st.add_vertex(p0 - side * w0)
		st.set_color(c1); st.add_vertex(p1 + side * w1)
		st.set_color(c0); st.add_vertex(p0 + side * w0)

		st.set_color(c1); st.add_vertex(p1 - side * w1)
		st.set_color(c2); st.add_vertex(p2 - side * w2)
		st.set_color(c2); st.add_vertex(p2 + side * w2)

		st.set_color(c1); st.add_vertex(p1 - side * w1)
		st.set_color(c2); st.add_vertex(p2 + side * w2)
		st.set_color(c1); st.add_vertex(p1 + side * w1)

		st.set_color(c2); st.add_vertex(p2 - side * w2)
		st.set_color(c3); st.add_vertex(p3)
		st.set_color(c2); st.add_vertex(p2 + side * w2)

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, _get_meadow_grass_material())
	return mesh


static func _get_meadow_grass_material() -> Material:
	if _meadow_grass_mat != null:
		return _meadow_grass_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying float v_height;
varying float v_patch;
varying float v_seed;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_height = COLOR.g;
	v_seed = COLOR.r;
	v_patch = sin(wp.x * 0.075 + 0.5) * cos(wp.z * 0.082 - 0.3) * 0.5 + 0.5;

	float wave = sin(TIME * 2.05 + wp.x * 0.22 + wp.z * 0.16) + 0.45 * cos(TIME * 3.4 - wp.x * 0.35 + v_seed * 6.28);
	float bend = v_height * v_height;
	VERTEX.x += wave * 0.15 * bend;
	VERTEX.z += wave * 0.09 * bend;
	VERTEX.y -= abs(wave) * 0.03 * bend;
}

void fragment() {
	vec3 root_col = vec3(0.07, 0.14, 0.04);
	vec3 mid_green = mix(vec3(0.16, 0.31, 0.08), vec3(0.26, 0.35, 0.10), v_patch);
	vec3 tip_gold = mix(vec3(0.34, 0.44, 0.13), vec3(0.62, 0.53, 0.20), smoothstep(0.35, 0.85, v_patch + (v_seed - 0.5) * 0.35));

	vec3 col = mix(root_col, mid_green, smoothstep(0.0, 0.45, v_height));
	col = mix(col, tip_gold, smoothstep(0.48, 1.0, v_height));

	ALBEDO = col;
	ROUGHNESS = 0.62;
	SPECULAR = 0.22;
	AO = mix(0.35, 1.0, v_height);
	BACKLIGHT = col * (0.45 + 0.55 * v_height);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_meadow_grass_mat = sm
	return sm


# ============================================================================
# ПРОСТРАНСТВЕННОЕ РАЗБИЕНИЕ MULTIMESH ПО ЧАНКАМ (FRUSTUM & DISTANCE CULLING)
# ============================================================================

static func _add_multimesh_batch(
	parent: Node3D,
	batch_name: String,
	mesh: Mesh,
	xforms: Array,
	vis_end: float,
	cast_shadows: bool,
	cell_size: float = 36.0
) -> void:
	if xforms.is_empty() or mesh == null:
		return

	if xforms.size() <= 20 or cell_size <= 0.0:
		_spawn_single_multimesh_node(parent, batch_name, mesh, xforms, Vector3.ZERO, vis_end, cast_shadows)
		return

	var buckets: Dictionary = {}
	for i in range(xforms.size()):
		var xf: Transform3D = xforms[i]
		var cx := int(floor((xf.origin.x + 120.0) / cell_size))
		var cz := int(floor((xf.origin.z + 120.0) / cell_size))
		var key := Vector2i(cx, cz)
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(xf)

	var group := Node3D.new()
	group.name = batch_name
	parent.add_child(group)

	for key in buckets.keys():
		var cell_list: Array = buckets[key]
		if cell_list.is_empty():
			continue
		var sum_pos := Vector3.ZERO
		for cxf in cell_list:
			sum_pos += (cxf as Transform3D).origin
		var center := sum_pos / float(cell_list.size())
		var cname := "%s_C%d_%d" % [batch_name, key.x, key.y]
		_spawn_single_multimesh_node(group, cname, mesh, cell_list, center, vis_end, cast_shadows)


static func _spawn_single_multimesh_node(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	xforms: Array,
	local_origin: Vector3,
	vis_end: float,
	cast_shadows: bool
) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		var xf: Transform3D = xforms[i]
		mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - local_origin))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.position = local_origin
	mmi.multimesh = mm
	if vis_end < 220.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = 12.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
