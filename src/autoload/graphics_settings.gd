extends Node
## Управление графическими пресетами (по умолчанию — Ultra под RTX 4070).

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
			return "Ultra (RTX 4070 — SDFGI + 4K + Volumetric)"
		Preset.HIGH:
			return "Высокие (SSAO + SSR + Туман)"
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
				vp.msaa_3d = Viewport.MSAA_2X
				vp.use_taa = true
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				vp.positional_shadow_atlas_size = 8192
				RenderingServer.directional_shadow_atlas_set_size(8192, true)
			Preset.HIGH:
				vp.msaa_3d = Viewport.MSAA_2X
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
		match preset:
			Preset.ULTRA_4070:
				_registered_sun.directional_shadow_max_distance = 140.0
				_registered_sun.shadow_blur = 1.35
			Preset.HIGH:
				_registered_sun.directional_shadow_max_distance = 100.0
				_registered_sun.shadow_blur = 1.1
			Preset.MEDIUM:
				_registered_sun.directional_shadow_max_distance = 75.0
				_registered_sun.shadow_blur = 0.8

	if _registered_env != null:
		_registered_env.tonemap_mode = Environment.TONE_MAPPER_AGX
		_registered_env.tonemap_exposure = 1.05
		_registered_env.glow_enabled = true
		_registered_env.glow_intensity = 0.45
		_registered_env.glow_bloom = 0.08
		_registered_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

		match preset:
			Preset.ULTRA_4070:
				_registered_env.sdfgi_enabled = true
				_registered_env.sdfgi_use_occlusion = true
				_registered_env.sdfgi_bounce_feedback = 0.75
				_registered_env.sdfgi_cascades = 4
				_registered_env.sdfgi_min_cell_size = 0.25
				_registered_env.ssao_enabled = true
				_registered_env.ssao_radius = 1.25
				_registered_env.ssao_intensity = 2.1
				_registered_env.ssil_enabled = true
				_registered_env.ssil_radius = 4.0
				_registered_env.ssil_intensity = 1.0
				_registered_env.ssr_enabled = true
				_registered_env.ssr_max_steps = 64
				_registered_env.volumetric_fog_enabled = true
				_registered_env.volumetric_fog_density = 0.0065
				_registered_env.volumetric_fog_albedo = Color(0.96, 0.86, 0.76)
				_registered_env.volumetric_fog_anisotropy = 0.55
			Preset.HIGH:
				_registered_env.sdfgi_enabled = false
				_registered_env.ssao_enabled = true
				_registered_env.ssao_radius = 1.1
				_registered_env.ssao_intensity = 1.8
				_registered_env.ssil_enabled = false
				_registered_env.ssr_enabled = true
				_registered_env.ssr_max_steps = 32
				_registered_env.volumetric_fog_enabled = true
				_registered_env.volumetric_fog_density = 0.0055
				_registered_env.volumetric_fog_albedo = Color(0.95, 0.86, 0.78)
			Preset.MEDIUM:
				_registered_env.sdfgi_enabled = false
				_registered_env.ssao_enabled = false
				_registered_env.ssil_enabled = false
				_registered_env.ssr_enabled = false
				_registered_env.volumetric_fog_enabled = false

	preset_changed.emit(current_preset)
