extends Node
## Единый каталог ресурсов, 4K PBR-материалов, фотосканов оружия и объектов песочницы.
## Чтобы добавить новое оружие или объект в будущем — достаточно добавить запись в WEAPON_DEFS / SANDBOX_ITEMS.

const WEAPON_DEFS: Dictionary = {
	"sword_1h": {
		"title": "Старая шашка",
		"grip": "1h",
		"damage": 26.0,
		"heavy_damage": 44.0,
		"throw_damage": 54.0,
		"range": 2.45,
		"knockback": 7.5,
		"cooldown": 0.41,
		"stamina_cost": 12.0,
		"hit_sfx": "hit_blade",
		"model_path": "res://assets/downloaded/models/wooden_handle_saber/model.gltf",
		"model_scale": Vector3(1.24, 1.24, 1.24),
		"grip_offset": Vector3(0.0, 0.04, 0.0),
		"grip_rot_deg": Vector3(0.0, 180.0, 0.0),
		"accent_color": Color(0.80, 0.86, 0.94),
	},
	"axe_1h": {
		"title": "Деревенский топор-колун",
		"grip": "1h",
		"damage": 30.0,
		"heavy_damage": 49.0,
		"throw_damage": 68.0,
		"range": 2.32,
		"knockback": 10.0,
		"cooldown": 0.45,
		"stamina_cost": 13.0,
		"hit_sfx": "hit_blade",
		"model_path": "res://assets/downloaded/models/wooden_axe_02/model.gltf",
		"model_scale": Vector3(1.48, 1.48, 1.48),
		"grip_offset": Vector3(0.0, 0.24, 0.0),
		"grip_rot_deg": Vector3(0.0, 180.0, 0.0),
		"accent_color": Color(0.88, 0.46, 0.34),
	},
	"mace_1h": {
		"title": "Кованая булава",
		"grip": "1h",
		"damage": 31.0,
		"heavy_damage": 50.0,
		"throw_damage": 58.0,
		"range": 2.25,
		"knockback": 11.5,
		"cooldown": 0.50,
		"stamina_cost": 15.0,
		"hit_sfx": "hit_blunt",
		"model_path": "res://assets/downloaded/models/ornate_medieval_mace/model.gltf",
		"model_scale": Vector3(1.85, 1.85, 1.85),
		"grip_offset": Vector3(0.0, 0.12, 0.0),
		"grip_rot_deg": Vector3(0.0, 0.0, 0.0),
		"accent_color": Color(0.88, 0.72, 0.36),
	},
	"club_1h": {
		"title": "Суковатая дубина",
		"grip": "1h",
		"damage": 28.0,
		"heavy_damage": 46.0,
		"throw_damage": 48.0,
		"range": 2.35,
		"knockback": 13.5,
		"cooldown": 0.48,
		"stamina_cost": 14.0,
		"hit_sfx": "hit_blunt",
		"model_path": "res://assets/downloaded/weapons/Club.glb",
		"model_scale": Vector3(0.44, 0.44, 0.44),
		"grip_offset": Vector3(0.0, 0.0, 0.0),
		"grip_rot_deg": Vector3(0.0, 0.0, 0.0),
		"accent_color": Color(0.68, 0.46, 0.26),
	},
	"claymore_2h": {
		"title": "Двуручный меч",
		"grip": "2h",
		"damage": 40.0,
		"heavy_damage": 64.0,
		"throw_damage": 66.0,
		"range": 3.05,
		"knockback": 12.5,
		"cooldown": 0.64,
		"stamina_cost": 20.0,
		"hit_sfx": "hit_blade",
		"model_path": "res://assets/downloaded/weapons/Claymore.glb",
		"model_scale": Vector3(0.29, 0.29, 0.29),
		"grip_offset": Vector3(0.0, -0.05, 0.0),
		"grip_rot_deg": Vector3(0.0, 0.0, 0.0),
		"accent_color": Color(0.62, 0.82, 1.0),
	},
	"warhammer_2h": {
		"title": "Тяжёлый молот-кувалда",
		"grip": "2h",
		"damage": 46.0,
		"heavy_damage": 72.0,
		"throw_damage": 74.0,
		"range": 2.85,
		"knockback": 17.0,
		"cooldown": 0.70,
		"stamina_cost": 22.0,
		"hit_sfx": "hit_blunt",
		"model_path": "res://assets/downloaded/models/ornate_war_hammer/model.gltf",
		"model_scale": Vector3(2.15, 2.15, 2.15),
		"grip_offset": Vector3(0.0, 0.22, 0.0),
		"grip_rot_deg": Vector3(0.0, 90.0, 0.0),
		"accent_color": Color(0.96, 0.64, 0.24),
	},
}

