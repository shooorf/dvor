class_name RealisticFoliage
extends RefCounted
## Реалистичная растительность Восточной Европы (Август):
## 1) Ботанические 3D-деревья 4 пород (берёза повислая, корабельная сосна, ель, садовая яблоня/липа)
##    с плавными изогнутыми стволами/ветвями (4K PBR кора) и детализированной листвой/хвоей с ветром и просветом солнца.
## 2) Тысячи реальных 3D-фотосканов Poly Haven (кусты, крапива у заборов, чистотел, папоротник, пни, валежник) через MultiMesh.
## 3) 55 000+ пучков густой 3D-травы до пояса на GPU (MultiMeshInstance3D + шейдер августовского ветра).

enum TreeSpecies {
	BIRCH = 0,
	PINE = 1,
	SPRUCE = 2,
	ORCHARD = 3,
}

static var _birch_bark_mat: Material = null
static var _pine_bark_mat: Material = null
static var _dark_bark_mat: Material = null
static var _broadleaf_canopy_mat: Material = null
static var _birch_canopy_mat: Material = null
static var _conifer_canopy_mat: Material = null
static var _meadow_grass_mat: Material = null


static func populate_world_foliage(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "RealisticFoliageSystem"
	parent.add_child(root)

	_build_trees_and_trunks(root, rng)

	if DisplayServer.get_name() != "headless":
		_build_photoscanned_undergrowth(root, rng)
		_build_gpu_meadow_grass(root, rng)


# ============================================================================
# 1. БОТАНИЧЕСКИЕ ДЕРЕВЬЯ (БЕРЁЗЫ, СОСНЫ, ЕЛИ, ЯБЛОНИ/ЛИПЫ) + КОЛЛАЙДЕРЫ СТВОЛОВ
# ============================================================================

static func _build_trees_and_trunks(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var trunk_bodies := StaticBody3D.new()
	trunk_bodies.name = "TreeTrunkColliders"
	trunk_bodies.collision_layer = 1
	trunk_bodies.collision_mask = 0
	parent.add_child(trunk_bodies)

	# Генерируем по 2 органических варианта меша на каждую из 4 пород (ствол+ветви в surface 0, листва/хвоя в surface 1)
	var species_variants: Dictionary = {}
	if DisplayServer.get_name() != "headless":
		for sp in [TreeSpecies.BIRCH, TreeSpecies.PINE, TreeSpecies.SPRUCE, TreeSpecies.ORCHARD]:
			var v0 := _generate_tree_mesh(sp, 100 + sp * 17)
			var v1 := _generate_tree_mesh(sp, 200 + sp * 31)
			species_variants[sp] = [v0, v1]

	# Списки трансформаций для аппаратного MultiMesh рендеринга по вариантам
	var transforms_by_key: Dictionary = {}
	for sp in [TreeSpecies.BIRCH, TreeSpecies.PINE, TreeSpecies.SPRUCE, TreeSpecies.ORCHARD]:
		transforms_by_key["%d_0" % sp] = []
		transforms_by_key["%d_1" % sp] = []

	var placed_trees: Array[Vector2] = []

	# А) Плодовые деревья (яблони/липы) и берёзы во дворах и вдоль деревенской улицы
	for plot in TerrainBuilder.HOUSE_PLOTS:
		var c: Vector2 = plot["pos"]
		var style := String(plot["style"])
		if style == "forester_hut":
			continue
		for k in range(3):
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(6.8, 11.2)
			var tp := c + Vector2(cos(ang), sin(ang)) * dist
			if not _can_place_tree_at(tp.x, tp.y, placed_trees, 3.6):
				continue
			var sp: int = TreeSpecies.ORCHARD if (k < 2) else TreeSpecies.BIRCH
			var sc := rng.randf_range(0.85, 1.18)
			_register_tree_instance(tp, sp, sc, rng, placed_trees, transforms_by_key, trunk_bodies)

	# Б) Живописные старые берёзы и сосны вдоль просёлочной грунтовки и у поляны костра
	for i in range(42):
		var tz := -78.0 + float(i) * 3.8 + rng.randf_range(-1.2, 1.2)
		var side := -1.0 if (i % 2 == 0) else 1.0
		var tx := TerrainBuilder.get_road_center_x(tz) + side * rng.randf_range(6.2, 11.5)
		if not _can_place_tree_at(tx, tz, placed_trees, 4.2):
			continue
		var sp2: int = TreeSpecies.BIRCH if (rng.randf() < 0.68) else TreeSpecies.PINE
		var sc2 := rng.randf_range(0.95, 1.32)
		_register_tree_instance(Vector2(tx, tz), sp2, sc2, rng, placed_trees, transforms_by_key, trunk_bodies)

	# В) Густой смешанный восточный и северный лес + лесные опушки (~460 деревьев)
	for _attempt in range(1350):
		if placed_trees.size() >= 540:
			break
		var tx := rng.randf_range(-85.0, 85.0)
		var tz := rng.randf_range(-85.0, 85.0)
		var ff := TerrainBuilder.get_forest_factor(tx, tz)
		# В поле/деревне редкие одиночные рощицы, в лесу — плотный массив
		var keep_prob := 0.04 + ff * 0.92
		if rng.randf() > keep_prob:
			continue
		var min_spacing := lerpf(5.4, 3.4, ff)
		if not _can_place_tree_at(tx, tz, placed_trees, min_spacing):
			continue

		var roll := rng.randf()
		var sp3: int = TreeSpecies.PINE
		if ff > 0.55:
			if roll < 0.40:
				sp3 = TreeSpecies.PINE
			elif roll < 0.72:
				sp3 = TreeSpecies.SPRUCE
			else:
				sp3 = TreeSpecies.BIRCH
		else:
			sp3 = TreeSpecies.BIRCH if (roll < 0.65) else TreeSpecies.PINE

		var sc3 := rng.randf_range(0.88, 1.42)
		_register_tree_instance(Vector2(tx, tz), sp3, sc3, rng, placed_trees, transforms_by_key, trunk_bodies)

	# Г) Плотная лесная стена за внешним периметром карты (от ±87 до ±106 м — глубокий непроглядный лес со всех сторон)
	for i in range(180):
		var side_idx := i % 4
		var along := rng.randf_range(-102.0, 102.0)
		var depth := rng.randf_range(88.5, 106.0)
		var bp := Vector2.ZERO
		match side_idx:
			0: bp = Vector2(along, -depth)
			1: bp = Vector2(along, depth)
			2: bp = Vector2(-depth, along)
			_: bp = Vector2(depth, along)
		var sp_b: int = [TreeSpecies.PINE, TreeSpecies.SPRUCE, TreeSpecies.BIRCH][i % 3]
		var sc_b := rng.randf_range(1.05, 1.55)
		var v_idx := i % 2
		var key := "%d_%d" % [sp_b, v_idx]
		var y_b := TerrainBuilder.get_height(bp.x, bp.y) - 0.12
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc_b, sc_b, sc_b)), Vector3(bp.x, y_b, bp.y))
		(transforms_by_key[key] as Array).append(xf)

	# Д) Поваленные лесные стволы и пни с реальными фотосканами Poly Haven + коллайдерами в лесу
	_populate_fallen_logs_and_stumps(parent, trunk_bodies, rng)

	if DisplayServer.get_name() == "headless":
		return

	# Создаём MultiMeshInstance3D для каждого варианта породы дерева (всего 8 батчей на ~700 высокодетализированных деревьев!)
	for sp in [TreeSpecies.BIRCH, TreeSpecies.PINE, TreeSpecies.SPRUCE, TreeSpecies.ORCHARD]:
		for v_idx in range(2):
			var key := "%d_%d" % [sp, v_idx]
			var xforms: Array = transforms_by_key[key]
			if xforms.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = species_variants[sp][v_idx]
			mm.instance_count = xforms.size()
			for idx in range(xforms.size()):
				mm.set_instance_transform(idx, xforms[idx])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Trees_Sp%d_V%d" % [sp, v_idx]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(mmi)


