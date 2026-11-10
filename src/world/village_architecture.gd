class_name VillageArchitecture
extends RefCounted
## Детализированная сельская архитектура Восточной Европы (Август):
## - 7 открытых жилых малоэтажных домов (с интерьерами, перегородками, окнами с наличниками, крыльцом, шиферными крышами и трубами)
## - Лесная избушка лесника в восточной чаще
## - Хозяйственные сараи, поленницы дров, деревенский колодец с ведром, лавочки у калиток, деревянные и шиферные заборы
## - Деревянные столбы ЛЭП с провисающими проводами и тёплыми уличными фонарями вдоль грунтовки
## - Полностью замкнутый периметр 180×180 м (глухие заборы + непролазные заросли и бурелом, 0 обрывов).


static func build_all(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "EasternEuropeanVillage"
	parent.add_child(root)

	for plot in TerrainBuilder.HOUSE_PLOTS:
		var style := String(plot["style"])
		var c: Vector2 = plot["pos"]
		var yaw: float = float(plot["yaw"])
		var ground_y := TerrainBuilder.get_height(c.x, c.y)
		var house_pos := Vector3(c.x, ground_y, c.y)

		if style == "forester_hut":
			_build_forester_cabin(root, house_pos, yaw)
		else:
			_build_enterable_village_house(root, house_pos, yaw, style, rng)
			_build_homestead_yard(root, house_pos, yaw, style, rng)

	_build_village_well(root, Vector3(-15.0, TerrainBuilder.get_height(-15.0, -6.0), -6.0))
	_build_campfire_glade_seating(root, Vector3(14.0, TerrainBuilder.get_height(14.0, -4.0), -4.0))
	_build_forest_boulder_glade(root, Vector3(45.0, TerrainBuilder.get_height(45.0, 42.0), 42.0), rng)
	_build_power_line_and_streetlamps(root)
	_build_airtight_outer_perimeter(root, rng)


# ============================================================================
# 1. ОТКРЫТЫЕ СЕЛЬСКИЕ ДОМА С ИНТЕРЬЕРОМ, ОКНАМИ, КРЫЛЬЦОМ И ДВУСКАТНОЙ КРЫШЕЙ
# ============================================================================

static func _build_enterable_village_house(
	parent: Node3D,
	world_pos: Vector3,
	yaw: float,
	style: String,
	rng: RandomNumberGenerator
) -> void:
	var h_root := Node3D.new()
	h_root.name = "VillageHouse_%s" % style
	h_root.position = world_pos
	h_root.rotation.y = yaw
	parent.add_child(h_root)

	var sb := StaticBody3D.new()
	sb.name = "HouseStaticBody"
	sb.collision_layer = 1
	sb.collision_mask = 0
	h_root.add_child(sb)

	# Подбор аутентичных 4K PBR-материалов под стиль конкретного дома
	var mat_wall_ext: Material
	var mat_roof: Material
	var mat_trim := AssetCatalog.get_pbr_material(" worn_mossy_plasterwall".strip_edges(), Vector3(0.4, 0.4, 0.4), true, Color(0.95, 0.94, 0.90))
	var mat_wood_dark := AssetCatalog.get_pbr_material("brown_planks_03", Vector3(0.35, 0.35, 0.35), true, Color(0.72, 0.58, 0.44))
	var mat_floor := AssetCatalog.get_pbr_material("brown_planks_03", Vector3(0.42, 0.42, 0.42), true, Color(0.82, 0.68, 0.50))
	var mat_interior := AssetCatalog.get_pbr_material("worn_mossy_plasterwall", Vector3(0.32, 0.32, 0.32), true, Color(0.92, 0.90, 0.84))
	var mat_plinth := AssetCatalog.get_pbr_material("brick_wall_001", Vector3(0.40, 0.40, 0.40), true, Color(0.78, 0.72, 0.68))
	var mat_brick := AssetCatalog.get_pbr_material("brick_wall_001", Vector3(0.45, 0.45, 0.45), true)

	match style:
		"blue_wood":
			mat_wall_ext = AssetCatalog.get_pbr_material("blue_painted_planks", Vector3(0.36, 0.36, 0.36), true)
			mat_roof = AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.38, 0.38, 0.38), true, Color(0.72, 0.74, 0.75), 1.15, 0.08) # Серый шифер
		"white_plaster":
			mat_wall_ext = AssetCatalog.get_pbr_material("worn_mossy_plasterwall", Vector3(0.28, 0.28, 0.28), true, Color(0.96, 0.95, 0.92))
			mat_roof = AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.36, 0.36, 0.36), true, Color(0.68, 0.34, 0.26), 0.95, 0.45) # Крашеное железо
			mat_trim = AssetCatalog.get_pbr_material("blue_painted_planks", Vector3(0.5, 0.5, 0.5), true)
		"log_cabin":
			mat_wall_ext = AssetCatalog.get_pbr_material("knotted_pine_bark", Vector3(0.35, 0.55, 0.35), true, Color(0.86, 0.70, 0.52))
			mat_roof = AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.38, 0.38, 0.38), true, Color(0.65, 0.67, 0.66), 1.2, 0.05)
		"green_wood":
			mat_wall_ext = AssetCatalog.get_pbr_material("green_rough_planks", Vector3(0.36, 0.36, 0.36), true)
			mat_roof = AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.36, 0.36, 0.36), true, Color(0.70, 0.72, 0.72), 1.15, 0.10)
		"blue_plaster":
			mat_wall_ext = AssetCatalog.get_pbr_material("blue_plaster_weathered", Vector3(0.28, 0.28, 0.28), true)
			mat_roof = AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.36, 0.36, 0.36), true, Color(0.32, 0.46, 0.36), 0.9, 0.5)
		_: # brick_cottage
			mat_wall_ext = mat_brick
			mat_roof = AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.38, 0.38, 0.38), true, Color(0.58, 0.32, 0.26), 0.95, 0.4)

	var w := 8.8  # Ширина дома по X
	var d := 7.4  # Глубина дома по Z (+Z смотрит к калитке и дороге)
	var wall_t := 0.24
	var plinth_h := 0.38
	var wall_h := 2.95
	var floor_y := plinth_h

	# 1. Каменный/кирпичный цоколь и деревянный пол внутри дома (утоплен до -0.6м в землю, чтобы на любом уклоне не было щелей)
	_add_box_part(sb, Vector3(w + 0.16, plinth_h + 0.60, d + 0.16), Vector3(0.0, (plinth_h - 0.60) * 0.5, 0.0), Vector3.ZERO, mat_plinth)
	_add_box_part(sb, Vector3(w - 0.12, 0.08, d - 0.12), Vector3(0.0, floor_y + 0.02, 0.0), Vector3.ZERO, mat_floor)

	# 2. Фронтальная стена (+Z): входной проём справа (x = +1.8, ширина 1.35 м) и окно слева (x = -1.9, ширина 1.40 м)
	var fz := d * 0.5 - wall_t * 0.5
	# Левый простенок [-4.4 .. -2.6], простенок между окном и дверью [-1.2 .. +1.12], правый простенок [+2.48 .. +4.4]
	_add_box_part(sb, Vector3(1.80, wall_h, wall_t), Vector3(-3.50, floor_y + wall_h * 0.5, fz), Vector3.ZERO, mat_wall_ext)
	_add_box_part(sb, Vector3(2.32, wall_h, wall_t), Vector3(-0.04, floor_y + wall_h * 0.5, fz), Vector3.ZERO, mat_wall_ext)
	_add_box_part(sb, Vector3(1.92, wall_h, wall_t), Vector3(3.44, floor_y + wall_h * 0.5, fz), Vector3.ZERO, mat_wall_ext)
	# Подоконная и надоконная части у фронтального окна (x = -1.90, ширина 1.40, проём y = 0.95..2.15 над полом)
	_add_box_part(sb, Vector3(1.40, 0.95, wall_t), Vector3(-1.90, floor_y + 0.475, fz), Vector3.ZERO, mat_wall_ext)
	_add_box_part(sb, Vector3(1.40, wall_h - 2.15, wall_t), Vector3(-1.90, floor_y + 2.15 + (wall_h - 2.15) * 0.5, fz), Vector3.ZERO, mat_wall_ext)
	_build_window_trim_and_shutters(sb, Vector3(-1.90, floor_y + 1.55, fz), 0.0, 1.40, 1.20, mat_trim, mat_wood_dark)
	# Перемычка над входной дверью (x = +1.80, ширина 1.36, высота двери 2.25 м) + распахнутая внутрь деревянная дверь
	_add_box_part(sb, Vector3(1.36, wall_h - 2.25, wall_t), Vector3(1.80, floor_y + 2.25 + (wall_h - 2.25) * 0.5, fz), Vector3.ZERO, mat_wall_ext)
	_add_box_part(sb, Vector3(0.08, 2.20, 1.15), Vector3(1.16, floor_y + 1.12, fz - 0.65), Vector3(0.0, -22.0, 0.0), mat_wood_dark)

	# 3. Задняя стена (-Z) с окном в сад (x = +1.5)
	var bz := -d * 0.5 + wall_t * 0.5
	_build_wall_with_center_window(sb, Vector3(0.0, floor_y, bz), 0.0, w, wall_h, wall_t, 1.40, mat_wall_ext, mat_trim, mat_wood_dark, PI)

	# 4. Левая (-X) и Правая (+X) боковые стены с окнами (можно выглядывать и перепрыгивать!)
	var side_len := d - wall_t * 2.0
	_build_wall_with_center_window(sb, Vector3(-w * 0.5 + wall_t * 0.5, floor_y, 0.0), PI * 0.5, side_len, wall_h, wall_t, 1.35, mat_wall_ext, mat_trim, mat_wood_dark, -PI * 0.5)
	_build_wall_with_center_window(sb, Vector3(w * 0.5 - wall_t * 0.5, floor_y, 0.0), PI * 0.5, side_len, wall_h, wall_t, 1.35, mat_wall_ext, mat_trim, mat_wood_dark, PI * 0.5)

	# Если это бревенчатый сруб — добавляем характерные выступающие венцы брёвен («рубка с остатком») по углам!
	if style == "log_cabin":
		for cx in [-w * 0.5, w * 0.5]:
			for cz in [-d * 0.5, d * 0.5]:
				for course in range(10):
					var ly := floor_y + 0.16 + float(course) * 0.28
					_add_box_part(sb, Vector3(0.58, 0.24, 0.24), Vector3(cx, ly, cz), Vector3.ZERO, mat_wall_ext, false)
					_add_box_part(sb, Vector3(0.24, 0.24, 0.58), Vector3(cx, ly + 0.14, cz), Vector3.ZERO, mat_wall_ext, false)

	# 5. Внутренняя межкомнатная перегородка с дверным проёмом (создаёт две комнаты для пряток!)
	_add_box_part(sb, Vector3(0.16, wall_h, 3.8), Vector3(0.45, floor_y + wall_h * 0.5, -1.55), Vector3.ZERO, mat_interior)
	_add_box_part(sb, Vector3(0.16, wall_h, 1.6), Vector3(0.45, floor_y + wall_h * 0.5, 2.65), Vector3.ZERO, mat_interior)
	_add_box_part(sb, Vector3(0.16, wall_h - 2.15, 1.8), Vector3(0.45, floor_y + 2.15 + (wall_h - 2.15) * 0.5, 1.15), Vector3.ZERO, mat_interior)

	# Потолочные деревянные балки перекрытия
	_add_box_part(sb, Vector3(w + 0.1, 0.16, d + 0.1), Vector3(0.0, floor_y + wall_h + 0.08, 0.0), Vector3.ZERO, mat_wood_dark)

	# 6. Двускатная шиферная/железная крыша со свесами, чердачными фронтонами и кирпичной печной трубой
	var roof_top_y := floor_y + wall_h + 0.16
	var ridge_h := 2.25
	var slope_angle := atan2(ridge_h, d * 0.5 + 0.55)
	var slope_len := sqrt(pow(d * 0.5 + 0.58, 2.0) + ridge_h * ridge_h)
	var roof_w := w + 0.95

	# Передний и задний скаты крыши
	var mid_z := (d * 0.5 + 0.55) * 0.5
	var mid_y := roof_top_y + ridge_h * 0.5
	_add_box_part(sb, Vector3(roof_w, 0.12, slope_len), Vector3(0.0, mid_y, mid_z), Vector3(rad_to_deg(slope_angle), 0.0, 0.0), mat_roof)
	_add_box_part(sb, Vector3(roof_w, 0.12, slope_len), Vector3(0.0, mid_y, -mid_z), Vector3(rad_to_deg(-slope_angle), 0.0, 0.0), mat_roof)
	# Конёк крыши
	_add_box_part(sb, Vector3(roof_w + 0.06, 0.18, 0.26), Vector3(0.0, roof_top_y + ridge_h + 0.04, 0.0), Vector3.ZERO, mat_trim, false)

	# Треугольные деревянные фронтоны чердака слева и справа
	_add_gable_prism(h_root, Vector3(-w * 0.5, roof_top_y, 0.0), d, ridge_h, -1.0, mat_wood_dark)
	_add_gable_prism(h_root, Vector3(w * 0.5, roof_top_y, 0.0), d, ridge_h, 1.0, mat_wood_dark)

	# Кирпичная печная труба с жестяным колпаком
	_add_box_part(sb, Vector3(0.68, 1.65, 0.68), Vector3(-1.1, roof_top_y + ridge_h - 0.15, -0.65), Vector3.ZERO, mat_brick)
	_add_box_part(sb, Vector3(0.84, 0.10, 0.84), Vector3(-1.1, roof_top_y + ridge_h + 0.72, -0.65), Vector3.ZERO, mat_roof, false)

	# 7. Деревянное крыльцо со ступенями, резными столбиками, козырьком и уличным бра
	var porch_x := 1.80
	var porch_z := d * 0.5 + 0.85
	_add_box_part(sb, Vector3(2.35, plinth_h, 1.65), Vector3(porch_x, plinth_h * 0.5, porch_z), Vector3.ZERO, mat_wood_dark)
	_add_box_part(sb, Vector3(1.85, plinth_h * 0.52, 0.48), Vector3(porch_x, plinth_h * 0.26, porch_z + 1.02), Vector3.ZERO, mat_wood_dark)
	# Опорные столбики, перила и козырёк крыльца
	for sx in [-1.05, 1.05]:
		_add_box_part(sb, Vector3(0.11, 2.35, 0.11), Vector3(porch_x + sx, plinth_h + 1.175, porch_z + 0.72), Vector3.ZERO, mat_trim)
		_add_box_part(sb, Vector3(0.09, 0.88, 1.50), Vector3(porch_x + sx, plinth_h + 0.44, porch_z), Vector3.ZERO, mat_trim)
	_add_box_part(sb, Vector3(2.65, 0.10, 1.95), Vector3(porch_x, plinth_h + 2.42, porch_z + 0.05), Vector3(12.0, 0.0, 0.0), mat_roof)

	# Фотоскан настенного фонаря над входом + мягкий тёплый свет
	var wlamp := AssetCatalog.instantiate_model("res://assets/downloaded/models/industrial_wall_lamp/model.gltf")
	if wlamp != null:
		wlamp.position = Vector3(porch_x - 0.82, floor_y + 2.05, d * 0.5 + 0.02)
		h_root.add_child(wlamp)
	var plight := OmniLight3D.new()
	plight.light_color = Color(1.0, 0.74, 0.40)
	plight.light_energy = 1.45
	plight.omni_range = 8.5
	plight.position = Vector3(porch_x - 0.65, floor_y + 1.95, d * 0.5 + 0.35)
	h_root.add_child(plight)

	# 8. Мебель внутри дома (стол и лавка в горнице для укрытия)
	var bench := AssetCatalog.instantiate_model("res://assets/downloaded/models/painted_wooden_bench/model.gltf")
	if bench != null:
		bench.position = Vector3(-2.4, floor_y + 0.04, -2.2)
		h_root.add_child(bench)
	_add_box_part(sb, Vector3(1.5, 0.76, 0.9), Vector3(-2.4, floor_y + 0.40, -0.9), Vector3.ZERO, mat_wood_dark)

	if rng.randf() < 0.6:
		# Тёплый свет настольной лампы в комнате (красиво светится сквозь окна в августовских сумерках!)
		var ilight := OmniLight3D.new()
		ilight.light_color = Color(1.0, 0.70, 0.34)
		ilight.light_energy = 1.25
		ilight.omni_range = 7.0
		ilight.position = Vector3(-2.0, floor_y + 1.65, -0.9)
		h_root.add_child(ilight)


