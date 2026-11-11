class_name VfxHelper
extends RefCounted
## Реалистичные визуальные эффекты (Forward+):
## процедурный GPU-шейдер живого пламени костра, тлеющие угли, мягкий дым, искры, щепки и взрывы.

static var _soft_glow_tex: GradientTexture2D = null
static var _soft_smoke_tex: GradientTexture2D = null
static var _flame_shader: Shader = null
static var _ember_shader: Shader = null


static func _get_soft_glow_tex() -> GradientTexture2D:
	if _soft_glow_tex != null:
		return _soft_glow_tex
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.28, 0.68, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.92, 0.75, 0.78),
		Color(1.0, 0.65, 0.30, 0.22),
		Color(1.0, 0.40, 0.10, 0.0),
	])
	tex.gradient = g
	_soft_glow_tex = tex
	return tex


static func _get_soft_smoke_tex() -> GradientTexture2D:
	if _soft_smoke_tex != null:
		return _soft_smoke_tex
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.80, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.55),
		Color(0.92, 0.92, 0.94, 0.30),
		Color(0.85, 0.85, 0.88, 0.08),
		Color(0.80, 0.80, 0.85, 0.0),
	])
	tex.gradient = g
	_soft_smoke_tex = tex
	return tex


static func _get_flame_shader() -> Shader:
	if _flame_shader != null:
		return _flame_shader
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float time_offset = 0.0;
uniform float flame_intensity = 2.5;
uniform float wind_sway = 0.10;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i + vec2(0.0, 0.0)), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	float t = TIME + time_offset;
	VERTEX.x += sin(t * 4.2 + h * 4.5) * h * h * wind_sway;
	VERTEX.z += cos(t * 3.5 + h * 3.8) * h * h * (wind_sway * 0.8);
}

void fragment() {
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	float x = (UV.x - 0.5) * 2.0;
	float t = TIME + time_offset;

	float n1 = fbm(vec2(x * 2.3, h * 2.9 - t * 3.15));
	float n2 = fbm(vec2(x * 4.7 + 5.2, h * 5.4 - t * 4.85));
	float turb = mix(n1, n2, 0.42);

	float x_warp = x + (turb - 0.48) * (0.30 + h * 0.88);
	float half_w = mix(0.76, 0.05, pow(h, 0.82));
	float horiz = 1.0 - smoothstep(half_w * 0.25, half_w, abs(x_warp));

	float base_in = smoothstep(0.0, 0.11, h);
	float top_erode = smoothstep(1.04, 0.14, h + (turb - 0.47) * 0.68);
	float mask = clamp(horiz * base_in * top_erode, 0.0, 1.0);

	// Реалистичная цветовая температура пламени (Blackbody)
	vec3 outer_red = vec3(0.95, 0.14, 0.02);
	vec3 mid_orange = vec3(1.00, 0.48, 0.06);
	vec3 core_white = vec3(1.00, 0.93, 0.68);
	vec3 base_blue = vec3(0.18, 0.38, 0.95);

	vec3 col = mix(outer_red, mid_orange, smoothstep(0.12, 0.52, mask));
	col = mix(col, core_white, smoothstep(0.56, 0.90, mask));
	float blue_zone = (1.0 - smoothstep(0.03, 0.22, h)) * smoothstep(0.15, 0.6, horiz);
	col = mix(col, base_blue, blue_zone * 0.38);

	ALBEDO = col * mask * flame_intensity;
	ALPHA = clamp(mask * 1.15, 0.0, 1.0);
}
"""
	_flame_shader = sh
	return sh


static func _get_ember_shader() -> Shader:
	if _ember_shader != null:
		return _ember_shader
	var sh := Shader.new()
	sh.code = """