static func _can_place_tree_at(x: float, z: float, existing: Array[Vector2], min_dist: float) -> bool:
	if absf(x) > 85.5 or absf(z) > 85.5:
		return false
	if TerrainBuilder.get_road_distance(x, z) < 5.0:
		return false
	if TerrainBuilder.get_footpath_distance(x, z) < 2.5:
		return false
	if TerrainBuilder.is_inside_building_footprint(x, z, 2.2):
		return false
	# Не ставим деревья прямо в костёр и колодец
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

	# Физический коллайдер ствола (чтобы прятаться за деревьями и отбивать брошенные топоры)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	var base_r := 0.24 if species == TreeSpecies.BIRCH else (0.31 if species == TreeSpecies.PINE else 0.27)
	cyl.radius = base_r * scale_val
	cyl.height = 5.5 * scale_val
	col.shape = cyl
	col.position = Vector3(pos2.x, wy + cyl.height * 0.5, pos2.y)
	trunk_bodies.add_child(col)


static func _populate_fallen_logs_and_stumps(parent: Node3D, trunk_bodies: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var stump_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/tree_stump_01/model.gltf")
	var trunk_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/dead_tree_trunk/model.gltf")
	var branch_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/dry_branches_medium_01/model.gltf")

	var stump_xforms: Array[Transform3D] = []
	var log_xforms: Array[Transform3D] = []
	var branch_xforms: Array[Transform3D] = []

	for i in range(95):
		var lx := rng.randf_range(12.0, 84.0) if (i < 75) else rng.randf_range(-78.0, 12.0)
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
			# Коллайдер поваленного бревна
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(2.9 * sc, 0.36 * sc, 0.36 * sc)
			col.shape = box
			col.position = Vector3(lx, ly + 0.18 * sc, lz)
			col.rotation.y = yaw
			trunk_bodies.add_child(col)
		elif i % 3 == 1:
			var sc2 := rng.randf_range(0.85, 1.35)
			stump_xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc2, sc2, sc2)), Vector3(lx, ly + 0.08, lz)))
		else:
			var sc3 := rng.randf_range(1.1, 1.8)
			branch_xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc3, sc3, sc3)), Vector3(lx, ly + 0.02, lz)))

	if DisplayServer.get_name() == "headless":
		return

	if not stump_meshes.is_empty() and not stump_xforms.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedStumps", stump_meshes[0], stump_xforms, 95.0, true)
	if not trunk_meshes.is_empty() and not log_xforms.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedFallenLogs", trunk_meshes[0], log_xforms, 105.0, true)
	if not branch_meshes.is_empty() and not branch_xforms.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedDryBranches", branch_meshes[0], branch_xforms, 70.0, false)