static func _build_forester_cabin(parent: Node3D, world_pos: Vector3, yaw: float) -> void:
	var h_root := Node3D.new()
	h_root.name = "ForesterCabin"
	h_root.position = world_pos
	h_root.rotation.y = yaw
	parent.add_child(h_root)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	h_root.add_child(sb)

	var mat_log := AssetCatalog.get_pbr_material("knotted_pine_bark", Vector3(0.4, 0.6, 0.4), true, Color(0.76, 0.60, 0.42))
	var mat_wood := AssetCatalog.get_pbr_material("brown_planks_03", Vector3(0.4, 0.4, 0.4), true, Color(0.68, 0.54, 0.38))
	var mat_roof := AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.4, 0.4, 0.4), true, Color(0.48, 0.42, 0.36))
	var mat_stone := AssetCatalog.get_pbr_material("gravel_concrete_02", Vector3(0.4, 0.4, 0.4), true)

	var w := 6.2
	var d := 5.4
	var floor_y := 0.28
	var wall_h := 2.55
	var wt := 0.24

	_add_box_part(sb, Vector3(w + 0.2, floor_y + 0.5, d + 0.2), Vector3(0.0, (floor_y - 0.5) * 0.5, 0.0), Vector3.ZERO, mat_stone)
	_add_box_part(sb, Vector3(w - 0.1, 0.08, d - 0.1), Vector3(0.0, floor_y + 0.02, 0.0), Vector3.ZERO, mat_wood)

	# Фронт с дверью по центру
	var fz := d * 0.5 - wt * 0.5
	_add_box_part(sb, Vector3(2.4, wall_h, wt), Vector3(-1.9, floor_y + wall_h * 0.5, fz), Vector3.ZERO, mat_log)
	_add_box_part(sb, Vector3(2.4, wall_h, wt), Vector3(1.9, floor_y + wall_h * 0.5, fz), Vector3.ZERO, mat_log)
	_add_box_part(sb, Vector3(1.4, wall_h - 2.1, wt), Vector3(0.0, floor_y + 2.1 + (wall_h - 2.1) * 0.5, fz), Vector3.ZERO, mat_log)

	# Задняя и боковые стены с окнами
	_build_wall_with_center_window(sb, Vector3(0.0, floor_y, -fz), 0.0, w, wall_h, wt, 1.15, mat_log, mat_wood, mat_wood, PI)
	_build_wall_with_center_window(sb, Vector3(-w * 0.5 + wt * 0.5, floor_y, 0.0), PI * 0.5, d - wt * 2.0, wall_h, wt, 1.15, mat_log, mat_wood, mat_wood, -PI * 0.5)
	_build_wall_with_center_window(sb, Vector3(w * 0.5 - wt * 0.5, floor_y, 0.0), PI * 0.5, d - wt * 2.0, wall_h, wt, 1.15, mat_log, mat_wood, mat_wood, PI * 0.5)

	# Крыша избушки
	var roof_y := floor_y + wall_h + 0.08
	var r_h := 1.65
	var ang := atan2(r_h, d * 0.5 + 0.45)
	var slen := sqrt(pow(d * 0.5 + 0.48, 2.0) + r_h * r_h)
	_add_box_part(sb, Vector3(w + 0.8, 0.12, slen), Vector3(0.0, roof_y + r_h * 0.5, (d * 0.5 + 0.45) * 0.5), Vector3(rad_to_deg(ang), 0.0, 0.0), mat_roof)
	_add_box_part(sb, Vector3(w + 0.8, 0.12, slen), Vector3(0.0, roof_y + r_h * 0.5, -(d * 0.5 + 0.45) * 0.5), Vector3(rad_to_deg(-ang), 0.0, 0.0), mat_roof)
	_add_gable_prism(h_root, Vector3(-w * 0.5, roof_y, 0.0), d, r_h, -1.0, mat_wood)
	_add_gable_prism(h_root, Vector3(w * 0.5, roof_y, 0.0), d, r_h, 1.0, mat_wood)

	# Фонарь у входа в избушку лесника
	var lant := AssetCatalog.instantiate_model("res://assets/downloaded/models/wooden_lantern_01/model.gltf")
	if lant != null:
		lant.position = Vector3(1.1, floor_y + 1.75, d * 0.5 + 0.18)
		h_root.add_child(lant)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.68, 0.30)
	fl.light_energy = 1.8
	fl.omni_range = 10.0
	fl.position = Vector3(1.1, floor_y + 1.8, d * 0.5 + 0.32)
	h_root.add_child(fl)