const CHARACTER_PATHS: Dictionary = {
	"knight": "res://assets/downloaded/characters/Knight.glb",
	"barbarian": "res://assets/downloaded/characters/Barbarian.glb",
	"rogue": "res://assets/downloaded/characters/Rogue_Hooded.glb",
}

## Каталог объектов для спавна в режиме Песочницы (клавиша Q)
const SANDBOX_ITEMS: Array[Dictionary] = [
	{"id": "weapon:axe_1h", "category": "Оружие", "title": "Деревенский топор-колун", "desc": "Фотоскан: мощный удар и 68 урона броском"},
	{"id": "weapon:sword_1h", "category": "Оружие", "title": "Старая шашка", "desc": "Фотоскан: быстрые рубящие комбо и точный бросок"},
	{"id": "weapon:mace_1h", "category": "Оружие", "title": "Кованая булава", "desc": "Фотоскан: дробящий урон по блоку"},
	{"id": "weapon:club_1h", "category": "Оружие", "title": "Суковатая дубина", "desc": "Сильное отбрасывание врагов"},
	{"id": "weapon:claymore_2h", "category": "Оружие", "title": "Двуручный меч", "desc": "Широкие взмахи и вихревой удар на 360°"},
	{"id": "weapon:warhammer_2h", "category": "Оружие", "title": "Тяжёлый молот-кувалда", "desc": "Фотоскан: сокрушительный двуручный удар"},
	{"id": "prop:wooden_crate", "category": "Предметы", "title": "Дощатый ящик", "desc": "Можно схватить [E], швырнуть или разбить в щепки"},
	{"id": "prop:wine_barrel", "category": "Предметы", "title": "Деревянная бочка", "desc": "Отлично катится от пинка [F] и сбивает с ног"},
	{"id": "prop:explosive_barrel", "category": "Предметы", "title": "Бочка с горючим", "desc": "ВЗРЫВАЕТСЯ от удара или броска!"},
	{"id": "prop:jerrycan", "category": "Предметы", "title": "Канистра с бензином", "desc": "Лёгкая взрывоопасная канистра для дальнего броска!"},
	{"id": "prop:boulder", "category": "Предметы", "title": "Лесной валун", "desc": "Тяжёлый камень с огромным физическим импульсом"},
	{"id": "prop:treasure_chest", "category": "Предметы", "title": "Сундук с припасами", "desc": "При разрушении выпадает случайное оружие"},
	{"id": "prop:launchpad", "category": "Постройки", "title": "Пружинный трамплин", "desc": "Подбрасывает бойцов на крыши домов"},
	{"id": "prop:wood_ramp", "category": "Постройки", "title": "Дощатый настил-рампа", "desc": "Помост для запрыгивания через заборы и на чердаки"},
	{"id": "prop:thicket_hedge", "category": "Постройки", "title": "Густой кустарник", "desc": "Живая изгородь — засада и укрытие"},
	{"id": "prop:fire_pit", "category": "Постройки", "title": "Костровище", "desc": "Живой костёр с дымом и поджогом"},
	{"id": "prop:lantern_post", "category": "Постройки", "title": "Уличный фонарь", "desc": "Фотоскан уличного столба с тёплым светом"},
	{"id": "dummy:practice", "category": "Бойцы / NPC", "title": "Деревенское пугало-мишень", "desc": "Боевая мишень с HP для проверки ударов и бросков"},
]

var _material_cache: Dictionary = {}
var _scene_cache: Dictionary = {}
var _submesh_cache: Dictionary = {}


