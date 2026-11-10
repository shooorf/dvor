extends Node3D
## Главное меню с живой 3D-диорамой выбранного бойца на фоне закатного неба (4K HDRI),
## выбором класса и цвета, настройкой графики RTX 4070 и запуском сетевой игры ENet UDP.

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
		_turntable.rotation.y += delta * 0.35


func _build_3d_backdrop() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var hdri := AssetCatalog.load_sky_hdri()
	if hdri != null:
		var sm := PanoramaSkyMaterial.new()
		sm.panorama = hdri
		sky.sky_material = sm
	else:
		var psm := ProceduralSkyMaterial.new()
		psm.sky_top_color = Color(0.16, 0.30, 0.56)
		psm.sky_horizon_color = Color(0.86, 0.58, 0.38)
		sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.70)
	sun.light_energy = 2.1
	sun.rotation_degrees = Vector3(-30.0, 42.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	GraphicsSettings.register_scene_lighting(env, sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.55, 4.15)
	cam.rotation_degrees = Vector3(-6.5, 0.0, 0.0)
	cam.fov = 56.0
	cam.current = true
	add_child(cam)

	_turntable = Node3D.new()
	_turntable.position = Vector3(0.0, 0.0, 0.0)
	add_child(_turntable)

	# Сплошная лесная поляна и каменная стена/заросли на фоне меню (без пустоты вокруг подиума)
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(60.0, 0.4, 60.0)
	gm.material = AssetCatalog.get_pbr_material("aerial_grass_rock", Vector3(0.22, 0.22, 0.22), true)
	ground.mesh = gm
	ground.position = Vector3(0.0, -0.56, -4.0)
	add_child(ground)

	for bg_spec in [
		["res://assets/downloaded/nature/PineTree_1.glb", Vector3(-3.8, -0.36, -4.5), 2.6],
		["res://assets/downloaded/nature/CommonTree_1.glb", Vector3(4.2, -0.36, -5.2), 2.8],
		["res://assets/downloaded/nature/Willow_1.glb", Vector3(0.4, -0.36, -6.8), 3.0],
		["res://assets/downloaded/models/shrub_02/model.gltf", Vector3(-2.4, -0.18, -2.6), 1.25],
		["res://assets/downloaded/nature/BushBerries_1.glb", Vector3(2.9, -0.36, -2.8), 1.6],
	]:
		var bg_mdl := AssetCatalog.instantiate_model(String(bg_spec[0]))
		if bg_mdl != null:
			bg_mdl.position = bg_spec[1]
			var s := float(bg_spec[2])
			bg_mdl.scale = Vector3(s, s, s)
			add_child(bg_mdl)

	# Каменный подиум
	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.45
	cyl.bottom_radius = 1.65
	cyl.height = 0.36
	cyl.radial_segments = 32
	cyl.material = AssetCatalog.get_pbr_material("cobblestone_05", Vector3(0.4, 0.4, 0.4), true)
	ped.mesh = cyl
	ped.position = Vector3(0.0, -0.18, 0.0)
	_turntable.add_child(ped)

	# Фоновая жаровня справа от бойца
	var fire_holder := Node3D.new()
	fire_holder.position = Vector3(1.95, 0.0, -1.1)
	add_child(fire_holder)
	var fp := AssetCatalog.instantiate_model("res://assets/downloaded/models/stone_fire_pit/model.gltf")
	if fp != null:
		fp.scale = Vector3(0.85, 0.85, 0.85)
		fire_holder.add_child(fp)
	VfxHelper.attach_fire_effect(fire_holder, 2.6, 10.0, 0.85)

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
		if n.name == "handslot.r":
			for ch in n.get_children():
				if ch is Node3D:
					(ch as Node3D).visible = false
			var preview_wpn := "warhammer_2h" if cls == "barbarian" else ("sword_1h" if cls == "knight" else "axe_1h")
			var wv := AssetCatalog.instantiate_weapon_visual(preview_wpn)
			n.add_child(wv)
		elif n.name == "handslot.l":
			for ch in n.get_children():
				if ch is Node3D:
					(ch as Node3D).visible = (cls == "knight" and ch.name == "Round_Shield")

		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var base_mat := mi.mesh.surface_get_material(0)
				if base_mat is StandardMaterial3D:
					var dup := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
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
	sb.bg_color = Color(0.05, 0.07, 0.11, 0.86)
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
	title.text = "ЛЕСНАЯ ЦИТАДЕЛЬ — СЕТЕВАЯ ПЕСОЧНИЦА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.68))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.95))
	title.add_theme_constant_override("outline_size", 8)
	header_box.add_child(title)

	var sub := Label.new()
	sub.text = "Рукопашный бой  •  Мечи, булавы и молоты  •  Спартанский пинок  •  Метание предметов и спавнер [Q]"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub.add_theme_constant_override("outline_size", 5)
	header_box.add_child(sub)

	# Левая карточка: Боец и Графика
	var left_card := PanelContainer.new()
	left_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.45, 0.68, 0.95, 0.65)))
	left_card.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left_card.position = Vector2(36, -205)
	left_card.size = Vector2(365, 430)
	root.add_child(left_card)

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
	_class_opt.add_item("Разбойник в капюшоне", 2)
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
	asset_info.add_theme_color_override("font_color", Color(0.68, 0.76, 0.86))
	asset_info.text = "Ассеты: Poly Haven PBR/HDRI + KayKit + Quaternius (100% CC0)."
	lv.add_child(asset_info)

	# Правая карточка: Подключение с друзьями
	var right_card := PanelContainer.new()
	right_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.95, 0.74, 0.35, 0.68)))
	right_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right_card.position = Vector2(-416, -215)
	right_card.size = Vector2(380, 450)
	root.add_child(right_card)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 11)
	right_card.add_child(rv)

	var r_hdr := Label.new()
	r_hdr.text = "ЗАПУСК И СЕТЕВАЯ ИГРА"
	r_hdr.add_theme_font_size_override("font_size", 17)
	r_hdr.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	rv.add_child(r_hdr)

	var solo_btn := Button.new()
	solo_btn.text = "▶  Одиночная песочница (Быстрый старт)"
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
	quit_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	quit_btn.position = Vector2(-105, -54)
	quit_btn.size = Vector2(210, 36)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	root.add_child(quit_btn)


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
