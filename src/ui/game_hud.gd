class_name GameHUD
extends CanvasLayer
## Боевой интерфейс: прицел, HP/выносливость, статус оружия, подсказки [E], лента фрагов,
## меню спавна Песочницы [Q], таблица счёта [Tab] и меню паузы [Esc].

var _crosshair_lbl: Label = null
var _prompt_lbl: Label = null
var _hp_bar: ProgressBar = null
var _hp_val_lbl: Label = null
var _stam_bar: ProgressBar = null
var _weapon_lbl: Label = null
var _death_banner: PanelContainer = null
var _killfeed_box: VBoxContainer = null

var _sandbox_panel: PanelContainer = null
var _scoreboard_panel: PanelContainer = null
var _scoreboard_rows: VBoxContainer = null
var _server_ip_lbl: Label = null
var _pause_panel: PanelContainer = null

var _sandbox_open: bool = false
var _pause_open: bool = false


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_sandbox_menu()
	_build_scoreboard()
	_build_pause_menu()

	NetworkManager.killfeed_event.connect(_on_killfeed_event)
	NetworkManager.players_updated.connect(_refresh_scoreboard)


func _make_glass_style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Прицел по центру экрана
	_crosshair_lbl = Label.new()
	_crosshair_lbl.text = "+"
	_crosshair_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair_lbl.add_theme_font_size_override("font_size", 24)
	_crosshair_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_crosshair_lbl.add_theme_constant_override("outline_size", 4)
	_crosshair_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair_lbl.position = Vector2(-24, -24)
	_crosshair_lbl.size = Vector2(48, 48)
	root.add_child(_crosshair_lbl)

	# Подсказка взаимодействия [E]
	_prompt_lbl = Label.new()
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 19)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_prompt_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_prompt_lbl.add_theme_constant_override("outline_size", 6)
	_prompt_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_lbl.position = Vector2(-260, 46)
	_prompt_lbl.size = Vector2(520, 36)
	root.add_child(_prompt_lbl)

	# Левая нижняя панель здоровья, стамины и экипировки
	var status_card := PanelContainer.new()
	status_card.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.06, 0.07, 0.10, 0.82), Color(0.35, 0.42, 0.55, 0.55), 12)
	)
	status_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_card.position = Vector2(24, -158)
	status_card.size = Vector2(340, 134)
	root.add_child(status_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	status_card.add_child(vbox)

	var hp_row := HBoxContainer.new()
	vbox.add_child(hp_row)
	var hp_title := Label.new()
	hp_title.text = "ЗДОРОВЬЕ"
	hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_title.add_theme_font_size_override("font_size", 13)
	hp_title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	hp_row.add_child(hp_title)

	_hp_val_lbl = Label.new()
	_hp_val_lbl.text = "100 / 100"
	_hp_val_lbl.add_theme_font_size_override("font_size", 13)
	hp_row.add_child(_hp_val_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.86, 0.22, 0.24)
	hp_fill.set_corner_radius_all(5)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.14, 0.15, 0.18, 0.9)
	bar_bg.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	_hp_bar.add_theme_stylebox_override("background", bar_bg)
	vbox.add_child(_hp_bar)

	_stam_bar = ProgressBar.new()
	_stam_bar.max_value = 100.0
	_stam_bar.value = 100.0
	_stam_bar.show_percentage = false
	_stam_bar.custom_minimum_size = Vector2(0, 9)
	var st_fill := StyleBoxFlat.new()
	st_fill.bg_color = Color(0.95, 0.72, 0.20)
	st_fill.set_corner_radius_all(4)
	_stam_bar.add_theme_stylebox_override("fill", st_fill)
	_stam_bar.add_theme_stylebox_override("background", bar_bg)
	vbox.add_child(_stam_bar)

	_weapon_lbl = Label.new()
	_weapon_lbl.text = "Оружие: Рукопашный бой"
	_weapon_lbl.add_theme_font_size_override("font_size", 15)
	_weapon_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	vbox.add_child(_weapon_lbl)

	# Правая нижняя шпаргалка управления
	var help_card := PanelContainer.new()
	help_card.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.06, 0.07, 0.10, 0.74), Color(0.30, 0.35, 0.45, 0.40), 10)
	)
	help_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help_card.position = Vector2(-372, -184)
	help_card.size = Vector2(348, 160)
	root.add_child(help_card)

	var help_lbl := Label.new()
	help_lbl.text = (
		"[ЛКМ] Комбо-атака   [СКМ / R] Силовой удар\n"
		+ "[F] Пинок (пробивает блок!)   [ПКМ] Блок / Прицел\n"
		+ "[E] Взять оружие / предмет   [G] Метнуть\n"
		+ "[Ctrl] Присесть (прятаться!)   [Shift] Спринт\n"
		+ "[Alt / C] Рывок   [Пробел] Прыжок\n"
		+ "[Q] Меню Песочницы   [Tab] Счёт   [Esc] Пауза"
	)
	help_lbl.add_theme_font_size_override("font_size", 12)
	help_lbl.add_theme_color_override("font_color", Color(0.84, 0.87, 0.92))
	help_card.add_child(help_lbl)

	# Правая верхняя лента событий и фрагов
	_killfeed_box = VBoxContainer.new()
	_killfeed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_killfeed_box.position = Vector2(-430, 20)
	_killfeed_box.size = Vector2(406, 260)
	_killfeed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_killfeed_box)

	# Баннер ожидания респавна
	_death_banner = PanelContainer.new()
	_death_banner.visible = false
	_death_banner.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.22, 0.05, 0.06, 0.88), Color(0.95, 0.30, 0.25, 0.85), 12)
	)
	_death_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_death_banner.position = Vector2(-190, 90)
	_death_banner.size = Vector2(380, 62)
	var dlbl := Label.new()
	dlbl.text = "ВЫ ПОВЕРЖЕНЫ — Возрождение на арене..."
	dlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dlbl.add_theme_font_size_override("font_size", 17)
	_death_banner.add_child(dlbl)
	root.add_child(_death_banner)