static func _build_wall_with_center_window(
	sb: StaticBody3D,
	base_center: Vector3,
	wall_yaw: float,
	total_len: float,
	wall_h: float,
	wall_t: float,
	win_w: float,
	mat_wall: Material,
	mat_trim: Material,
	mat_shutter: Material,
	outward_yaw: float
) -> void:
	var holder := Node3D.new()
	holder.position = base_center
	holder.rotation.y = wall_yaw
	sb.add_child(holder)

	var side_w := (total_len - win_w) * 0.5
	var sill_h := 0.96
	var head_y := 2.12

	# Левый и правый глухие простенки, подоконная и надоконная части (коллайдеры на sb!)
	var basis := Basis(Vector3.UP, wall_yaw)
	_add_box_part(sb, Vector3(side_w, wall_h, wall_t), base_center + basis * Vector3(-(win_w + side_w) * 0.5, wall_h * 0.5, 0.0), Vector3(0.0, rad_to_deg(wall_yaw), 0.0), mat_wall)
	_add_box_part(sb, Vector3(side_w, wall_h, wall_t), base_center + basis * Vector3((win_w + side_w) * 0.5, wall_h * 0.5, 0.0), Vector3(0.0, rad_to_deg(wall_yaw), 0.0), mat_wall)
	_add_box_part(sb, Vector3(win_w, sill_h, wall_t), base_center + basis * Vector3(0.0, sill_h * 0.5, 0.0), Vector3(0.0, rad_to_deg(wall_yaw), 0.0), mat_wall)
	_add_box_part(sb, Vector3(win_w, wall_h - head_y, wall_t), base_center + basis * Vector3(0.0, head_y + (wall_h - head_y) * 0.5, 0.0), Vector3(0.0, rad_to_deg(wall_yaw), 0.0), mat_wall)

	_build_window_trim_and_shutters(sb, base_center + Vector3(0.0, (sill_h + head_y) * 0.5, 0.0), outward_yaw, win_w, head_y - sill_h, mat_trim, mat_shutter)


