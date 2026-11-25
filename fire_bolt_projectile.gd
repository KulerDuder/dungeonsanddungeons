class_name FireBoltProjectile
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 19.0
var damage: float = 2.0
var burn_duration: float = 3.5
var burn_tick_damage: float = 1.0
var shooter: Node3D = null

var _velocity: Vector3 = Vector3.ZERO
var _core_mesh: MeshInstance3D
var _outer_halo: MeshInstance3D
var _trail_timer: float = 0.0
var _lifetime: float = 3.5

func _ready() -> void:
	_velocity = direction.normalized() * speed
	_build_visual_and_collider()
	body_entered.connect(_on_body_entered)

func _build_visual_and_collider() -> void:
	# Núcleo blanco-dorado incandescente
	var core_box := BoxMesh.new()
	core_box.size = Vector3(0.14, 0.14, 0.14)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.96, 0.72)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.88, 0.45)
	core_mat.emission_energy_multiplier = 3.6
	core_box.material = core_mat
	
	_core_mesh = MeshInstance3D.new()
	_core_mesh.mesh = core_box
	add_child(_core_mesh)
	
	# Aura exterior naranja-rojiza translúcida
	var halo_box := BoxMesh.new()
	halo_box.size = Vector3(0.24, 0.24, 0.24)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(1.0, 0.42, 0.08, 0.65)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(1.0, 0.35, 0.05)
	halo_mat.emission_energy_multiplier = 2.5
	halo_box.material = halo_mat
	
	_outer_halo = MeshInstance3D.new()
	_outer_halo.mesh = halo_box
	add_child(_outer_halo)
	
	# Luz cálida que ilumina los pasillos mientras vuela
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.16)
	light.light_energy = 2.2
	light.omni_range = 4.2
	add_child(light)
	
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	col.shape = sphere
	add_child(col)

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
		
	global_position += _velocity * delta
	if _core_mesh:
		_core_mesh.rotation += Vector3(10.0, 12.0, 8.0) * delta
	if _outer_halo:
		_outer_halo.rotation -= Vector3(7.0, 9.0, 11.0) * delta
		
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.035
		_spawn_trail_spark()

func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	if body.name == "PlayerBody" or (body.get_parent() and body.get_parent().has_method("equip_weapon")):
		return
		
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		# Aplicamos el efecto de quemadura sobre el objetivo (si sigue vivo tras el golpe)
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			StatusEffectManager.apply_burn(body, burn_duration, burn_tick_damage, 0.85)
		_spawn_impact_burst()
		queue_free()
	elif body is StaticBody3D:
		_spawn_impact_burst()
		queue_free()

func _spawn_trail_spark() -> void:
	var host := get_tree().current_scene
	if not host:
		return
	var spark := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.58, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.08)
	mat.emission_energy_multiplier = 2.4
	box.material = mat
	spark.mesh = box
	host.add_child(spark)
	spark.global_position = global_position + Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
	
	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3(0.01, 0.01, 0.01), 0.18)
	tween.tween_callback(spark.queue_free)

func _spawn_impact_burst() -> void:
	var host := get_tree().current_scene
	if not host:
		return
	for i in range(7):
		var spark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.08)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.78, 0.25) if i % 2 == 0 else Color(1.0, 0.35, 0.08)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 2.8
		box.material = mat
		spark.mesh = box
		host.add_child(spark)
		spark.global_position = global_position
		
		var dir := Vector3(randf_range(-1.2, 1.2), randf_range(0.3, 1.4), randf_range(-1.2, 1.2))
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", global_position + dir * 0.45, 0.24)
		tween.tween_property(spark, "scale", Vector3(0.01, 0.01, 0.01), 0.24)
		tween.chain().tween_callback(spark.queue_free)
