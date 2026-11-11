extends Node
## Управление графическими пресетами (по умолчанию — Ultra под RTX 4070 для открытого мира 180×180 м).

enum Preset {
	ULTRA_4070 = 0,
	HIGH = 1,
	MEDIUM = 2,
}

signal preset_changed(new_preset: int)

var current_preset: int = Preset.ULTRA_4070
var mouse_sensitivity: float = 0.0024

var _registered_env: Environment = null
var _registered_sun: DirectionalLight3D = null


func get_preset_name(p: int) -> String:
	match p:
		Preset.ULTRA_4070:
			return "Ultra (RTX 4070 — 4K PBR + SSIL + Volumetric)"
		Preset.HIGH:
			return "Высокие (SSAO + SSR + Дымка)"
		Preset.MEDIUM:
			return "Средние (Высокий FPS)"
	return "Ultra"


func register_scene_lighting(env: Environment, sun: DirectionalLight3D) -> void:
	_registered_env = env
	_registered_sun = sun
	apply_preset(current_preset)


func apply_preset(preset: int) -> void:
	current_preset = preset
	if DisplayServer.get_name() == "headless":
		preset_changed.emit(current_preset)
		return

	var vp := get_viewport()
	if vp != null:
		match preset:
			Preset.ULTRA_4070:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.use_taa = true
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.positional_shadow_atlas_size = 4096
				RenderingServer.directional_shadow_atlas_set_size(4096, true)
			Preset.HIGH:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.use_taa = true
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.positional_shadow_atlas_size = 4096
				RenderingServer.directional_shadow_atlas_set_size(4096, true)
			Preset.MEDIUM:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.use_taa = false
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
				vp.positional_shadow_atlas_size = 2048
				RenderingServer.directional_shadow_atlas_set_size(2048, true)

	if _registered_sun != null:
		_registered_sun.shadow_enabled = true
		_registered_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_registered_sun.directional_shadow_blend_splits = true
		_registered_sun.directional_shadow_split_1 = 0.07
		_registered_sun.directional_shadow_split_2 = 0.19
		_registered_sun.directional_shadow_split_3 = 0.44
		match preset:
			Preset.ULTRA_4070:
				_registered_sun.directional_shadow_max_distance = 96.0
				_registered_sun.shadow_blur = 0.55
			Preset.HIGH:
				_registered_sun.directional_shadow_max_distance = 86.0
				_registered_sun.shadow_blur = 0.55
			Preset.MEDIUM:
				_registered_sun.directional_shadow_max_distance = 72.0
				_registered_sun.shadow_blur = 0.50

	if _registered_env != null:
		# Кинематографичный ACES сохраняет глубокие тени, насыщенную лесную зелень и микроконтраст коры/земли
		_registered_env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_registered_env.tonemap_exposure = 1.0
		_registered_env.glow_enabled = true
		_registered_env.glow_intensity = 0.24
		_registered_env.glow_bloom = 0.03
		_registered_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		# Воздушная перспектива уведена далеко к горизонту (240..460 м) с глубоким лесным оттенком,
		# чтобы деревья на границе игровой зоны (88..220 м) оставались сочно-зелёными без малейшей «седины»!
		_registered_env.volumetric_fog_enabled = false
		_registered_env.fog_enabled = (preset != Preset.MEDIUM)
		_registered_env.fog_mode = Environment.FOG_MODE_DEPTH
		_registered_env.fog_depth_begin = 240.0
		_registered_env.fog_depth_end = 460.0
		_registered_env.fog_light_color = Color(0.12, 0.19, 0.15)
		_registered_env.fog_density = 0.22
		_registered_env.fog_sky_affect = 0.08

		match preset:
			Preset.ULTRA_4070:
				_registered_env.sdfgi_enabled = false
				_registered_env.ssao_enabled = true
				_registered_env.ssao_radius = 1.15
				_registered_env.ssao_intensity = 2.35
				_registered_env.ssil_enabled = true
				_registered_env.ssil_radius = 3.8
				_registered_env.ssil_intensity = 0.65
				_registered_env.ssr_enabled = false
			Preset.HIGH:
				_registered_env.sdfgi_enabled = false
				_registered_env.ssao_enabled = true
				_registered_env.ssao_radius = 1.10
				_registered_env.ssao_intensity = 2.10
				_registered_env.ssil_enabled = false
				_registered_env.ssr_enabled = false
			Preset.MEDIUM:
				_registered_env.sdfgi_enabled = false
				_registered_env.ssao_enabled = false
				_registered_env.ssil_enabled = false
				_registered_env.ssr_enabled = false

	preset_changed.emit(current_preset)