static func _build_window_trim_and_shutters(
	sb: StaticBody3D,
	win_center: Vector3,
	out_yaw: float,
	win_w: float,
	win_h: float,
	mat_trim: Material,
	mat_shutter: Material
) -> void:
	var b := Basis(Vector3.UP, out_yaw)
	var deg_y := rad_to_deg(out_yaw)
	# Наличники и подоконник
	_add_box_part(sb, Vector3(win_w + 0.28, 0.11, 0.30), win_center + b * Vector3(0.0, win_h * 0.5 + 0.05, 0.0), Vector3(0.0, deg_y, 0.0), mat_trim, false)
	_add_box_part(sb, Vector3(win_w + 0.26, 0.08, 0.32), win_center + b * Vector3(0.0, -win_h * 0.5 - 0.03, 0.02), Vector3(0.0, deg_y, 0.0), mat_trim, false)
	# Деревянный переплёт рамы (без коллайдера, чтобы можно было метнуть предмет в окно!)
	_add_box_part(sb, Vector3(0.05, win_h, 0.06), win_center, Vector3(0.0, deg_y, 0.0), mat_trim, false)
	_add_box_part(sb, Vector3(win_w, 0.05, 0.06), win_center + Vector3(0.0, 0.12, 0.0), Vector3(0.0, deg_y, 0.0), mat_trim, false)
	# Распахнутые деревянные ставни снаружи стены
	var sh_w := win_w * 0.46
	_add_box_part(sb, Vector3(sh_w, win_h + 0.04, 0.04), win_center + b * Vector3(-(win_w * 0.5 + sh_w * 0.48), 0.0, 0.14), Vector3(0.0, deg_y + 18.0, 0.0), mat_shutter, false)
	_add_box_part(sb, Vector3(sh_w, win_h + 0.04, 0.04), win_center + b * Vector3((win_w * 0.5 + sh_w * 0.48), 0.0, 0.14), Vector3(0.0, deg_y - 18.0, 0.0), mat_shutter, false)


static func _add_gable_prism(parent: Node3D, base_edge_center: Vector3, depth_z: float, height_y: float, normal_sign_x: float, mat: Material) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p_left := Vector3(0.0, 0.0, -depth_z * 0.5)
	var p_right := Vector3(0.0, 0.0, depth_z * 0.5)
	var p_top := Vector3(0.0, height_y, 0.0)
	var n := Vector3(normal_sign_x, 0.0, 0.0)

	st.set_normal(n)
	if normal_sign_x > 0.0:
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p_right)
		st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(p_top)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p_left)
	else:
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p_left)
		st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(p_top)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p_right)

	st.generate_tangents()
	var m := ArrayMesh.new()
	st.commit(m)
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = base_edge_center
	parent.add_child(mi)


