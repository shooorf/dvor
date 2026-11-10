class_name VfxHelper
extends RefCounted
## Генератор визуальных спецэффектов боя: искры ударов, щепки ящиков, взрывные волны и всплывающий урон.


static func spawn_hit_sparks(parent: Node, world_pos: Vector3, color: Color, count: int = 18, scale_mult: float = 1.0) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return

	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = count
	particles.lifetime = 0.42

	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09) * scale_mult
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color * 2.4 # Яркая эмиссия для Glow/Bloom
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	flash.light_energy = 3.2 * scale_mult
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
	box.size = Vector3(0.22, 0.05, 0.09)
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

	spawn_hit_sparks(parent, world_pos + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.52, 0.12), 42, 2.3)

	var fireball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.58, 0.16, 0.88)
	sphere.material = mat
	fireball.mesh = sphere
	parent.add_child(fireball)
	fireball.global_position = world_pos + Vector3(0.0, 0.5, 0.0)

	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fireball, "scale", Vector3(6.8, 6.8, 6.8), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(0.25, 0.18, 0.15, 0.0), 0.36)
	tw.chain().tween_callback(fireball.queue_free)


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


static func attach_fire_effect(target: Node3D, light_energy: float = 2.8, omni_range: float = 11.0, particle_scale: float = 1.0) -> void:
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.56, 0.18)
	light.light_energy = light_energy
	light.omni_range = omni_range
	light.shadow_enabled = true
	light.position = Vector3(0.0, 0.45 * particle_scale, 0.0)
	target.add_child(light)

	if DisplayServer.get_name() == "headless":
		return

	var flames := CPUParticles3D.new()
	flames.name = "FlameParticles"
	flames.amount = 26
	flames.lifetime = 0.75
	flames.position = Vector3(0.0, 0.18 * particle_scale, 0.0)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.28 * particle_scale
	flames.direction = Vector3.UP
	flames.spread = 18.0
	flames.gravity = Vector3(0.0, 3.2, 0.0)
	flames.initial_velocity_min = 0.6 * particle_scale
	flames.initial_velocity_max = 1.6 * particle_scale

	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34) * particle_scale
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.4, 0.85, 0.35, 0.85)
	quad.material = mat
	flames.mesh = quad

	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.88, 0.38, 0.95))
	grad.add_point(0.55, Color(1.0, 0.35, 0.08, 0.70))
	grad.add_point(1.0, Color(0.25, 0.05, 0.02, 0.0))
	flames.color_ramp = grad

	target.add_child(flames)