func _build_sandbox_menu() -> void:
	_sandbox_panel = PanelContainer.new()
	_sandbox_panel.visible = false
	_sandbox_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.07, 0.09, 0.13, 0.94), Color(0.42, 0.68, 0.98, 0.78), 14)
	)
	_sandbox_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sandbox_panel.position = Vector2(-410, -265)
	_sandbox_panel.size = Vector2(820, 530)
	add_child(_sandbox_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_sandbox_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "КАТАЛОГ ПЕСОЧНИЦЫ — Нажмите на объект, чтобы заспавнить перед собой"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Закрыть [Q]"
	close_btn.pressed.connect(func() -> void: _set_sandbox_open(false))
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	for item in AssetCatalog.SANDBOX_ITEMS:
		var item_id := String(item["id"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(248, 72)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text = "[%s] %s\n%s" % [item["category"], item["title"], item["desc"]]
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func() -> void: _request_spawn_item(item_id))
		grid.add_child(btn)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	var tip := Label.new()
	tip.text = "Совет: прячьтесь в присяде [Ctrl] в высокой траве, крапиве и домах (ваш ник скрыт!), кидайте канистры и бочки!"
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	footer.add_child(tip)

	var reset_btn := Button.new()
	reset_btn.text = "Перезагрузить объекты арены (Хост)"
	reset_btn.pressed.connect(_request_arena_props_reset)
	footer.add_child(reset_btn)


func _build_scoreboard() -> void:
	_scoreboard_panel = PanelContainer.new()
	_scoreboard_panel.visible = false
	_scoreboard_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.05, 0.07, 0.11, 0.90), Color(0.85, 0.72, 0.35, 0.75), 12)
	)
	_scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	_scoreboard_panel.position = Vector2(-310, -200)
	_scoreboard_panel.size = Vector2(620, 380)
	add_child(_scoreboard_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_scoreboard_panel.add_child(vbox)

	var title := Label.new()
	title.text = "ТАБЛИЦА БОЙЦОВ НА АРЕНЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
	vbox.add_child(title)

	_server_ip_lbl = Label.new()
	_server_ip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_server_ip_lbl.add_theme_font_size_override("font_size", 13)
	_server_ip_lbl.add_theme_color_override("font_color", Color(0.68, 0.86, 1.0))
	vbox.add_child(_server_ip_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_scoreboard_rows = VBoxContainer.new()
	_scoreboard_rows.add_theme_constant_override("separation", 6)
	vbox.add_child(_scoreboard_rows)


func _build_pause_menu() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.visible = false
	_pause_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.06, 0.08, 0.12, 0.95), Color(0.55, 0.65, 0.82, 0.80), 14)
	)
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.position = Vector2(-210, -185)
	_pause_panel.size = Vector2(420, 370)
	add_child(_pause_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "ПАУЗА И НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Вернуться в бой [Esc]"
	resume_btn.custom_minimum_size = Vector2(0, 40)
	resume_btn.pressed.connect(func() -> void: _set_pause_open(false))
	vbox.add_child(resume_btn)

	var gfx_lbl := Label.new()
	gfx_lbl.text = "Качество графики:"
	vbox.add_child(gfx_lbl)

	var gfx_opt := OptionButton.new()
	gfx_opt.add_item(GraphicsSettings.get_preset_name(0), 0)
	gfx_opt.add_item(GraphicsSettings.get_preset_name(1), 1)
	gfx_opt.add_item(GraphicsSettings.get_preset_name(2), 2)
	gfx_opt.selected = GraphicsSettings.current_preset
	gfx_opt.item_selected.connect(func(idx: int) -> void: GraphicsSettings.apply_preset(idx))
	vbox.add_child(gfx_opt)

	var sens_lbl := Label.new()
	sens_lbl.text = "Чувствительность мыши:"
	vbox.add_child(sens_lbl)

	var sens_slider := HSlider.new()
	sens_slider.min_value = 0.0008
	sens_slider.max_value = 0.0065
	sens_slider.step = 0.0002
	sens_slider.value = GraphicsSettings.mouse_sensitivity
	sens_slider.value_changed.connect(func(v: float) -> void: GraphicsSettings.mouse_sensitivity = v)
	vbox.add_child(sens_slider)

	var leave_btn := Button.new()
	leave_btn.text = "Выйти в главное меню"
	leave_btn.custom_minimum_size = Vector2(0, 40)
	leave_btn.pressed.connect(func() -> void: NetworkManager.leave_to_main_menu())
	vbox.add_child(leave_btn)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("sandbox_menu") and not _pause_open:
		_set_sandbox_open(not _sandbox_open)
	elif Input.is_action_just_pressed("pause_menu"):
		if _sandbox_open:
			_set_sandbox_open(false)
		else:
			_set_pause_open(not _pause_open)

	var want_tab := Input.is_action_pressed("scoreboard") and not _sandbox_open and not _pause_open
	if want_tab != _scoreboard_panel.visible:
		_scoreboard_panel.visible = want_tab
		if want_tab:
			_refresh_scoreboard()

	_update_local_player_stats()


func _set_sandbox_open(open: bool) -> void:
	_sandbox_open = open
	_sandbox_panel.visible = open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED)