# ============================================================================
# 2. ДВОРЫ, ЗАБОРЫ С КАЛИТКАМИ И ПРОЛАЗАМИ, САРАИ, ПОЛЕННИЦЫ И ЛАВОЧКИ
# ============================================================================

static func _build_homestead_yard(
	parent: Node3D,
	house_pos: Vector3,
	yaw: float,
	style: String,
	rng: RandomNumberGenerator
) -> void:
	var yard := Node3D.new()
	yard.name = "HomesteadYard"
	yard.position = house_pos
	yard.rotation.y = yaw
	parent.add_child(yard)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	yard.add_child(sb)

	var mat_picket := AssetCatalog.get_pbr_material(
		"blue_painted_planks" if style in ["blue_wood", "white_plaster"] else "brown_planks_03",
		Vector3(0.5, 0.5, 0.5),
		true,
		Color(0.88, 0.84, 0.78)
	)
	var mat_wood := AssetCatalog.get_pbr_material("brown_planks_03", Vector3(0.4, 0.4, 0.4), true, Color(0.75, 0.62, 0.48))
	var mat_slate := AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.42, 0.42, 0.42), true, Color(0.66, 0.68, 0.68), 1.15, 0.08)
	var mat_bark := AssetCatalog.get_pbr_material("knotted_pine_bark", Vector3(0.5, 0.5, 0.5), true)

	# 1. Хозяйственный дощатый сарай / дровяник в глубине участка (открыт — можно прятаться внутри!)
	var sx := -1.5
	var sz := -7.2
	_add_box_part(sb, Vector3(4.2, 2.35, 0.16), Vector3(sx, 1.175, sz - 1.75), Vector3.ZERO, mat_wood)
	_add_box_part(sb, Vector3(0.16, 2.35, 3.5), Vector3(sx - 2.02, 1.175, sz), Vector3.ZERO, mat_wood)
	_add_box_part(sb, Vector3(0.16, 2.35, 3.5), Vector3(sx + 2.02, 1.175, sz), Vector3.ZERO, mat_wood)
	# Фронт сарая с широким открытым входом
	_add_box_part(sb, Vector3(1.3, 2.35, 0.16), Vector3(sx - 1.45, 1.175, sz + 1.75), Vector3.ZERO, mat_wood)
	_add_box_part(sb, Vector3(1.3, 2.35, 0.16), Vector3(sx + 1.45, 1.175, sz + 1.75), Vector3.ZERO, mat_wood)
	# Односкатная шиферная крыша сарая
	_add_box_part(sb, Vector3(4.65, 0.10, 4.15), Vector3(sx, 2.45, sz), Vector3(-7.5, 0.0, 0.0), mat_slate)

	# 2. Поленница колотых дров у стены дома + железная бочка для дождевой воды + приставная лестница
	for row in range(4):
		for col_i in range(6):
			_add_box_part(
				sb,
				Vector3(0.22, 0.18, 0.58),
				Vector3(4.68, 0.12 + float(row) * 0.19, -1.8 + float(col_i) * 0.24),
				Vector3.ZERO,
				mat_bark,
				row == 0 and col_i == 0
			)
	_add_box_part(sb, Vector3(0.55, 0.85, 1.55), Vector3(4.68, 0.42, -1.2), Vector3.ZERO, mat_bark) # Общий коллайдер поленницы

	var rain_barrel := AssetCatalog.instantiate_model("res://assets/downloaded/models/barrel_03/model.gltf")
	if rain_barrel != null:
		rain_barrel.position = Vector3(4.75, 0.0, 3.65)
		yard.add_child(rain_barrel)

	var ladder := AssetCatalog.instantiate_model("res://assets/downloaded/models/wooden_ladder/model.gltf")
	if ladder != null:
		ladder.scale = Vector3(1.35, 1.95, 1.35)
		ladder.position = Vector3(-4.65, 0.0, -1.8)
		ladder.rotation_degrees = Vector3(0.0, 90.0, -14.0)
		yard.add_child(ladder)

	# 3. Палисадник и штакетник вдоль фасада (+Z = +8.8 м) с открытой калиткой и деревенской лавочкой снаружи!
	var fz := 8.8
	_build_fence_span(sb, Vector3(-9.2, 0.0, fz), Vector3(-0.6, 0.0, fz), 1.32, mat_picket)
	_build_fence_span(sb, Vector3(2.8, 0.0, fz), Vector3(9.2, 0.0, fz), 1.32, mat_picket)
	# Приоткрытая калитка
	_add_box_part(sb, Vector3(1.35, 1.25, 0.08), Vector3(0.15, 0.65, fz - 0.55), Vector3(0.0, -38.0, 0.0), mat_picket)

	# Лавочка у калитки и садовый стол во дворе (фотосканы Poly Haven!)
	var bench_out := AssetCatalog.instantiate_model("res://assets/downloaded/models/painted_wooden_bench/model.gltf")
	if bench_out != null:
		bench_out.position = Vector3(-3.2, 0.0, fz + 0.65)
		yard.add_child(bench_out)

	if rng.randf() < 0.65:
		var ptable := AssetCatalog.instantiate_model("res://assets/downloaded/models/wooden_picnic_table/model.gltf")
		if ptable != null:
			ptable.scale = Vector3(0.88, 0.88, 0.88)
			ptable.position = Vector3(5.6, 0.0, 3.2)
			ptable.rotation_degrees.y = 24.0
			yard.add_child(ptable)

	# 4. Боковые и задний заборы (с лазом/проломом в глубине огорода для скрытных перебежек между участками!)
	_build_fence_span(sb, Vector3(-9.2, 0.0, fz), Vector3(-9.2, 0.0, -2.5), 1.58, mat_wood)
	_build_fence_span(sb, Vector3(-9.2, 0.0, -5.2), Vector3(-9.2, 0.0, -10.2), 1.58, mat_slate) # Лаз 2.7 м между -2.5 и -5.2!
	_build_fence_span(sb, Vector3(9.2, 0.0, fz), Vector3(9.2, 0.0, -1.5), 1.58, mat_wood)
	_build_fence_span(sb, Vector3(9.2, 0.0, -4.4), Vector3(9.2, 0.0, -10.2), 1.65, mat_slate)
	_build_fence_span(sb, Vector3(-9.2, 0.0, -10.2), Vector3(1.5, 0.0, -10.2), 1.65, mat_slate)
	_build_fence_span(sb, Vector3(4.2, 0.0, -10.2), Vector3(9.2, 0.0, -10.2), 1.65, mat_wood)