# ============================================================================
# ПРОЦЕДУРНАЯ ГЕНЕРАЦИЯ ВЫСОКОДЕТАЛИЗИРОВАННЫХ БОТАНИЧЕСКИХ ДЕРЕВЬЕВ
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
			var h := rng.randf_range(10.8, 13.8)
			var lean := Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))
			var spine := _make_curved_spine(Vector3.ZERO, Vector3(lean.x, h, lean.y), 9, 0.28, rng)
			_append_tube_along_spine(st_wood, spine, 0.24, 0.035, 10, true)

			# Ветви берёзы и повислая ажурная крона
			for b in range(18):
				var t := lerpf(0.30, 0.94, float(b) / 17.0)
				var origin := _sample_spine(spine, t)
				var yaw := float(b) * 2.399 + rng.randf_range(-0.25, 0.25)
				var b_len := lerpf(3.4, 1.35, t) * rng.randf_range(0.85, 1.18)
				var end_pt := origin + Vector3(cos(yaw) * b_len, b_len * 0.42 - 0.35, sin(yaw) * b_len)
				var b_spine := _make_curved_spine(origin, end_pt, 5, 0.16, rng)
				b_spine[2].y += 0.32 # Изгиб вверх и затем поникшие кончики ветвей
				_append_tube_along_spine(st_wood, b_spine, lerpf(0.065, 0.028, t), 0.010, 6, false)

				for c_step in [0.55, 0.82, 1.0]:
					var cp := _sample_spine(b_spine, c_step)
					_append_canopy_rosette(st_leaf, cp, rng.randf_range(1.15, 1.55), true, rng)
			_append_canopy_rosette(st_leaf, spine[spine.size() - 1], 1.45, true, rng)

		TreeSpecies.PINE:
			var h2 := rng.randf_range(13.5, 17.2)
			var lean2 := Vector2(rng.randf_range(-0.55, 0.55), rng.randf_range(-0.55, 0.55))
			var spine2 := _make_curved_spine(Vector3.ZERO, Vector3(lean2.x, h2, lean2.y), 10, 0.32, rng)
			_append_tube_along_spine(st_wood, spine2, 0.33, 0.055, 11, true)

			# У корабельной сосны нижняя половина ствола чистая (с сучками), а наверху раскидистая шапка хвои
			for b in range(22):
				var t2 := lerpf(0.54, 0.97, float(b) / 21.0)
				var origin2 := _sample_spine(spine2, t2)
				var yaw2 := float(b) * 2.399 + rng.randf_range(-0.3, 0.3)
				var spread := sin((t2 - 0.48) * PI * 1.45)
				var b_len2 := (1.4 + 2.5 * maxf(spread, 0.25)) * rng.randf_range(0.85, 1.2)
				var end_pt2 := origin2 + Vector3(cos(yaw2) * b_len2, b_len2 * 0.18, sin(yaw2) * b_len2)
				var b_spine2 := _make_curved_spine(origin2, end_pt2, 4, 0.15, rng)
				_append_tube_along_spine(st_wood, b_spine2, lerpf(0.09, 0.035, t2), 0.014, 6, false)

				for c_step2 in [0.62, 0.95]:
					var cp2 := _sample_spine(b_spine2, c_step2)
					_append_canopy_rosette(st_leaf, cp2, rng.randf_range(1.35, 1.85), false, rng)
			_append_canopy_rosette(st_leaf, spine2[spine2.size() - 1] + Vector3(0.0, 0.25, 0.0), 1.85, false, rng)

		TreeSpecies.SPRUCE:
			var h3 := rng.randf_range(11.5, 15.2)
			var spine3 := _make_curved_spine(Vector3.ZERO, Vector3(rng.randf_range(-0.2, 0.2), h3, rng.randf_range(-0.2, 0.2)), 9, 0.12, rng)
			_append_tube_along_spine(st_wood, spine3, 0.28, 0.03, 10, true)

			# Густые ярусы лап ели почти от самой земли (отличное укрытие в лесу!)
			for tier in range(11):
				var t3 := lerpf(0.11, 0.95, float(tier) / 10.0)
				var origin3 := _sample_spine(spine3, t3)
				var branches_in_tier := 5 if t3 < 0.7 else 4
				var b_len3 := lerpf(3.35, 0.75, pow(t3, 0.88))
				for k in range(branches_in_tier):
					var yaw3 := float(tier) * 0.75 + float(k) * (TAU / float(branches_in_tier)) + rng.randf_range(-0.2, 0.2)
					var end_pt3 := origin3 + Vector3(cos(yaw3) * b_len3, -0.35 * (1.0 - t3) + 0.12, sin(yaw3) * b_len3)
					var b_spine3 := _make_curved_spine(origin3, end_pt3, 3, 0.06, rng)
					_append_tube_along_spine(st_wood, b_spine3, 0.055 * (1.1 - t3 * 0.6), 0.012, 5, false)
					_append_canopy_rosette(st_leaf, _sample_spine(b_spine3, 0.62), b_len3 * 0.56 + 0.55, false, rng)
					_append_canopy_rosette(st_leaf, end_pt3, b_len3 * 0.48 + 0.48, false, rng)
			_append_canopy_rosette(st_leaf, spine3[spine3.size() - 1], 1.05, false, rng)

		_: # ORCHARD (раскидистая садовая яблоня / липа у деревенских домов)
			var h4 := rng.randf_range(5.8, 7.6)
			var fork_h := h4 * 0.36
			var trunk_spine := _make_curved_spine(Vector3.ZERO, Vector3(0.08, fork_h, -0.06), 5, 0.14, rng)
			_append_tube_along_spine(st_wood, trunk_spine, 0.24, 0.15, 9, true)
			var fork_pt := trunk_spine[trunk_spine.size() - 1]

			for limb in range(6):
				var yaw4 := float(limb) * (TAU / 6.0) + rng.randf_range(-0.25, 0.25)
				var rad4 := rng.randf_range(2.3, 3.3)
				var limb_end := fork_pt + Vector3(cos(yaw4) * rad4, h4 - fork_h + rng.randf_range(-0.6, 0.6), sin(yaw4) * rad4)
				var l_spine := _make_curved_spine(fork_pt, limb_end, 5, 0.22, rng)
				_append_tube_along_spine(st_wood, l_spine, 0.11, 0.022, 6, false)
				for c_step4 in [0.50, 0.78, 1.0]:
					_append_canopy_rosette(st_leaf, _sample_spine(l_spine, c_step4), rng.randf_range(1.35, 1.75), false, rng)

	st_wood.generate_normals()
	st_leaf.generate_normals()

	var mesh := ArrayMesh.new()
	st_wood.commit(mesh)
	st_leaf.commit(mesh)

	match species:
		TreeSpecies.BIRCH:
			mesh.surface_set_material(0, _get_birch_bark_material())
			mesh.surface_set_material(1, _get_canopy_material(0))
		TreeSpecies.PINE:
			mesh.surface_set_material(0, _get_pine_bark_material())
			mesh.surface_set_material(1, _get_canopy_material(1))
		TreeSpecies.SPRUCE:
			mesh.surface_set_material(0, _get_dark_bark_material())
			mesh.surface_set_material(1, _get_canopy_material(1))
		_:
			mesh.surface_set_material(0, _get_dark_bark_material())
			mesh.surface_set_material(1, _get_canopy_material(2))

	return mesh


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

		var ref := Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.92 else Vector3.UP
		var right := tangent.cross(ref).normalized()
		var forward := right.cross(tangent).normalized()

		var rad := lerpf(r_base, r_tip, pow(t, 0.82))
		if root_flare and t < 0.14:
			rad *= 1.0 + 0.42 * pow(1.0 - t / 0.14, 2.0)

		var ring_pts: Array[Vector3] = []
		for s in range(radial_segs + 1):
			var ang := (float(s) / float(radial_segs)) * TAU
			var lobe := 1.0 + (0.12 * sin(ang * 5.0) * (1.0 - t * 6.0) if (root_flare and t < 0.16) else 0.0)
			var offset := (right * cos(ang) + forward * sin(ang)) * (rad * lobe)
			ring_pts.append(center + offset)
		rings.append({"pts": ring_pts, "v": v_accum, "t": t})

	for i in range(rings.size() - 1):
		var r0: Array = rings[i]["pts"]
		var r1: Array = rings[i + 1]["pts"]
		var v0: float = rings[i]["v"]
		var v1: float = rings[i + 1]["v"]
		var col0 := Color(float(rings[i]["t"]), 0.0, 0.0, 1.0)
		var col1 := Color(float(rings[i + 1]["t"]), 0.0, 0.0, 1.0)

		for s in range(radial_segs):
			var u0 := float(s) / float(radial_segs)
			var u1 := float(s + 1) / float(radial_segs)

			st.set_color(col0); st.set_uv(Vector2(u0, v0)); st.add_vertex(r0[s])
			st.set_color(col1); st.set_uv(Vector2(u0, v1)); st.add_vertex(r1[s])
			st.set_color(col1); st.set_uv(Vector2(u1, v1)); st.add_vertex(r1[s + 1])

			st.set_color(col0); st.set_uv(Vector2(u0, v0)); st.add_vertex(r0[s])
			st.set_color(col1); st.set_uv(Vector2(u1, v1)); st.add_vertex(r1[s + 1])
			st.set_color(col0); st.set_uv(Vector2(u1, v0)); st.add_vertex(r0[s + 1])