func _set_pause_open(open: bool) -> void:
	_pause_open = open
	_pause_panel.visible = open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED)


func _get_local_character() -> PlayerCharacter:
	var arena := get_tree().current_scene
	if arena == null:
		return null
	var players_node := arena.get_node_or_null("Players")
	if players_node == null or multiplayer.multiplayer_peer == null:
		return null
	var my_name := "Player_%d" % multiplayer.get_unique_id()
	var p := players_node.get_node_or_null(my_name)
	return p as PlayerCharacter if p is PlayerCharacter else null


func _update_local_character_crosshair(pc: PlayerCharacter, prompt: String) -> void:
	if pc.is_blocking:
		_crosshair_lbl.text = "( + )"
		_crosshair_lbl.modulate = Color(0.45, 0.88, 1.0)
	elif not pc.carried_prop_name.is_empty():
		_crosshair_lbl.text = "[ o ]"
		_crosshair_lbl.modulate = Color(1.0, 0.78, 0.32)
	elif not prompt.is_empty():
		_crosshair_lbl.text = "[ + ]"
		_crosshair_lbl.modulate = Color(1.0, 0.92, 0.45)
	elif pc.is_crouching:
		_crosshair_lbl.text = "< · >"
		_crosshair_lbl.modulate = Color(0.55, 0.95, 0.62, 0.92)
	else:
		_crosshair_lbl.text = "+"
		_crosshair_lbl.modulate = Color(1.0, 1.0, 1.0, 0.88)


