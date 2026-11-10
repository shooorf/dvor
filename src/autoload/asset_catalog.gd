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
var _alpha_cutout_shader: Shader = null


func _get_alpha_cutout_shader() -> Shader:
	if _alpha_cutout_shader != null:
		return _alpha_cutout_shader
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_alpha : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float alpha_Threshold = 0.42;
uniform float backlight_strength = 0.40;

void vertex() {
	// Мягкое покачивание листвы кустарников и травы на ветру
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h_factor = clamp(VERTEX.y * 0.8, 0.0, 1.2);
	float sway = sin(TIME * 1.8 + wp.x * 0.5 + wp.z * 0.4) * 0.025 * h_factor;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.7;
}

void fragment() {
	float a = texture(tex_alpha, UV).r;
	vec3 alb = texture(tex_alb, UV).rgb;
	ALBEDO = alb;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = alpha_Threshold;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	NORMAL_MAP = texture(tex_nor, UV).rgb;
	NORMAL_MAP_DEPTH = 0.95;
	vec3 arm = texture(tex_arm, UV).rgb;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.60;
	ROUGHNESS = clamp(arm.g, 0.35, 0.95);
	METALLIC = arm.b * 0.1;
	BACKLIGHT = alb * backlight_strength;
}
"""
	_alpha_cutout_shader = sh
	return sh


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
## (с сохранением поворота узла glTF и сборкой пышных кустов из отдельных веток для shrub_*).
func get_model_submeshes(res_path: String) -> Array[Mesh]:
	if _submesh_cache.has(res_path):
		return _submesh_cache[res_path]

	var raw_meshes: Array[Mesh] = []
	var inst := instantiate_model(res_path)
	if inst != null:
		var queue: Array[Node] = [inst]
		while not queue.is_empty():
			var cur: Node = queue.pop_front()
			if cur is MeshInstance3D:
				var mi := cur as MeshInstance3D
				if mi.mesh != null:
					raw_meshes.append(_bake_submesh_basis_and_materials(mi))
			for ch in cur.get_children():
				queue.append(ch)
		inst.free()

	var out: Array[Mesh] = raw_meshes
	# В Poly Haven модели shrub_02 / shrub_03 / shrub_04 состоят из отдельных веточек;
	# собираем из них полноценный густой многоствольный куст в качестве основного меша!
	if ("/shrub_02/" in res_path or "/shrub_03/" in res_path or "/shrub_04/" in res_path) and not raw_meshes.is_empty():
		var cluster := _build_bush_cluster_mesh(raw_meshes, res_path)
		if cluster != null:
			out = [cluster]
			for rm in raw_meshes:
				out.append(rm)

	_submesh_cache[res_path] = out
	return out


func _bake_submesh_basis_and_materials(mi: MeshInstance3D) -> Mesh:
	var src_mesh := mi.mesh
	if src_mesh == null or src_mesh.get_surface_count() == 0:
		return src_mesh
	var basis_xform := Transform3D(mi.transform.basis, Vector3.ZERO)
	var is_identity := basis_xform.basis.is_equal_approx(Basis.IDENTITY)
	var has_override := mi.material_override != null
	if is_identity and not has_override:
		return src_mesh

	var dst := ArrayMesh.new()
	for s in range(src_mesh.get_surface_count()):
		var mat := mi.material_override if has_override else src_mesh.surface_get_material(s)
		if is_identity:
			var arr := src_mesh.surface_get_arrays(s)
			dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		else:
			var st := SurfaceTool.new()
			st.append_from(src_mesh, s, basis_xform)
			st.generate_tangents()
			st.commit(dst)
		if mat != null:
			dst.surface_set_material(dst.get_surface_count() - 1, mat)
	return dst


func _build_bush_cluster_mesh(stems: Array[Mesh], res_path: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	var mat: Material = null
	for sm in stems:
		if sm != null and sm.get_surface_count() > 0:
			mat = sm.surface_get_material(0)
			if mat != null:
				break

	var is_small_herb := ("/shrub_03/" in res_path or "/shrub_04/" in res_path)
	var stem_count := 9 if is_small_herb else 6
	var base_scale := 2.35 if "/shrub_03/" in res_path else (2.65 if "/shrub_04/" in res_path else 1.0)
	var spread_r := 0.22 if is_small_herb else 0.18

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(stem_count):
		var src: Mesh = stems[i % stems.size()]
		if src == null or src.get_surface_count() == 0:
			continue
		var yaw := float(i) * (TAU / float(stem_count)) + float(i % 2) * 0.28
		var tilt := deg_to_rad(10.0 + float(i % 3) * 6.0)
		var sc := base_scale * (0.88 + float(i % 3) * 0.11)
		var b := (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)).scaled(Vector3(sc, sc, sc))
		var offset := Vector3(cos(yaw) * spread_r, 0.0, sin(yaw) * spread_r)
		for s in range(src.get_surface_count()):
			st.append_from(src, s, Transform3D(b, offset))

	st.generate_tangents()
	var out_mesh := ArrayMesh.new()
	st.commit(out_mesh)
	if mat != null and out_mesh.get_surface_count() > 0:
		out_mesh.surface_set_material(0, mat)
	return out_mesh


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
	var loaded_ps: PackedScene = null
	if ResourceLoader.exists(res_path):
		var res := load(res_path)
		if res is PackedScene:
			loaded_ps = res as PackedScene
	if loaded_ps == null:
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
						loaded_ps = ps
					scene_node.free()
	if loaded_ps != null:
		loaded_ps = _upgrade_scene_alpha_materials(res_path, loaded_ps)
		_scene_cache[res_path] = loaded_ps
	return loaded_ps


func _upgrade_scene_alpha_materials(res_path: String, ps: PackedScene) -> PackedScene:
	var model_dir := res_path.get_base_dir()
	var alpha_path := "%s/textures/alpha.jpg" % model_dir
	if not FileAccess.file_exists(ProjectSettings.globalize_path(alpha_path)):
		alpha_path = "%s/textures/alpha.png" % model_dir
		if not FileAccess.file_exists(ProjectSettings.globalize_path(alpha_path)):
			return ps

	var inst := ps.instantiate()
	if inst == null:
		return ps

	var alpha_tex := _load_texture_safe(alpha_path)
	if alpha_tex == null:
		inst.free()
		return ps

	var model_id := model_dir.get_file()
	var diff_tex := _find_model_texture(model_dir, model_id, "diff")
	var nor_tex := _find_model_texture(model_dir, model_id, "nor_gl")
	var arm_tex := _find_model_texture(model_dir, model_id, "arm")

	var sm := ShaderMaterial.new()
	sm.shader = _get_alpha_cutout_shader()
	sm.set_shader_parameter("tex_alpha", alpha_tex)
	if diff_tex != null:
		sm.set_shader_parameter("tex_alb", diff_tex)
	if nor_tex != null:
		sm.set_shader_parameter("tex_nor", nor_tex)
	if arm_tex != null:
		sm.set_shader_parameter("tex_arm", arm_tex)

	var modified := false
	var queue: Array[Node] = [inst]
	while not queue.is_empty():
		var cur: Node = queue.pop_front()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var base_mat := mi.mesh.surface_get_material(0)
				if base_mat is BaseMaterial3D and (base_mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					if diff_tex == null and (base_mat as BaseMaterial3D).albedo_texture != null:
						sm.set_shader_parameter("tex_alb", (base_mat as BaseMaterial3D).albedo_texture)
					for s in range(mi.mesh.get_surface_count()):
						mi.mesh.surface_set_material(s, sm)
					modified = true
		for ch in cur.get_children():
			queue.append(ch)

	if modified:
		var new_ps := PackedScene.new()
		if new_ps.pack(inst) == OK:
			inst.free()
			return new_ps
	inst.free()
	return ps


func _find_model_texture(model_dir: String, model_id: String, map_suffix: String) -> Texture2D:
	for res_tag in ["4k", "2k", "1k"]:
		for ext in ["jpg", "png"]:
			var candidate := "%s/textures/%s_%s_%s.%s" % [model_dir, model_id, map_suffix, res_tag, ext]
			if FileAccess.file_exists(ProjectSettings.globalize_path(candidate)):
				return _load_texture_safe(candidate)
	return null