static func _append_canopy_rosette(
	st: SurfaceTool,
	center: Vector3,
	radius: float,
	drooping: bool,
	rng: RandomNumberGenerator
) -> void:
	# 4 изогнутые ботанические ветки-карты под разными углами (никаких плоских крестов или кубиков!)
	var card_count := 4
	var base_yaw := rng.randf() * TAU
	for c in range(card_count):
		var yaw := base_yaw + float(c) * (TAU / float(card_count)) + rng.randf_range(-0.22, 0.22)
		var pitch := deg_to_rad(rng.randf_range(42.0, 68.0) if drooping else rng.randf_range(18.0, 48.0))
		var roll := rng.randf_range(-0.35, 0.35)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)

		var w := radius * 0.92
		var l := radius * 1.12
		var arch := -0.22 * radius

		# Двухсегментная изогнутая пластина ветви (4x2 вершин) для естественного объёма кроны
		var p00 := center + basis * Vector3(-w * 0.5, 0.0, 0.0)
		var p10 := center + basis * Vector3(w * 0.5, 0.0, 0.0)
		var p0m := center + basis * Vector3(-w * 0.54, arch * 0.35, l * 0.5)
		var p1m := center + basis * Vector3(w * 0.54, arch * 0.35, l * 0.5)
		var p01 := center + basis * Vector3(-w * 0.46, arch, l)
		var p11 := center + basis * Vector3(w * 0.46, arch, l)

		var seed_col := Color(rng.randf(), 0.5, 0.0, 1.0)
		var tip_col := Color(seed_col.r, 1.0, 0.0, 1.0)
		var base_col := Color(seed_col.r, 0.15, 0.0, 1.0)

		# Сегмент 1 (от ветки к середине)
		st.set_color(base_col); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p00)
		st.set_color(seed_col); st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(p0m)
		st.set_color(seed_col); st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(p1m)

		st.set_color(base_col); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p00)
		st.set_color(seed_col); st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(p1m)
		st.set_color(base_col); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p10)

		# Сегмент 2 (от середины к кончику побега)
		st.set_color(seed_col); st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(p0m)
		st.set_color(tip_col);  st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p01)
		st.set_color(tip_col);  st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p11)

		st.set_color(seed_col); st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(p0m)
		st.set_color(tip_col);  st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p11)
		st.set_color(seed_col); st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(p1m)


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
	// Горизонтальные чёрные чечевички русской берёзы + тёмный потрескавшийся комель у корней
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
	// У сосны нижняя кора тёмно-бурая, а верхняя — золотисто-янтарная
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