func _update_local_player_stats() -> void:
	var pc := _get_local_character()
	if pc == null:
		return

	_hp_bar.value = pc.hp
	_hp_val_lbl.text = "%d / %d" % [ceili(pc.hp), int(PlayerCharacter.MAX_HP)]
	_stam_bar.value = pc.stamina
	_death_banner.visible = pc.is_dead

	var stealth_tag := "  •  [Скрыт]" if pc.is_crouching else ""
	if not pc.carried_prop_name.is_empty():
		_weapon_lbl.text = "В руках: Предмет ([G] Бросок)%s" % stealth_tag
	elif pc.equipped_weapon_id.is_empty():
		_weapon_lbl.text = "Оружие: Рукопашный бой (+ [F] Пинок)%s" % stealth_tag
	elif AssetCatalog.WEAPON_DEFS.has(pc.equipped_weapon_id):
		var title := String(AssetCatalog.WEAPON_DEFS[pc.equipped_weapon_id]["title"])
		_weapon_lbl.text = "Оружие: %s ([G] Метнуть)%s" % [title, stealth_tag]

	var prompt := pc.get_look_interaction_prompt()
	_prompt_lbl.text = prompt
	_update_local_character_crosshair(pc, prompt)


func _request_spawn_item(item_id: String) -> void:
	var pc := _get_local_character()
	var arena := get_tree().current_scene
	if pc == null or arena == null or not arena.has_method("request_sandbox_spawn"):
		return
	var fwd := -Basis(Vector3.UP, pc.cam_yaw).z
	var desired_pos := pc.global_position + fwd * 2.85 + Vector3(0.0, 0.65, 0.0)
	arena.rpc_id(1, "request_sandbox_spawn", item_id, desired_pos, pc.cam_yaw)
	SfxManager.play_ui("pickup", -5.0)


func _request_arena_props_reset() -> void:
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("request_reset_arena_props"):
		arena.rpc_id(1, "request_reset_arena_props")
	_set_sandbox_open(false)


func _on_killfeed_event(message: String, accent_color: Color) -> void:
	if _killfeed_box == null:
		return
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.05, 0.06, 0.09, 0.80), Color(accent_color.r, accent_color.g, accent_color.b, 0.65), 7)
	)
	var lbl := Label.new()
	lbl.text = message
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", accent_color.lerp(Color.WHITE, 0.45))
	card.add_child(lbl)
	_killfeed_box.add_child(card)

	while _killfeed_box.get_child_count() > 6:
		var oldest := _killfeed_box.get_child(0)
		_killfeed_box.remove_child(oldest)
		oldest.queue_free()

	var tw := create_tween()
	tw.tween_interval(6.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(card.queue_free)


func _refresh_scoreboard() -> void:
	if _scoreboard_rows == null:
		return
	for ch in _scoreboard_rows.get_children():
		ch.queue_free()

	if NetworkManager.is_online_host:
		var ips := NetworkManager.get_local_lan_ips()
		var ip_str := ", ".join(ips) if not ips.is_empty() else "127.0.0.1"
		_server_ip_lbl.text = "Вы Хост (UDP порт %d)  |  Ваши IP для друзей (LAN/VPN): %s" % [NetworkManager.active_port, ip_str]
	else:
		_server_ip_lbl.text = "Сетевая песочница  |  Активных бойцов: %d" % NetworkManager.players.size()

	var ids := NetworkManager.players.keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = NetworkManager.players[pid]
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = "%s (%s)" % [p.get("name", "Боец"), String(p.get("char_class", "knight")).capitalize()]
		name_lbl.add_theme_color_override("font_color", p.get("color", Color.WHITE).lerp(Color.WHITE, 0.35))
		row.add_child(name_lbl)

		var kd_lbl := Label.new()
		var ping := NetworkManager.get_peer_ping_ms(int(pid))
		var ping_str := "Хост" if int(pid) == 1 else "%d мс" % ping
		kd_lbl.text = "Фраги: %d   |   Смерти: %d   |   %s" % [int(p.get("kills", 0)), int(p.get("deaths", 0)), ping_str]
		row.add_child(kd_lbl)
		_scoreboard_rows.add_child(row)