static func _build_fence_span(sb: StaticBody3D, p_from: Vector3, p_to: Vector3, height: float, mat: Material) -> void:
	var delta := p_to - p_from
	var length := Vector2(delta.x, delta.z).length()
	if length < 0.3:
		return
	var mid := (p_from + p_to) * 0.5
	var yaw_deg := rad_to_deg(atan2(delta.x, delta.z))
	# Опускаем основание забора на 0.45 м ниже отметки участка, чтобы при перепаде высот под забором не было щели
	_add_box_part(sb, Vector3(0.11, height + 0.45, length), Vector3(mid.x, (height - 0.45) * 0.5, mid.z), Vector3(0.0, yaw_deg, 0.0), mat)

	# Столбики забора каждые 2.4 м
	var posts := maxi(1, int(round(length / 2.4)))
	var dir := delta / length
	for i in range(posts + 1):
		var pt := p_from + dir * (float(i) / float(posts) * length)
		_add_box_part(sb, Vector3(0.17, height + 0.55, 0.17), Vector3(pt.x, (height - 0.35) * 0.5, pt.z), Vector3.ZERO, mat, false)


# ============================================================================
# 3. КОЛОДЕЦ, ПОЛЯНА У КОСТРА, СТОЛБЫ ЛЭП С ПРОВОДАМИ И УЛИЧНЫМИ ФОНАРЯМИ
# ============================================================================

static func _build_village_well(parent: Node3D, pos: Vector3) -> void:
	var well := Node3D.new()
	well.name = "VillageWell"
	well.position = pos
	parent.add_child(well)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	well.add_child(sb)

	var mat_log := AssetCatalog.get_pbr_material("knotted_pine_bark", Vector3(0.5, 0.5, 0.5), true, Color(0.76, 0.62, 0.46))
	var mat_roof := AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.5, 0.5, 0.5), true, Color(0.68, 0.70, 0.70))
	var mat_stone := AssetCatalog.get_pbr_material("gravel_concrete_02", Vector3(0.5, 0.5, 0.5), true)

	# Каменная отмостка и бревенчатый сруб колодца
	_add_box_part(sb, Vector3(2.8, 0.16, 2.8), Vector3(0.0, 0.04, 0.0), Vector3.ZERO, mat_stone)
	_add_box_part(sb, Vector3(1.38, 0.92, 1.38), Vector3(0.0, 0.46, 0.0), Vector3.ZERO, mat_log)
	# Две стойки, ворот и двускатный домик над колодцем
	_add_box_part(sb, Vector3(0.13, 1.45, 0.13), Vector3(-0.62, 1.55, 0.0), Vector3.ZERO, mat_log)
	_add_box_part(sb, Vector3(0.13, 1.45, 0.13), Vector3(0.62, 1.55, 0.0), Vector3.ZERO, mat_log)
	_add_box_part(sb, Vector3(1.40, 0.14, 0.14), Vector3(0.0, 1.75, 0.0), Vector3.ZERO, mat_log, false)
	_add_box_part(sb, Vector3(1.85, 0.08, 1.15), Vector3(0.0, 2.42, 0.42), Vector3(32.0, 0.0, 0.0), mat_roof, false)
	_add_box_part(sb, Vector3(1.85, 0.08, 1.15), Vector3(0.0, 2.42, -0.42), Vector3(-32.0, 0.0, 0.0), mat_roof, false)

	var bucket := AssetCatalog.instantiate_model("res://assets/downloaded/models/wooden_bucket_01/model.gltf")
	if bucket != null:
		bucket.position = Vector3(0.45, 0.92, 0.35)
		well.add_child(bucket)


static func _build_campfire_glade_seating(parent: Node3D, center: Vector3) -> void:
	var glade := Node3D.new()
	glade.name = "CampfireGladeProps"
	glade.position = center
	parent.add_child(glade)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	glade.add_child(sb)

	var mat_bark := AssetCatalog.get_pbr_material("knotted_pine_bark", Vector3(0.45, 0.45, 0.45), true)

	# Брёвна для посиделок вокруг вечернего костра
	for i in range(4):
		var ang := float(i) * (TAU / 4.0) + 0.38
		if i == 2:
			continue # Оставляем проход со стороны тропинки
		var lp := Vector3(cos(ang) * 3.1, 0.24, sin(ang) * 3.1)
		_add_box_part(sb, Vector3(2.3, 0.44, 0.46), lp, Vector3(0.0, rad_to_deg(-ang), 0.0), mat_bark)

	var ptable := AssetCatalog.instantiate_model("res://assets/downloaded/models/wooden_picnic_table/model.gltf")
	if ptable != null:
		ptable.position = Vector3(-4.2, 0.0, -3.6)
		ptable.rotation_degrees.y = 32.0
		glade.add_child(ptable)
		_add_box_part(sb, Vector3(2.2, 0.76, 2.9), Vector3(-4.2, 0.38, -3.6), Vector3(0.0, 32.0, 0.0), mat_bark, false)


static func _build_forest_boulder_glade(parent: Node3D, center: Vector3, rng: RandomNumberGenerator) -> void:
	var glade := Node3D.new()
	glade.name = "ForestBoulderGlade"
	glade.position = center
	parent.add_child(glade)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	glade.add_child(sb)

	for i in range(6):
		var ang := float(i) * (TAU / 6.0) + rng.randf_range(-0.3, 0.3)
		var rad := rng.randf_range(3.8, 6.4)
		var bp := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var sc := rng.randf_range(1.4, 2.3)
		var rock := AssetCatalog.instantiate_model("res://assets/downloaded/models/boulder_01/model.gltf")
		if rock != null:
			rock.scale = Vector3(sc, sc * 0.9, sc)
			rock.position = bp
			rock.rotation.y = rng.randf() * TAU
			glade.add_child(rock)
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.72 * sc
		col.shape = sph
		col.position = bp + Vector3(0.0, 0.55 * sc, 0.0)
		sb.add_child(col)


