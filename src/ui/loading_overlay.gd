class_name LoadingOverlay
extends CanvasLayer
## Неблокирующий полноэкранный оверлей загрузки мира с плавным ProgressBar,
## живым индикатором активности (60 FPS, окно всегда отвечает ОС) и таймером этапов.

var _bg: ColorRect = null
var _card: PanelContainer = null
var _stage_lbl: Label = null
var _pct_lbl: Label = null
var _time_lbl: Label = null
var _spinner_lbl: Label = null
var _bar: ProgressBar = null
var _tip_lbl: Label = null

var _target_pct: float = 0.0
var _shown_pct: float = 0.0
var _elapsed: float = 0.0
var _spin_phase: float = 0.0
var _is_fading: bool = false

const SPINNER_FRAMES: Array[String] = ["◐", "◓", "◑", "◒"]
const TIPS: Array[String] = [
	"Совет: Нажмите [Q] в игре, чтобы открыть меню Песочницы и заспавнить оружие, бочки или трамплины.",
	"Совет: Присядьте на [Ctrl] в густой луговой траве или кустах — никнейм скроется для засады!",
	"Совет: Любое оружие можно метнуть в противника клавишей [G], а блок пробивается пинком [F].",
]


func _init(title_text: String = "ЗАГРУЗКА ОТКРЫТОГО МИРА") -> void:
	layer = 100
	name = "LoadingOverlay"
	_build_ui(title_text)


func _build_ui(title_text: String) -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.04, 0.06, 0.08, 0.96)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(680, 250)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.07, 0.10, 0.13, 0.96)
	card_sb.border_color = Color(0.92, 0.74, 0.38, 0.72)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(16)
	card_sb.content_margin_left = 32
	card_sb.content_margin_right = 32
	card_sb.content_margin_top = 26
	card_sb.content_margin_bottom = 24
	_card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_card.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	_spinner_lbl = Label.new()
	_spinner_lbl.text = SPINNER_FRAMES[0]
	_spinner_lbl.add_theme_font_size_override("font_size", 22)
	_spinner_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42))
	top_row.add_child(_spinner_lbl)

	var hdr := Label.new()
	hdr.text = title_text
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_font_size_override("font_size", 21)
	hdr.add_theme_color_override("font_color", Color(0.98, 0.90, 0.68))
	top_row.add_child(hdr)

	_time_lbl = Label.new()
	_time_lbl.text = "0.0 с"
	_time_lbl.add_theme_font_size_override("font_size", 14)
	_time_lbl.add_theme_color_override("font_color", Color(0.62, 0.74, 0.82))
	top_row.add_child(_time_lbl)

	var stage_row := HBoxContainer.new()
	vbox.add_child(stage_row)

	_stage_lbl = Label.new()
	_stage_lbl.text = "Подготовка ресурсов..."
	_stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_lbl.add_theme_font_size_override("font_size", 15)
	_stage_lbl.add_theme_color_override("font_color", Color(0.84, 0.91, 0.88))
	stage_row.add_child(_stage_lbl)

	_pct_lbl = Label.new()
	_pct_lbl.text = "0%"
	_pct_lbl.add_theme_font_size_override("font_size", 16)
	_pct_lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	stage_row.add_child(_pct_lbl)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 22)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.03, 0.05, 0.07, 0.95)
	bar_bg.border_color = Color(0.26, 0.36, 0.44, 0.75)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(8)
	_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.36, 0.74, 0.46, 0.95)
	bar_fill.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_bar)

	_tip_lbl = Label.new()
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lbl.text = TIPS[randi() % TIPS.size()]
	_tip_lbl.add_theme_font_size_override("font_size", 13)
	_tip_lbl.add_theme_color_override("font_color", Color(0.64, 0.76, 0.72))
	vbox.add_child(_tip_lbl)


func set_progress(pct: float, stage_text: String = "") -> void:
	_target_pct = clampf(pct, _target_pct, 100.0)
	if _target_pct >= 99.9:
		_shown_pct = 100.0
		if _bar != null:
			_bar.value = 100.0
		if _pct_lbl != null:
			_pct_lbl.text = "100%"
	if not stage_text.is_empty() and _stage_lbl != null:
		_stage_lbl.text = stage_text


func _process(delta: float) -> void:
	if _is_fading:
		return
	_elapsed += delta
	_spin_phase += delta * 8.0
	if _spinner_lbl != null:
		_spinner_lbl.text = SPINNER_FRAMES[int(_spin_phase) % SPINNER_FRAMES.size()]
	if _time_lbl != null:
		_time_lbl.text = "%.1f с" % _elapsed

	# Плавное визуальное движение полоски даже между дискретными шагами генерации
	var creep_cap := minf(_target_pct + 2.5, 99.0)
	if _shown_pct < _target_pct:
		_shown_pct = move_toward(_shown_pct, _target_pct, maxf(18.0, (_target_pct - _shown_pct) * 8.5) * delta)
	elif _shown_pct < creep_cap:
		_shown_pct = move_toward(_shown_pct, creep_cap, 0.65 * delta)

	if _bar != null:
		_bar.value = _shown_pct
	if _pct_lbl != null:
		_pct_lbl.text = "%d%%" % int(round(_shown_pct))


func fade_out_and_free(duration: float = 0.24) -> void:
	if _is_fading:
		return
	_is_fading = true
	set_progress(100.0, "Готово!")
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)