static func _get_dark_bark_material() -> Material:
	if _dark_bark_mat != null:
		return _dark_bark_mat
	_dark_bark_mat = AssetCatalog.get_pbr_material("bark_willow_02", Vector3(1.2, 0.9, 1.2), false, Color(0.80, 0.76, 0.70))
	return _dark_bark_mat


## Аналитический ботанический шейдер ветвей, зубчатых листьев и хвои (чёткость на любом расстоянии + ветер + Backlight)
static func _get_canopy_material(mode: int) -> Material:
	if mode == 0 and _birch_canopy_mat != null:
		return _birch_canopy_mat
	if mode == 1 and _conifer_canopy_mat != null:
		return _conifer_canopy_mat
	if mode == 2 and _broadleaf_canopy_mat != null:
		return _broadleaf_canopy_mat

	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley;

uniform int foliage_mode = 0; // 0 = берёза, 1 = хвоя сосны/ели, 2 = липа/яблоня
uniform vec3 leaf_dark : source_color = vec3(0.13, 0.28, 0.07);
uniform vec3 leaf_bright : source_color = vec3(0.35, 0.46, 0.12);

varying vec3 v_wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wpos = wp;
	float flex = COLOR.g; // 0 у основания ветки, 1 на кончике
	float gust = sin(TIME * 1.65 + wp.x * 0.14 + wp.z * 0.11);
	float flutter = sin(TIME * 5.2 + wp.x * 1.9 + wp.y * 2.3 + COLOR.r * 12.0) * 0.035;
	VERTEX.x += (gust * 0.16 + flutter) * flex;
	VERTEX.z += (cos(TIME * 1.35 + wp.z * 0.15) * 0.12 + flutter) * flex;
	VERTEX.y += flutter * 0.6 * flex;
}

// Форма одного зубчатого листа в локальных координатах [-1..1, 0..1]
float leaf_shape(vec2 lp, out float vein) {
	if (lp.y < 0.0 || lp.y > 1.0) return 0.0;
	float env = sin(pow(lp.y, 0.72) * 3.14159265) * (1.0 - 0.25 * lp.y);
	float teeth = 0.045 * sin(lp.y * 38.0) * env;
	float w = max(0.001, env * 0.58 + teeth);
	float ax = abs(lp.x);
	if (ax > w) return 0.0;
	vein = exp(-ax * 26.0) + exp(-abs(sin((lp.y - ax * 0.65) * 24.0)) * 9.0) * 0.35;
	return 1.0;
}