static func _build_power_line_and_streetlamps(parent: Node3D) -> void:
	var net := Node3D.new()
	net.name = "RuralPowerLine"
	parent.add_child(net)

	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	net.add_child(sb)

	var mat_pole := AssetCatalog.get_pbr_material("knotted_pine_bark", Vector3(0.6, 0.3, 0.6), true, Color(0.66, 0.58, 0.48))
	var mat_metal := AssetCatalog.get_pbr_material("metal_plate", Vector3(0.6, 0.6, 0.6), true, Color(0.32, 0.34, 0.36))

	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.08, 0.08, 0.09)
	wire_mat.roughness = 0.75

	var pole_tops_left: Array[Vector3] = []
	var pole_tops_right: Array[Vector3] = []

	var z_list := [-76.0, -56.0, -36.0, -16.0, 4.0, 24.0, 44.0, 64.0, 80.0]
	for idx in range(z_list.size()):
		var pz: float = float(z_list[idx])
		var px := TerrainBuilder.get_road_center_x(pz) + 4.85
		var py := TerrainBuilder.get_height(px, pz)
		var pole_h := 6.8

		# Деревянный столб ЛЭП + металлическая траверса наверху
		var cyl_col := CollisionShape3D.new()
		var cshape := CylinderShape3D.new()
		cshape.radius = 0.16
		cshape.height = pole_h
		cyl_col.shape = cshape
		cyl_col.position = Vector3(px, py + pole_h * 0.5 - 0.2, pz)
		sb.add_child(cyl_col)

		if DisplayServer.get_name() != "headless":
			var pmi := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.11
			pm.bottom_radius = 0.16
			pm.height = pole_h + 0.4
			pm.radial_segments = 10
			pm.material = mat_pole
			pmi.mesh = pm
			pmi.position = Vector3(px, py + pole_h * 0.5 - 0.2, pz)
			net.add_child(pmi)

			var cross := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(1.35, 0.09, 0.09)
			cm.material = mat_metal
			cross.mesh = cm
			cross.position = Vector3(px, py + pole_h - 0.35, pz)
			net.add_child(cross)

			pole_tops_left.append(Vector3(px - 0.58, py + pole_h - 0.30, pz))
			pole_tops_right.append(Vector3(px + 0.58, py + pole_h - 0.30, pz))

			# На каждом втором столбе — фотосканированный уличный фонарь с мягким светом на просёлочную дорогу
			if idx % 2 == 1:
				var slamp := AssetCatalog.instantiate_model("res://assets/downloaded/models/street_lamp_01/model.gltf")
				if slamp != null:
					slamp.position = Vector3(px - 0.55, py, pz + 0.35)
					slamp.rotation_degrees.y = -90.0
					net.add_child(slamp)
				var rlight := OmniLight3D.new()
				rlight.light_color = Color(1.0, 0.78, 0.46)
				rlight.light_energy = 2.0
				rlight.omni_range = 15.5
				rlight.omni_attenuation = 1.25
				rlight.position = Vector3(px - 1.15, py + 3.75, pz + 0.35)
				net.add_child(rlight)

	# Провисающие электрические провода между столбами (параболический провис)
	if DisplayServer.get_name() != "headless" and pole_tops_left.size() >= 2:
		var st_wires := SurfaceTool.new()
		st_wires.begin(Mesh.PRIMITIVE_TRIANGLES)
		for arr in [pole_tops_left, pole_tops_right]:
			for i in range(arr.size() - 1):
				_append_sagging_wire(st_wires, arr[i], arr[i + 1], 0.48)
		st_wires.generate_normals()
		var wmesh := ArrayMesh.new()
		st_wires.commit(wmesh)
		wmesh.surface_set_material(0, wire_mat)
		var wmi := MeshInstance3D.new()
		wmi.name = "PowerWires"
		wmi.mesh = wmesh
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		net.add_child(wmi)


static func _append_sagging_wire(st: SurfaceTool, a: Vector3, b: Vector3, sag: float) -> void:
	var segs := 8
	var r := 0.018
	for s in range(segs):
		var t0 := float(s) / float(segs)
		var t1 := float(s + 1) / float(segs)
		var p0 := a.lerp(b, t0) - Vector3(0.0, sin(t0 * PI) * sag, 0.0)
		var p1 := a.lerp(b, t1) - Vector3(0.0, sin(t1 * PI) * sag, 0.0)
		# Две скрещенные ленты провода (хорошо читаются на фоне предзакатного неба!)
		for off in [Vector3(r, 0.0, 0.0), Vector3(0.0, r, 0.0)]:
			st.add_vertex(p0 - off); st.add_vertex(p1 - off); st.add_vertex(p1 + off)
			st.add_vertex(p0 - off); st.add_vertex(p1 + off); st.add_vertex(p0 + off)


# ============================================================================
# 4. ГЕРМЕТИЧНЫЙ ВНЕШНИЙ ПЕРИМЕТР 180×180 м (ЗАБОРЫ + НЕПРОЛАЗНЫЕ ЗАРОСЛИ, 0 ОБРЫВОВ)
# ============================================================================