func get_pbr_material(
	tex_id: String,
	uv_scale: Vector3 = Vector3.ONE,
	triplanar: bool = true,
	tint: Color = Color.WHITE,
	roughness_mult: float = 1.0,
	metallic_override: float = -1.0
) -> StandardMaterial3D:
	var cache_key := "%s|%s|%s|%s|%.2f|%.2f" % [
		tex_id, str(uv_scale), str(triplanar), tint.to_html(), roughness_mult, metallic_override
	]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var base_dir := "res://assets/downloaded/textures/%s" % tex_id
	var diff_tex := _load_texture_safe("%s/diff.jpg" % base_dir)
	var nor_tex := _load_texture_safe("%s/nor_gl.jpg" % base_dir)
	var arm_tex := _load_texture_safe("%s/arm.jpg" % base_dir)

	if diff_tex != null:
		mat.albedo_texture = diff_tex
	if nor_tex != null:
		mat.normal_enabled = true
		mat.normal_texture = nor_tex
		mat.normal_scale = 1.15
	if arm_tex != null:
		mat.ao_enabled = true
		mat.ao_texture = arm_tex
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.ao_light_affect = 0.70

		mat.roughness = clampf(roughness_mult, 0.05, 1.0)
		mat.roughness_texture = arm_tex
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN

		if metallic_override >= 0.0:
			mat.metallic = metallic_override
		else:
			mat.metallic = 1.0
			mat.metallic_texture = arm_tex
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	else:
		mat.roughness = clampf(0.85 * roughness_mult, 0.1, 1.0)
		mat.metallic = maxf(metallic_override, 0.02)

	if triplanar:
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 4.5
		mat.uv1_scale = uv_scale
	else:
		mat.uv1_scale = uv_scale

	_material_cache[cache_key] = mat
	return mat


## Извлекает отдельные локальные Mesh-варианты из составных glTF-наборов растений Poly Haven
## (например, grass_medium_01 содержит 17 отдельных кустиков травы, shrub_02 — 4 разных куста).
func get_model_submeshes(res_path: String) -> Array[Mesh]:
	if _submesh_cache.has(res_path):
		return _submesh_cache[res_path]

	var out: Array[Mesh] = []
	var inst := instantiate_model(res_path)
	if inst != null:
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur is MeshInstance3D:
				var mi := cur as MeshInstance3D
				if mi.mesh != null:
					out.append(mi.mesh)
			for ch in cur.get_children():
				stack.append(ch)
		inst.free()

	_submesh_cache[res_path] = out
	return out


## Инстанцирует только один вариант куста/растения из составного glTF (без соседних вариантов по оси X).
func instantiate_single_variant(res_path: String, variant_idx: int = 0) -> MeshInstance3D:
	var meshes := get_model_submeshes(res_path)
	if meshes.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = meshes[posmod(variant_idx, meshes.size())]
	return mi


func instantiate_model(res_path: String) -> Node3D:
	var packed := _load_scene_safe(res_path)
	if packed != null:
		var inst := packed.instantiate()
		if inst is Node3D:
			return inst as Node3D
	return null


func instantiate_weapon_visual(weapon_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponVisual_%s" % weapon_id
	if not WEAPON_DEFS.has(weapon_id):
		return root
	var def: Dictionary = WEAPON_DEFS[weapon_id]
	var model := instantiate_model(String(def["model_path"]))
	if model != null:
		model.scale = def["model_scale"]
		model.position = def["grip_offset"]
		model.rotation_degrees = def["grip_rot_deg"]
		root.add_child(model)
	else:
		var mesh_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.025
		cyl.height = 1.15 if String(def["grip"]) == "1h" else 1.65
		mesh_inst.mesh = cyl
		mesh_inst.position.y = cyl.height * 0.45
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def["accent_color"]
		mat.metallic = 0.85
		mat.roughness = 0.25
		mesh_inst.material_override = mat
		root.add_child(mesh_inst)
	return root


func instantiate_character_model(char_class: String) -> Node3D:
	var path: String = CHARACTER_PATHS.get(char_class, CHARACTER_PATHS["knight"])
	return instantiate_model(path)


func load_sky_hdri() -> Texture2D:
	return _load_texture_safe("res://assets/downloaded/hdri/sky.hdr")


func _load_texture_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res is Texture2D:
			return res as Texture2D
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


func _load_scene_safe(res_path: String) -> PackedScene:
	if _scene_cache.has(res_path):
		return _scene_cache[res_path]
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res is PackedScene:
			_scene_cache[res_path] = res
			return res as PackedScene
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(abs_path, state)
		if err == OK:
			var scene_node := doc.generate_scene(state)
			if scene_node != null:
				var ps := PackedScene.new()
				if ps.pack(scene_node) == OK:
					scene_node.free()
					_scene_cache[res_path] = ps
					return ps
				scene_node.free()
	return null