void fragment() {
	vec2 uv = UV;
	float v = 1.0 - uv.y; // 0 у основания побега, 1 на макушке
	float u = (uv.x - 0.5) * 2.0; // -1..+1

	// Изогнутый деревянный черенок ветки
	float stem_x = 0.06 * sin(v * 5.5 + COLOR.r * 6.28);
	float stem_w = mix(0.026, 0.007, v);
	float on_stem = (v < 0.92 && abs(u - stem_x) < stem_w) ? 1.0 : 0.0;

	float alpha = on_stem;
	float is_wood = on_stem;
	float shade_var = 0.5;
	float vein_val = 0.0;

	if (foliage_mode == 1) {
		// ХВОЙНАЯ ЛАПА СОСНЫ / ЕЛИ: боковые побеги с густыми пучками отдельных хвоинок
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float sv = 0.10 + fi * 0.125;
			float side = (i % 2 == 0) ? 1.0 : -1.0;
			vec2 origin = vec2(0.06 * sin(sv * 5.5 + COLOR.r * 6.28), sv);
			float ang = side * mix(0.95, 0.52, sv);
			vec2 dir = vec2(sin(ang), cos(ang));
			vec2 nrm = vec2(dir.y, -dir.x);
			vec2 rel = vec2(u, v) - origin;
			float along = dot(rel, dir);
			float perp = dot(rel, nrm);
			float max_l = mix(0.76, 0.28, sv);
			if (along > -0.04 && along < max_l) {
				if (abs(perp) < 0.012 && along > 0.0) {
					alpha = 1.0;
					is_wood = 1.0;
				}
				// Хвоинки под острым углом вдоль бокового побега
				float needle_reach = mix(0.22, 0.09, along / max_l);
				if (abs(perp) < needle_reach) {
					float comb = sin((along * 46.0 - abs(perp) * 28.0) + fi * 1.7);
					if (comb > 0.12) {
						alpha = 1.0;
						is_wood = 0.0;
						shade_var = clamp(along / max_l + abs(perp) * 1.8, 0.0, 1.0);
					}
				}
			}
		}
		// Верхушечная кисточка хвои
		vec2 top_rel = vec2(u - stem_x, v - 0.84);
		float tr = length(top_rel);
		if (tr < 0.24) {
			float rays = sin(atan(top_rel.x, top_rel.y) * 22.0 + COLOR.r * 9.0);
			if (rays > 0.15) {
				alpha = 1.0;
				is_wood = 0.0;
				shade_var = 0.85;
			}
		}
	} else {
		// ЛИСТВЕННАЯ ВЕТКА (БЕРЁЗА / ЯБЛОНЯ / ЛИПА): гроздья отдельных зубчатых листьев с прожилками
		int pairs = 11;
		for (int i = 0; i < 11; i++) {
			float fi = float(i);
			float lv_base = 0.08 + fi * 0.080;
			float side = (i % 2 == 0) ? 1.0 : -1.0;
			float spread_x = stem_x + side * mix(0.10, 0.48, hash21(vec2(fi, floor(COLOR.r * 10.0 + 0.5))));
			if (i >= 9) spread_x = stem_x + side * 0.08;
			vec2 l_orig = vec2(spread_x * 0.55, lv_base);
			float lang = side * (0.45 + 0.55 * hash21(vec2(fi * 3.1, 1.7)));
			if (i == 10) lang = 0.05;
			float cs = cos(lang);
			float sn = sin(lang);
			vec2 d = vec2(u, v) - l_orig;
			vec2 rot_d = vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
			float l_scale = (foliage_mode == 0) ? 0.27 : 0.33;
			float v_tmp = 0.0;
			if (leaf_shape(rot_d / l_scale, v_tmp) > 0.5) {
				alpha = 1.0;
				is_wood = 0.0;
				vein_val = v_tmp;
				shade_var = fract(fi * 0.37 + COLOR.r);
			}
		}
	}

	if (alpha < 0.5) {
		discard;
	}

	if (is_wood > 0.5) {
		ALBEDO = (foliage_mode == 0) ? vec3(0.28, 0.22, 0.17) : vec3(0.24, 0.17, 0.11);
		ROUGHNESS = 0.88;
		BACKLIGHT = vec3(0.0);
	} else {
		// Августовская палитра листвы: глубокая зелень + тёплые золотистые пряди у берёз на солнце
		float tree_gold = smoothstep(0.62, 0.95, sin(v_wpos.x * 0.09 + v_wpos.z * 0.07) * 0.5 + 0.5);
		vec3 col = mix(leaf_dark, leaf_bright, shade_var);
		if (foliage_mode == 0) {
			col = mix(col, vec3(0.58, 0.50, 0.12), tree_gold * shade_var * 0.55);
		}
		col *= (1.0 - vein_val * 0.14);
		ALBEDO = col;
		ROUGHNESS = (foliage_mode == 1) ? 0.62 : 0.54;
		SPECULAR = 0.28;
		BACKLIGHT = col * ((foliage_mode == 1) ? 0.45 : 0.85);
	}
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("foliage_mode", mode)
	if mode == 0:
		sm.set_shader_parameter("leaf_dark", Vector3(0.14, 0.30, 0.07))
		sm.set_shader_parameter("leaf_bright", Vector3(0.36, 0.48, 0.12))
		_birch_canopy_mat = sm
	elif mode == 1:
		sm.set_shader_parameter("leaf_dark", Vector3(0.06, 0.18, 0.06))
		sm.set_shader_parameter("leaf_bright", Vector3(0.16, 0.31, 0.10))
		_conifer_canopy_mat = sm
	else:
		sm.set_shader_parameter("leaf_dark", Vector3(0.11, 0.27, 0.07))
		sm.set_shader_parameter("leaf_bright", Vector3(0.29, 0.43, 0.11))
		_broadleaf_canopy_mat = sm
	return sm


# ============================================================================
# 2. ТЫСЯЧИ РЕАЛЬНЫХ 3D-ФОТОСКАНОВ ПОЛИ ХЕЙВЕН (КРАПИВА, ЧИСТОТЕЛ, КУСТЫ, ПАПОРОТНИК)
# ============================================================================