static func _build_airtight_outer_perimeter(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var perim := Node3D.new()
	perim.name = "AirtightPerimeter180x180"
	parent.add_child(perim)

	var sb := StaticBody3D.new()
	sb.name = "PerimeterStaticBlockers"
	sb.collision_layer = 1
	sb.collision_mask = 0
	perim.add_child(sb)

	var lim := TerrainBuilder.PLAYABLE_LIMIT # 87.0 м -> квадрат 174×174 м внутри непрерывной земли 232×232 м!
	var span := lim * 2.0 + 6.0              # 180.0 м с угловым перехлёстом 3 м на каждом стыке!

	# 4 монолитных физических блокиратора высотой 26 м (от y=-4 до y=+22 м) по всем 4 сторонам карты — 0 щелей!
	for b_spec in [
		[Vector3(span, 26.0, 2.4), Vector3(0.0, 9.0, -lim - 1.1)], # Север (z = -87)
		[Vector3(span, 26.0, 2.4), Vector3(0.0, 9.0, lim + 1.1)],  # Юг (z = +87)
		[Vector3(2.4, 26.0, span), Vector3(-lim - 1.1, 9.0, 0.0)], # Запад (x = -87)
		[Vector3(2.4, 26.0, span), Vector3(lim + 1.1, 9.0, 0.0)],  # Восток (x = +87)
	]:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b_spec[0]
		col.shape = box
		col.position = b_spec[1]
		sb.add_child(col)

	if DisplayServer.get_name() == "headless":
		return

	# Визуальное оформление границ без единого «невидимого стекла»:
	# Со стороны посёлка — высокие глухие деревянно-шиферные заборы крайних усадеб + кустарник;
	# На выездах просёлочной дороги (Север и Юг) — поваленные бурей стволы и шлагбаум лесничества;
	# Со стороны леса — многослойная стена густых кустов, валунов и валежника!
	var mat_fence_wood := AssetCatalog.get_pbr_material("brown_planks_03", Vector3(0.4, 0.4, 0.4), true, Color(0.68, 0.56, 0.44))
	var mat_fence_slate := AssetCatalog.get_pbr_material("corrugated_iron", Vector3(0.4, 0.4, 0.4), true, Color(0.62, 0.65, 0.64), 1.15, 0.08)
	var mat_barrier := AssetCatalog.get_pbr_material("blue_painted_planks", Vector3(0.5, 0.5, 0.5), true, Color(0.95, 0.45, 0.35))

	var shrub_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/shrub_02/model.gltf")
	var boulder_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/boulder_01/model.gltf")
	var log_meshes := AssetCatalog.get_model_submeshes("res://assets/downloaded/models/dead_tree_trunk/model.gltf")

	var perim_shrub_xf: Array[Transform3D] = []
	var perim_rock_xf: Array[Transform3D] = []
	var perim_log_xf: Array[Transform3D] = []

	# Проходим по всем 4 сторонам с шагом 2.2 м
	for edge in range(4):
		var steps := int(round((lim * 2.0) / 2.2))
		for i in range(steps + 1):
			var along := -lim + (float(i) / float(steps)) * (lim * 2.0)
			var wx := 0.0
			var wz := 0.0
			var is_ns := (edge < 2)
			match edge:
				0: wx = along; wz = -lim
				1: wx = along; wz = lim
				2: wx = -lim;  wz = along
				_: wx = lim;   wz = along

			var wy := TerrainBuilder.get_height(wx, wz)
			var rd := TerrainBuilder.get_road_distance(wx, wz)
			var ff := TerrainBuilder.get_forest_factor(wx, wz)

			if rd < 4.5:
				# Перекрытый лесной шлагбаум и поваленный бурей ствол на выезде просёлочной грунтовки
				if absf(rd) < 1.2:
					_add_box_part(sb, Vector3(8.2, 0.22, 0.22), Vector3(wx, wy + 1.05, wz), Vector3.ZERO, mat_barrier, false)
					_add_box_part(sb, Vector3(0.24, 1.35, 0.24), Vector3(wx - 3.8, wy + 0.65, wz), Vector3.ZERO, mat_fence_wood, false)
					_add_box_part(sb, Vector3(0.24, 1.35, 0.24), Vector3(wx + 3.8, wy + 0.65, wz), Vector3.ZERO, mat_fence_wood, false)
					perim_log_xf.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)).scaled(Vector3(2.4, 2.2, 2.2)), Vector3(wx, wy + 0.05, wz + (0.6 if wz > 0 else -0.6))))
				continue

			# На западной стороне и у крайних участков деревни ставим глухой 2.35-метровый забор + заросли
			if wx < -8.0 and ff < 0.72 and (i % 2 == 0):
				var fmat := mat_fence_wood if ((i / 2) % 2 == 0) else mat_fence_slate
				var f_sz := Vector3(4.55, 2.55, 0.14) if is_ns else Vector3(0.14, 2.55, 4.55)
				_add_box_part(sb, f_sz, Vector3(wx, wy + 1.05, wz), Vector3.ZERO, fmat, false)

			# По всему периметру (включая стыки заборов и всю лесную дугу) — плотный двойной вал кустарников, валунов и бурелома!
			var sc1 := rng.randf_range(1.35, 1.95)
			perim_shrub_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc1, sc1 * 1.2, sc1)), Vector3(wx, wy - 0.05, wz)))

			var out_dir := Vector2(wx, wz).normalized()
			var sc2 := rng.randf_range(1.65, 2.35)
			perim_shrub_xf.append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc2, sc2 * 1.35, sc2)),
				Vector3(wx + out_dir.x * 1.65, wy - 0.05, wz + out_dir.y * 1.65)
			))

			if i % 3 == 0:
				var rsc := rng.randf_range(1.3, 2.2)
				perim_rock_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rsc, rsc, rsc)), Vector3(wx + out_dir.x * 0.45, wy - 0.08, wz + out_dir.y * 0.45)))
			if i % 4 == 0 and ff > 0.35:
				var lsc := rng.randf_range(1.5, 2.2)
				var tang_yaw := (0.0 if is_ns else PI * 0.5) + rng.randf_range(-0.25, 0.25)
				perim_log_xf.append(Transform3D(Basis(Vector3.UP, tang_yaw).scaled(Vector3(lsc, lsc * 1.4, lsc * 1.4)), Vector3(wx - out_dir.x * 0.35, wy + 0.05, wz - out_dir.y * 0.35)))

	if not shrub_meshes.is_empty() and not perim_shrub_xf.is_empty():
		RealisticFoliage._add_multimesh_batch(perim, "PerimeterThicketShrubs", shrub_meshes[0], perim_shrub_xf, 165.0, true)
	if not boulder_meshes.is_empty() and not perim_rock_xf.is_empty():
		RealisticFoliage._add_multimesh_batch(perim, "PerimeterBoulders", boulder_meshes[0], perim_rock_xf, 150.0, true)
	if not log_meshes.is_empty() and not perim_log_xf.is_empty():
		RealisticFoliage._add_multimesh_batch(perim, "PerimeterWindfallLogs", log_meshes[0], perim_log_xf, 140.0, true)


# ============================================================================
# ВСПОМОГАТЕЛЬНЫЙ КОНСТРУКТОР ФИЗИЧЕСКИХ + ВИЗУАЛЬНЫХ ДЕТАЛЕЙ
# ============================================================================

static func _add_box_part(
	sb: StaticBody3D,
	size: Vector3,
	local_pos: Vector3,
	rot_deg: Vector3,
	mat: Material,
	with_collider: bool = true
) -> void:
	if with_collider:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = local_pos
		col.rotation_degrees = rot_deg
		sb.add_child(col)

	if DisplayServer.get_name() != "headless":
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = mat
		mi.mesh = bm
		mi.position = local_pos
		mi.rotation_degrees = rot_deg
		sb.add_child(mi)