shader_type spatial;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	float cracks = vnoise(UV * 18.0) * 0.6 + vnoise(UV * 39.0) * 0.4;
	float pulse = 0.72 + 0.28 * sin(TIME * 3.4 + cracks * 6.2);
	float glow = smoothstep(0.42, 0.82, cracks) * pulse;
	ALBEDO = mix(vec3(0.05, 0.04, 0.04), vec3(0.22, 0.07, 0.02), glow);
	ROUGHNESS = 0.92;
	EMISSION = mix(vec3(0.85, 0.16, 0.02), vec3(1.0, 0.62, 0.12), glow) * glow * 3.6;
}
"""
	_ember_shader = sh
	return sh


static func spawn_hit_sparks(parent: Node, world_pos: Vector3, color: Color, count: int = 18, scale_mult: float = 1.0) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return

	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = count
	particles.lifetime = 0.44

	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11) * scale_mult
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = _get_soft_glow_tex()
	mat.albedo_color = color * 2.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	particles.mesh = quad

	particles.direction = Vector3.UP
	particles.spread = 165.0
	particles.initial_velocity_min = 3.5 * scale_mult
	particles.initial_velocity_max = 9.5 * scale_mult
	particles.gravity = Vector3(0.0, -16.0, 0.0)
	particles.damping_min = 2.0
	particles.damping_max = 5.0

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(color.r, color.g * 0.6, color.b * 0.3, 0.0))
	particles.color_ramp = grad

	parent.add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true

	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 2.8 * scale_mult
	flash.omni_range = 4.5 * scale_mult
	parent.add_child(flash)
	flash.global_position = world_pos

	var tw := parent.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.16)
	tw.tween_callback(flash.queue_free)

	parent.get_tree().create_timer(0.65).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


static func spawn_wood_debris(parent: Node, world_pos: Vector3) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return

	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = 22
	particles.lifetime = 0.85

	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.04, 0.07)
	box.material = AssetCatalog.get_pbr_material("brown_planks_03", Vector3(1.5, 1.5, 1.5), false)
	particles.mesh = box

	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 110.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 8.5
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.gravity = Vector3(0.0, -18.0, 0.0)

	parent.add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true

	parent.get_tree().create_timer(1.1).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


static func spawn_explosion_vfx(parent: Node, world_pos: Vector3) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return

	spawn_hit_sparks(parent, world_pos + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.52, 0.12), 48, 2.4)

	# Мягкое облако пламени и чёрно-серого порохового дыма (без резких граней)
	var smoke := CPUParticles3D.new()
	smoke.emitting = false
	smoke.one_shot = true
	smoke.explosiveness = 0.92
	smoke.amount = 28
	smoke.lifetime = 1.45
	var sq := QuadMesh.new()
	sq.size = Vector2(1.8, 1.8)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.vertex_color_use_as_albedo = true
	smat.albedo_texture = _get_soft_smoke_tex()
	sq.material = smat
	smoke.mesh = sq
	smoke.direction = Vector3.UP
	smoke.spread = 135.0
	smoke.initial_velocity_min = 2.2
	smoke.initial_velocity_max = 6.8
	smoke.damping_min = 3.0
	smoke.damping_max = 5.5
	smoke.gravity = Vector3(0.0, 1.8, 0.0)
	var sgrad := Gradient.new()
	sgrad.offsets = PackedFloat32Array([0.0, 0.22, 0.65, 1.0])
	sgrad.colors = PackedColorArray([
		Color(1.0, 0.65, 0.20, 0.90),
		Color(0.28, 0.24, 0.22, 0.72),
		Color(0.18, 0.18, 0.19, 0.35),
		Color(0.15, 0.15, 0.16, 0.0),
	])
	smoke.color_ramp = sgrad
	parent.add_child(smoke)
	smoke.global_position = world_pos + Vector3(0.0, 0.55, 0.0)
	smoke.emitting = true

	parent.get_tree().create_timer(1.8).timeout.connect(func() -> void:
		if is_instance_valid(smoke):
			smoke.queue_free()
	)


static func spawn_damage_popup(parent: Node, world_pos: Vector3, text: String, color: Color) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return

	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 46
	lbl.outline_size = 12
	lbl.modulate = color
	lbl.outline_modulate = Color(0.05, 0.05, 0.07, 0.95)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = false
	lbl.pixel_size = 0.0065
	parent.add_child(lbl)

	var jitter := Vector3(randf_range(-0.35, 0.35), randf_range(0.0, 0.25), randf_range(-0.35, 0.35))
	lbl.global_position = world_pos + jitter

	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0.0, 1.35, 0.0), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.72).set_delay(0.18)
	tw.chain().tween_callback(lbl.queue_free)


static func attach_fire_effect(target: Node3D, light_energy: float = 2.9, omni_range: float = 14.0, particle_scale: float = 1.0) -> void:
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.58, 0.22)
	light.light_energy = light_energy
	light.omni_range = omni_range
	light.omni_attenuation = 1.35
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 34.0
	light.distance_fade_shadow = 26.0
	light.distance_fade_length = 14.0
	light.position = Vector3(0.0, 0.65 * particle_scale, 0.0)
	target.add_child(light)

	if DisplayServer.get_name() == "headless":
		return

	var root := Node3D.new()
	root.name = "RealisticCampfireVFX"
	target.add_child(root)

	# 1. Тлеющие угли и обугленные поленья в основании костра
	var ember_mat := ShaderMaterial.new()
	ember_mat.shader = _get_ember_shader()

	var coal_bed := MeshInstance3D.new()
	var coal_cyl := CylinderMesh.new()
	coal_cyl.top_radius = 0.36 * particle_scale
	coal_cyl.bottom_radius = 0.46 * particle_scale
	coal_cyl.height = 0.12 * particle_scale
	coal_cyl.radial_segments = 18
	coal_cyl.material = ember_mat
	coal_bed.mesh = coal_cyl
	coal_bed.position = Vector3(0.0, 0.07 * particle_scale, 0.0)
	root.add_child(coal_bed)

	for i in range(5):
		var log_mi := MeshInstance3D.new()
		var log_cyl := CylinderMesh.new()
		log_cyl.top_radius = 0.055 * particle_scale
		log_cyl.bottom_radius = 0.070 * particle_scale
		log_cyl.height = 0.78 * particle_scale
		log_cyl.radial_segments = 10
		log_cyl.material = ember_mat
		log_mi.mesh = log_cyl
		var ang := float(i) * TAU / 5.0 + 0.25
		log_mi.position = Vector3(cos(ang) * 0.16, 0.16, sin(ang) * 0.16) * particle_scale
		log_mi.rotation = Vector3(deg_to_rad(68.0), ang, 0.0)
		root.add_child(log_mi)

	# 2. Перекрещенные 3D-языки пламени на процедурном FBM-шейдере (никаких кубиков!)
	var angles := [0.0, 60.0, 120.0]
	for idx in range(angles.size()):
		var fmi := MeshInstance3D.new()
		var fq := QuadMesh.new()
		fq.size = Vector2(0.86, 1.32) * particle_scale
		fq.subdivide_width = 6
		fq.subdivide_depth = 10
		var sm := ShaderMaterial.new()
		sm.shader = _get_flame_shader()
		sm.set_shader_parameter("time_offset", float(idx) * 2.37 + randf() * 1.5)
		sm.set_shader_parameter("flame_intensity", 2.15)
		sm.set_shader_parameter("wind_sway", 0.09 * particle_scale)
		fq.material = sm
		fmi.mesh = fq
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fmi.position = Vector3(0.0, 0.68 * particle_scale, 0.0)
		fmi.rotation_degrees.y = float(angles[idx])
		root.add_child(fmi)

	# 3. Мягкий вечерний дымок над костром
	var smoke := CPUParticles3D.new()
	smoke.name = "CampfireSmoke"
	smoke.amount = 18
	smoke.lifetime = 3.2
	smoke.preprocess = 2.4
	smoke.position = Vector3(0.0, 0.95 * particle_scale, 0.0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.18 * particle_scale
	smoke.direction = Vector3(0.12, 1.0, 0.06).normalized()
	smoke.spread = 14.0
	smoke.gravity = Vector3(0.08, 0.55, 0.04)
	smoke.initial_velocity_min = 0.35 * particle_scale
	smoke.initial_velocity_max = 0.75 * particle_scale
	smoke.scale_amount_min = 0.65
	smoke.scale_amount_max = 1.65

	var smoke_q := QuadMesh.new()
	smoke_q.size = Vector2(0.85, 0.85) * particle_scale
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	smoke_mat.albedo_color = Color(0.62, 0.58, 0.56, 0.26)
	smoke_mat.albedo_texture = _get_soft_smoke_tex()
	smoke_q.material = smoke_mat
	smoke.mesh = smoke_q

	var sc_curve := Curve.new()
	sc_curve.add_point(Vector2(0.0, 0.15))
	sc_curve.add_point(Vector2(0.45, 1.0))
	sc_curve.add_point(Vector2(1.0, 0.0))
	smoke.scale_amount_curve = sc_curve
	root.add_child(smoke)

	# 4. Мелкие взмывающие крупинки раскалённых искр
	var sparks := CPUParticles3D.new()
	sparks.name = "EmberSparks"
	sparks.amount = 22
	sparks.lifetime = 1.85
	sparks.preprocess = 1.2
	sparks.position = Vector3(0.0, 0.26 * particle_scale, 0.0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.26 * particle_scale
	sparks.direction = Vector3(0.08, 1.0, 0.04).normalized()
	sparks.spread = 24.0
	sparks.gravity = Vector3(0.15, 1.45, 0.06)
	sparks.initial_velocity_min = 0.65 * particle_scale
	sparks.initial_velocity_max = 1.95 * particle_scale
	sparks.orbit_velocity_min = -0.15
	sparks.orbit_velocity_max = 0.15

	var sp_quad := QuadMesh.new()
	sp_quad.size = Vector2(0.048, 0.048) * particle_scale
	var sp_mat := StandardMaterial3D.new()
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sp_mat.vertex_color_use_as_albedo = true
	sp_mat.albedo_texture = _get_soft_glow_tex()
	sp_mat.albedo_color = Color(2.4, 1.35, 0.45, 1.0)
	sp_quad.material = sp_mat
	sparks.mesh = sp_quad

	var sp_grad := Gradient.new()
	sp_grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	sp_grad.colors = PackedColorArray([
		Color(1.0, 0.92, 0.55, 1.0),
		Color(1.0, 0.45, 0.12, 0.85),
		Color(0.8, 0.15, 0.02, 0.0),
	])
	sparks.color_ramp = sp_grad
	root.add_child(sparks)

	# 5. Живое покачивание яркости огня на брёвнах и лицах игроков
	var timer := Timer.new()
	timer.wait_time = 0.09
	timer.autostart = true
	root.add_child(timer)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(light):
			light.light_energy = light_energy * randf_range(0.88, 1.14)
	)
