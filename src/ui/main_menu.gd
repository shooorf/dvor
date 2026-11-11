extends Node3D
## Главное меню с живой 3D-диорамой августовской опушки (4K HDRI вечерней дороги,
## берёзы и сосны, фотосканированные кусты, лавочка и шейдерный костёр),
## выбором персонажа, настройкой графики RTX 4070 и запуском сетевой игры ENet UDP.

var _turntable: Node3D = null
var _preview_holder: Node3D = null
var _name_edit: LineEdit = null
var _class_opt: OptionButton = null
var _color_picker: ColorPickerButton = null
var _ip_edit: LineEdit = null
var _port_spin: SpinBox = null
var _status_lbl: Label = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_3d_backdrop()
	_build_menu_ui()
	_refresh_character_preview()

	NetworkManager.connection_failed_msg.connect(_on_net_error)
	NetworkManager.connection_status_msg.connect(_on_net_status)

	if not NetworkManager.disconnect_reason.is_empty():
		_on_net_error(NetworkManager.disconnect_reason)
		NetworkManager.disconnect_reason = ""


func _process(delta: float) -> void:
	if _turntable != null:
		_turntable.rotation.y += delta * 0.32


func _build_3d_backdrop() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var hdri := AssetCatalog.load_sky_hdri()
	if hdri != null:
		var sm := PanoramaSkyMaterial.new()
		sm.panorama = hdri
		sm.energy_multiplier = 0.85
		sky.sky_material = sm
	else:
		var psm := ProceduralSkyMaterial.new()
		psm.sky_top_color = Color(0.22, 0.42, 0.70)
		psm.sky_horizon_color = Color(0.62, 0.70, 0.76)
		sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.20, 0.32, 0.50)
	env.ambient_light_sky_contribution = 0.34
	env.ambient_light_energy = 0.62
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.79)
	sun.light_energy = 1.48
	sun.rotation_degrees = Vector3(-36.0, -45.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	GraphicsSettings.register_scene_lighting(env, sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.52, 4.15)
	cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	cam.fov = 56.0
	cam.current = true
	add_child(cam)

	_turntable = Node3D.new()
	_turntable.position = Vector3(0.0, 0.0, 0.0)
	add_child(_turntable)

	# Августовская луговая поляна
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(80.0, 0.4, 80.0)
	gm.material = AssetCatalog.get_pbr_material("leafy_grass", Vector3(0.24, 0.24, 0.24), true)
	ground.mesh = gm
	ground.position = Vector3(0.0, -0.52, -6.0)
	add_child(ground)

	# Фоновые деревья (берёза, дуб, клён, ель), 3D-ельник, деревянная лавочка и фотосканированный луг
	if DisplayServer.get_name() != "headless":
		var birch_mesh := RealisticFoliage._generate_tree_mesh(RealisticFoliage.TreeSpecies.BIRCH, 77)
		var bmi := MeshInstance3D.new()
		bmi.mesh = birch_mesh
		bmi.position = Vector3(-4.2, -0.32, -5.4)
		bmi.scale = Vector3(0.82, 0.82, 0.82)
		add_child(bmi)

		var maple_mesh := RealisticFoliage._generate_tree_mesh(RealisticFoliage.TreeSpecies.MAPLE, 514)
		var mmi := MeshInstance3D.new()
		mmi.mesh = maple_mesh
		mmi.position = Vector3(4.6, -0.32, -6.5)
		mmi.scale = Vector3(0.84, 0.84, 0.84)
		add_child(mmi)

		var oak_mesh := RealisticFoliage._generate_tree_mesh(RealisticFoliage.TreeSpecies.OAK, 412)
		var omi := MeshInstance3D.new()
		omi.mesh = oak_mesh
		omi.position = Vector3(1.6, -0.32, -10.4)
		omi.scale = Vector3(0.80, 0.80, 0.80)
		add_child(omi)

		var spruce_mesh := RealisticFoliage._generate_tree_mesh(RealisticFoliage.TreeSpecies.SPRUCE, 99)
		var smi := MeshInstance3D.new()
		smi.mesh = spruce_mesh
		smi.position = Vector3(-2.6, -0.32, -8.8)
		smi.scale = Vector3(0.78, 0.78, 0.78)
		add_child(smi)

	var fir_sap := AssetCatalog.instantiate_single_variant("res://assets/downloaded/models/fir_sapling/model.gltf", 0)
	if fir_sap != null:
		fir_sap.position = Vector3(-4.85, -0.32, -4.15)
		fir_sap.scale = Vector3(1.68, 1.68, 1.68)
		add_child(fir_sap)

	var bench := AssetCatalog.instantiate_model("res://assets/downloaded/models/painted_wooden_bench/model.gltf")
	if bench != null:
		bench.position = Vector3(-2.35, -0.32, -2.15)
		bench.rotation_degrees.y = 32.0
		add_child(bench)

	var shrub_l := AssetCatalog.instantiate_single_variant("res://assets/downloaded/models/periwinkle_plant/model.gltf", 0)
	if shrub_l != null:
		shrub_l.position = Vector3(-3.35, -0.34, -3.15)
		shrub_l.scale = Vector3(1.18, 1.18, 1.18)
		add_child(shrub_l)

	var shrub_r := AssetCatalog.instantiate_single_variant("res://assets/downloaded/models/shrub_01/model.gltf", 0)
	if shrub_r != null:
		shrub_r.position = Vector3(3.25, -0.34, -3.05)
		shrub_r.scale = Vector3(1.42, 1.42, 1.42)
		add_child(shrub_r)

	var nettle := AssetCatalog.instantiate_single_variant("res://assets/downloaded/models/nettle_plant/model.gltf", 0)
	if nettle != null:
		nettle.position = Vector3(-1.85, -0.32, -1.55)
		nettle.scale = Vector3(3.2, 3.2, 3.2)
		add_child(nettle)

	for dand_cfg in [
		[Vector3(-1.38, -0.32, -1.18), 2.35, 25.0],
		[Vector3(2.52, -0.32, -1.78), 2.15, 140.0],
	]:
		var dand := AssetCatalog.instantiate_single_variant("res://assets/downloaded/models/dandelion_01/model.gltf", 0)
		if dand != null:
			dand.position = dand_cfg[0]
			dand.scale = Vector3.ONE * float(dand_cfg[1])
			dand.rotation_degrees.y = float(dand_cfg[2])
			add_child(dand)

	for fescue_cfg in [
		[Vector3(-2.65, -0.32, -1.45), 3.40, 18.0],
		[Vector3(2.85, -0.32, -2.25), 3.60, 96.0],
		[Vector3(1.55, -0.32, -2.55), 3.15, 210.0],
	]:
		var fescue := AssetCatalog.instantiate_single_variant("res://assets/downloaded/models/grass_medium_01/model.gltf", 0)
		if fescue != null:
			fescue.position = fescue_cfg[0]
			fescue.scale = Vector3.ONE * float(fescue_cfg[1])
			fescue.rotation_degrees.y = float(fescue_cfg[2])
			add_child(fescue)

	for turf_cfg in [
		[Vector3(-1.60, -0.33, -2.35), 1.08, 42.0],
		[Vector3(2.15, -0.33, -1.55), 1.02, 165.0],
	]:
		var turf_p := AssetCatalog.instantiate_single_variant("res://assets/downloaded/models/grass_bermuda_01/model.gltf", 0)
		if turf_p != null:
			turf_p.position = turf_cfg[0]
			turf_p.scale = Vector3.ONE * float(turf_cfg[1])
			turf_p.rotation_degrees.y = float(turf_cfg[2])
			add_child(turf_p)

	# Утоптанный круглый помост под персонажем
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.42
	cyl.bottom_radius = 1.62
	cyl.height = 0.32
	cyl.radial_segments = 32
	cyl.material = AssetCatalog.get_pbr_material("grass_path_2", Vector3(0.42, 0.42, 0.42), true)
	ped.mesh = cyl
	ped.position = Vector3(0.0, -0.16, 0.0)
	_turntable.add_child(ped)

	# Вечерний костёр справа от бойца (с новым шейдерным пламенем и дымом)
	var fire_holder := Node3D.new()
	fire_holder.position = Vector3(1.95, -0.28, -1.15)
	add_child(fire_holder)
	var fp := AssetCatalog.instantiate_model("res://assets/downloaded/models/stone_fire_pit/model.gltf")
	if fp != null:
		fp.scale = Vector3(0.85, 0.85, 0.85)
		fire_holder.add_child(fp)
	VfxHelper.attach_fire_effect(fire_holder, 2.5, 11.0, 0.85)

	_preview_holder = Node3D.new()
	_preview_holder.scale = Vector3(0.84, 0.84, 0.84)
	_turntable.add_child(_preview_holder)


func _refresh_character_preview() -> void:
	if _preview_holder == null:
		return
	for ch in _preview_holder.get_children():
		ch.queue_free()

	var cls := String(NetworkManager.local_profile.get("char_class", "knight"))
	var col: Color = NetworkManager.local_profile.get("color", Color(0.20, 0.58, 0.96))

	var mdl := AssetCatalog.instantiate_character_model(cls)
	if mdl == null:
		return
	_preview_holder.add_child(mdl)

	for n in mdl.find_children("*", "Node3D", true, false):
		if n.name in ["handslot.r", "handslot_r"]:
			for ch in n.get_children():
				if ch is Node3D:
					(ch as Node3D).visible = false
			var preview_wpn := "warhammer_2h" if cls == "barbarian" else ("sword_1h" if cls == "knight" else "axe_1h")
			var wv := AssetCatalog.instantiate_weapon_visual(preview_wpn)
			n.add_child(wv)
		elif n.name in ["handslot.l", "handslot_l"]:
			for ch in n.get_children():
				if ch is Node3D:
					(ch as Node3D).visible = (cls == "knight" and ch.name == "Round_Shield")

		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var base_mat := mi.mesh.surface_get_material(0)
				if base_mat is StandardMaterial3D:
					var dup := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.roughness = 0.76
					dup.metallic = 0.08
					if "Cape" in mi.name or "Hat" in mi.name or "Hood" in mi.name:
						dup.albedo_color = col.lerp(Color.WHITE, 0.25)
					mi.material_override = dup

	for ch in mdl.find_children("*", "AnimationPlayer", true, false):
		var ap := ch as AnimationPlayer
		var idle := "2H_Melee_Idle" if cls == "barbarian" else "Idle"
		if ap.has_animation(idle):
			ap.play(idle)
		break


func _make_card_style(border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.86)
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb


func _build_menu_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	# Заголовок сверху
	var header_box := VBoxContainer.new()
	header_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_box.offset_top = 24
	header_box.offset_bottom = 104
	header_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header_box)

	var title := Label.new()
	title.text = "ОКРАИНА: ПОСЁЛОК И ЛЕС — СЕТЕВАЯ ПЕСОЧНИЦА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.68))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.95))
	title.add_theme_constant_override("outline_size", 8)
	header_box.add_child(title)

	var sub := Label.new()
	sub.text = "Восточная Европа (Август, 180×180 м)  •  Прятки в траве и домах [Ctrl]  •  Бой, пинок [F], метание [G] и спавнер [Q]"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.82, 0.90, 0.84))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub.add_theme_constant_override("outline_size", 5)
	header_box.add_child(sub)

	# Левая карточка: Боец и Графика
	var left_card := PanelContainer.new()
	left_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.45, 0.68, 0.95, 0.65)))
	root.add_child(left_card)
	left_card.set_anchors_preset(Control.PRESET_CENTER)
	left_card.offset_left = -910
	left_card.offset_right = -525
	left_card.offset_top = -215
	left_card.offset_bottom = 215

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 11)
	left_card.add_child(lv)

	var l_hdr := Label.new()
	l_hdr.text = "ПРОФИЛЬ БОЙЦА И ГРАФИКА"
	l_hdr.add_theme_font_size_override("font_size", 17)
	l_hdr.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	lv.add_child(l_hdr)

	var name_lbl := Label.new()
	name_lbl.text = "Ваш никнейм:"
	lv.add_child(name_lbl)

	_name_edit = LineEdit.new()
	_name_edit.text = String(NetworkManager.local_profile["name"])
	_name_edit.max_length = 20
	_name_edit.placeholder_text = "Введите имя..."
	_name_edit.text_changed.connect(func(txt: String) -> void: NetworkManager.local_profile["name"] = txt)
	lv.add_child(_name_edit)

	var cls_lbl := Label.new()
	cls_lbl.text = "Внешность персонажа:"
	lv.add_child(cls_lbl)

	_class_opt = OptionButton.new()
	_class_opt.add_item("Рыцарь в латах", 0)
	_class_opt.add_item("Северный варвар", 1)
	_class_opt.add_item("Следопыт в капюшоне", 2)
	var cls_keys := ["knight", "barbarian", "rogue"]
	_class_opt.selected = max(0, cls_keys.find(String(NetworkManager.local_profile["char_class"])))
	_class_opt.item_selected.connect(func(idx: int) -> void:
		NetworkManager.local_profile["char_class"] = cls_keys[idx]
		_refresh_character_preview()
	)
	lv.add_child(_class_opt)

	var col_row := HBoxContainer.new()
	lv.add_child(col_row)
	var col_lbl := Label.new()
	col_lbl.text = "Цвет плаща / метки:"
	col_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_row.add_child(col_lbl)

	_color_picker = ColorPickerButton.new()
	_color_picker.custom_minimum_size = Vector2(78, 30)
	_color_picker.edit_alpha = false
	_color_picker.color = NetworkManager.local_profile["color"]
	_color_picker.color_changed.connect(func(c: Color) -> void:
		NetworkManager.local_profile["color"] = c
		_refresh_character_preview()
	)
	col_row.add_child(_color_picker)

	lv.add_child(HSeparator.new())

	var gfx_lbl := Label.new()
	gfx_lbl.text = "Пресет рендерера Forward+:"
	lv.add_child(gfx_lbl)

	var gfx_opt := OptionButton.new()
	gfx_opt.add_item(GraphicsSettings.get_preset_name(0), 0)
	gfx_opt.add_item(GraphicsSettings.get_preset_name(1), 1)
	gfx_opt.add_item(GraphicsSettings.get_preset_name(2), 2)
	gfx_opt.selected = GraphicsSettings.current_preset
	gfx_opt.item_selected.connect(func(idx: int) -> void: GraphicsSettings.apply_preset(idx))
	lv.add_child(gfx_opt)

	var asset_info := Label.new()
	asset_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asset_info.add_theme_font_size_override("font_size", 12)
	asset_info.add_theme_color_override("font_color", Color(0.68, 0.78, 0.84))
	asset_info.text = "Ассеты: Poly Haven 4K PBR/HDRI + 3D-фотосканы + KayKit (100% CC0)."
	lv.add_child(asset_info)

	# Правая карточка: Подключение с друзьями
	var right_card := PanelContainer.new()
	right_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.95, 0.74, 0.35, 0.68)))
	root.add_child(right_card)
	right_card.set_anchors_preset(Control.PRESET_CENTER)
	right_card.offset_left = 525
	right_card.offset_right = 910
	right_card.offset_top = -225
	right_card.offset_bottom = 225

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 11)
	right_card.add_child(rv)

	var r_hdr := Label.new()
	r_hdr.text = "ЗАПУСК И СЕТЕВАЯ ИГРА"
	r_hdr.add_theme_font_size_override("font_size", 17)
	r_hdr.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	rv.add_child(r_hdr)

	var solo_btn := Button.new()
	solo_btn.text = "▶  Одиночная прогулка / Песочница"
	solo_btn.custom_minimum_size = Vector2(0, 44)
	solo_btn.pressed.connect(_on_solo_pressed)
	rv.add_child(solo_btn)

	rv.add_child(HSeparator.new())

	var port_row := HBoxContainer.new()
	rv.add_child(port_row)
	var port_lbl := Label.new()
	port_lbl.text = "UDP-порт игры:"
	port_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(port_lbl)

	_port_spin = SpinBox.new()
	_port_spin.min_value = 1024
	_port_spin.max_value = 65535
	_port_spin.value = NetworkManager.DEFAULT_PORT
	port_row.add_child(_port_spin)

	var host_btn := Button.new()
	host_btn.text = "★  Создать сервер для друзей (Host)"
	host_btn.custom_minimum_size = Vector2(0, 44)
	host_btn.pressed.connect(_on_host_pressed)
	rv.add_child(host_btn)

	var lan_ips := NetworkManager.get_local_lan_ips()
	var ip_hint := Label.new()
	ip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ip_hint.add_theme_font_size_override("font_size", 12)
	ip_hint.add_theme_color_override("font_color", Color(0.66, 0.86, 1.0))
	ip_hint.text = "Ваши локальные / VPN IP: %s" % (", ".join(lan_ips) if not lan_ips.is_empty() else "127.0.0.1")
	rv.add_child(ip_hint)

	rv.add_child(HSeparator.new())

	var join_lbl := Label.new()
	join_lbl.text = "IP-адрес хоста (LAN / Radmin VPN / Tailscale):"
	rv.add_child(join_lbl)

	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.placeholder_text = "Например, 26.x.x.x или 100.x.x.x"
	rv.add_child(_ip_edit)

	var join_btn := Button.new()
	join_btn.text = "⚡  Подключиться к серверу (Join)"
	join_btn.custom_minimum_size = Vector2(0, 44)
	join_btn.pressed.connect(_on_join_pressed)
	rv.add_child(join_btn)

	_status_lbl = Label.new()
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.98, 0.78, 0.42))
	rv.add_child(_status_lbl)

	var quit_btn := Button.new()
	quit_btn.text = "Выход на рабочий стол"
	root.add_child(quit_btn)
	quit_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	quit_btn.offset_left = -105
	quit_btn.offset_right = 105
	quit_btn.offset_top = -54
	quit_btn.offset_bottom = -18
	quit_btn.pressed.connect(func() -> void: get_tree().quit())


func _sync_profile_fields() -> void:
	var nm := _name_edit.text.strip_edges()
	NetworkManager.local_profile["name"] = nm if not nm.is_empty() else "Боец"


func _on_solo_pressed() -> void:
	_sync_profile_fields()
	NetworkManager.start_solo_sandbox()


func _on_host_pressed() -> void:
	_sync_profile_fields()
	NetworkManager.host_game(int(_port_spin.value))


func _on_join_pressed() -> void:
	_sync_profile_fields()
	NetworkManager.join_game(_ip_edit.text, int(_port_spin.value))


func _on_net_error(msg: String) -> void:
	if _status_lbl != null:
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
		_status_lbl.text = msg


func _on_net_status(msg: String) -> void:
	if _status_lbl != null:
		_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 0.65))
		_status_lbl.text = msg