static func _build_photoscanned_undergrowth(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var shrub2 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_02/model.gltf")
	var shrub3 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_03/model.gltf")
	var shrub4 := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_04/model.gltf")
	var nettles := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/nettle_plant/model.gltf")
	var celandines := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/celandine_01/model.gltf")
	var ferns := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/fern_02/model.gltf")
	var grass_ph := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/grass_medium_02/model.gltf")

	# А) Густые кусты для пряток (у заборов, в палисадниках, вдоль кюветов и в лесу — ~650 кустов)
	var shrub_buckets: Array = [[], [], []]
	for _i in range(950):
		var sx := rng.randf_range(-85.0, 85.0)
		var sz := rng.randf_range(-85.0, 85.0)
		if TerrainBuilder.get_road_distance(sx, sz) < 4.2 or TerrainBuilder.get_footpath_distance(sx, sz) < 1.9:
			continue
		if TerrainBuilder.is_inside_building_footprint(sx, sz, 1.4):
			continue
		if Vector2(sx, sz).distance_to(Vector2(14.0, -4.0)) < 5.5:
			continue
		var sy := TerrainBuilder.get_height(sx, sz)
		var b_idx := rng.randi() % 3
		var sc := rng.randf_range(0.95, 1.55) if b_idx == 0 else rng.randf_range(2.1, 3.4)
		(shrub_buckets[b_idx] as Array).append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(sx, sy - 0.04, sz))
		)

	if not shrub2.is_empty():
		_add_multimesh_batch(parent, "Shrubs_Large", shrub2[0], shrub_buckets[0], 125.0, true)
	if not shrub3.is_empty():
		_add_multimesh_batch(parent, "Shrubs_Mid", shrub3[0], shrub_buckets[1], 105.0, false)
	if not shrub4.is_empty():
		_add_multimesh_batch(parent, "Shrubs_Low", shrub4[0], shrub_buckets[2], 95.0, false)

	# Б) Заросли высокой жгучей крапивы и чистотела вдоль деревенских заборов, сараев и придорожных канав!
	var nettle_xf: Array[Transform3D] = []
	var celandine_xf: Array[Transform3D] = []
	for plot in TerrainBuilder.HOUSE_PLOTS:
		var c: Vector2 = plot["pos"]
		for _k in range(135):
			var offset := Vector2(rng.randf_range(-11.5, 11.5), rng.randf_range(-11.5, 11.5))
			# Сгущаем у заборов и за сараями
			if absf(offset.x) < 6.2 and absf(offset.y) < 5.5:
				continue
			var np := c + offset
			if TerrainBuilder.get_road_distance(np.x, np.y) < 3.6 or TerrainBuilder.get_footpath_distance(np.x, np.y) < 1.4:
				continue
			if TerrainBuilder.is_inside_building_footprint(np.x, np.y, 0.5):
				continue
			var ny := TerrainBuilder.get_height(np.x, np.y)
			if rng.randf() < 0.58:
				var nsc := rng.randf_range(3.8, 5.8) # Крапива 0.85..1.25 м высотой!
				nettle_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(nsc, nsc, nsc)), Vector3(np.x, ny, np.y)))
			else:
				var csc := rng.randf_range(2.2, 3.4)
				celandine_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(csc, csc, csc)), Vector3(np.x, ny, np.y)))

	# Добавляем крапиву вдоль кюветов просёлочной дороги
	for i in range(420):
		var dz := rng.randf_range(-84.0, 84.0)
		var side := -1.0 if (i % 2 == 0) else 1.0
		var dx := TerrainBuilder.get_road_center_x(dz) + side * rng.randf_range(4.1, 6.4)
		if TerrainBuilder.get_footpath_distance(dx, dz) < 1.5 or TerrainBuilder.is_inside_building_footprint(dx, dz, 0.6):
			continue
		var dy := TerrainBuilder.get_height(dx, dz)
		var nsc2 := rng.randf_range(3.5, 5.4)
		nettle_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(nsc2, nsc2, nsc2)), Vector3(dx, dy, dz)))

	if not nettles.is_empty() and not nettle_xf.is_empty():
		# Берём высокий вариант крапивы (индекс 4 — nettle_plant_tall_a_LOD0)
		var tall_nettle: Mesh = nettles[mini(4, nettles.size() - 1)]
		_add_multimesh_batch(parent, "PhotoscannedNettles", tall_nettle, nettle_xf, 72.0, false)
	if not celandines.is_empty() and not celandine_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedCelandine", celandines[0], celandine_xf, 68.0, false)

	# В) Ковёр лесных папоротников вдоль лесной тропинки и под елями (~1 700 кустов)
	var fern_xf: Array[Transform3D] = []
	for _i in range(2100):
		var fx := rng.randf_range(10.0, 86.0)
		var fz := rng.randf_range(-85.0, 85.0)
		if TerrainBuilder.get_forest_factor(fx, fz) < 0.25:
			continue
		if TerrainBuilder.get_footpath_distance(fx, fz) < 1.35 or TerrainBuilder.is_inside_building_footprint(fx, fz, 1.0):
			continue
		var fy := TerrainBuilder.get_height(fx, fz)
		var fsc := rng.randf_range(1.45, 2.35)
		fern_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(fsc, fsc, fsc)), Vector3(fx, fy, fz)))

	if not ferns.is_empty() and not fern_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedFerns", ferns[0], fern_xf, 80.0, false)

	# Г) Фотосканированные кочки травы вдоль всех тропинок и обочин (~3 200 шт.)
	var ph_grass_xf: Array[Transform3D] = []
	for _i in range(3400):
		var gx := rng.randf_range(-84.0, 84.0)
		var gz := rng.randf_range(-84.0, 84.0)
		var rd := TerrainBuilder.get_road_distance(gx, gz)
		var pd := TerrainBuilder.get_footpath_distance(gx, gz)
		if rd < 3.1 or pd < 1.05 or TerrainBuilder.is_inside_building_footprint(gx, gz, 0.5):
			continue
		var gy := TerrainBuilder.get_height(gx, gz)
		var gsc := rng.randf_range(1.8, 3.1)
		ph_grass_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(gsc, gsc, gsc)), Vector3(gx, gy, gz)))

	if not grass_ph.is_empty() and not ph_grass_xf.is_empty():
		_add_multimesh_batch(parent, "PhotoscannedGrassClumps", grass_ph[grass_ph.size() - 1], ph_grass_xf, 66.0, false)


# ============================================================================
# 3. ГУСТОЙ АВГУСТОВСКИЙ ЛУГ — 56 000+ ПУЧКОВ ВЫСОКОЙ 3D-ТРАВЫ НА GPU (MultiMesh)
# ============================================================================

static func _build_gpu_meadow_grass(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var tuft_mesh := _create_curved_grass_tuft_mesh()

	# Разбиваем карту 180×180 м на 4 квадранта по ~14 000 кустов (всего ~56 000 кустов = ~450 000 изогнутых травинок!),
	# чтобы Frustum Culling и Distance Fade на GPU отсекали невидимые квадранты мгновенно.
	var quadrants: Array = [[], [], [], []]

	for _i in range(68000):
		var gx := rng.randf_range(-86.5, 86.5)
		var gz := rng.randf_range(-86.5, 86.5)

		var weights := TerrainBuilder.get_surface_weights(gx, gz)
		if weights.r > 0.35 or weights.g > 0.42:
			continue
		if TerrainBuilder.is_inside_building_footprint(gx, gz, 0.35):
			continue
		# В глубоком тёмном ельнике трава реже (там преобладает хвоя и папоротник)
		if weights.b > 0.72 and rng.randf() < 0.62:
			continue

		var gy := TerrainBuilder.get_height(gx, gz)
		# Островками делаем высокий некошеный бурьян (до 0.95..1.25 м!), в котором легко спрятаться присев на Ctrl!
		var wild_patch := sin(gx * 0.13 + 1.1) * cos(gz * 0.15 - 0.6)
		var h_scale := rng.randf_range(0.85, 1.55) if (wild_patch > 0.25) else rng.randf_range(0.48, 0.92)
		var w_scale := rng.randf_range(0.75, 1.20)

		var xf := Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w_scale, h_scale, w_scale)),
			Vector3(gx, gy - 0.02, gz)
		)
		var q_idx := (0 if gx < 0.0 else 1) + (0 if gz < 0.0 else 2)
		(quadrants[q_idx] as Array).append(xf)

	for q in range(4):
		var list_q: Array = quadrants[q]
		if list_q.is_empty():
			continue
		_add_multimesh_batch(parent, "MeadowGrass_Q%d" % q, tuft_mesh, list_q, 78.0, false)


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

		var h := rng.randf_range(0.62, 0.92)
		var droop := rng.randf_range(0.16, 0.34)
		var w0 := 0.026
		var w1 := 0.018
		var w2 := 0.009

		var p0 := base
		var p1 := base + Vector3(0.0, h * 0.42, 0.0) + dir * (droop * 0.25)
		var p2 := base + Vector3(0.0, h * 0.76, 0.0) + dir * (droop * 0.65)
		var p3 := base + Vector3(0.0, h, 0.0) + dir * droop

		var nrm := (Vector3.UP * 0.82 - dir * 0.18).normalized()
		var seed_r := rng.randf()

		# 3 изогнутых сегмента на каждую травинку с острым кончиком
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

	// Волны августовского ветра по полю
	float wave = sin(TIME * 2.05 + wp.x * 0.22 + wp.z * 0.16) + 0.45 * cos(TIME * 3.4 - wp.x * 0.35 + v_seed * 6.28);
	float bend = v_height * v_height;
	VERTEX.x += wave * 0.15 * bend;
	VERTEX.z += wave * 0.09 * bend;
	VERTEX.y -= abs(wave) * 0.03 * bend;
}

void fragment() {
	vec3 root_col = vec3(0.07, 0.14, 0.04);
	vec3 mid_green = mix(vec3(0.16, 0.31, 0.08), vec3(0.26, 0.35, 0.10), v_patch);
	// Подсохшие золотистые августовские колоски на кончиках травы
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


static func _add_multimesh_batch(
	parent: Node3D,
	batch_name: String,
	mesh: Mesh,
	xforms: Array,
	vis_end: float,
	cast_shadows: bool
) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = batch_name
	mmi.multimesh = mm
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_end_margin = 10.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
