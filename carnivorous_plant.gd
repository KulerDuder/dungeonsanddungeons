class_name CarnivorousPlant
extends EnemyBase

var _stem_pivot: Node3D
var _head_pivot: Node3D
var _upper_jaw: Node3D
var _lower_jaw: Node3D
var _charge_orb: MeshInstance3D
var _mouth_light: OmniLight3D

var _idle_time: float = 0.0
var _is_charging_shot: bool = false

func _init() -> void:
	max_health = 4.0
	move_speed = 0.0        # Plantada en el sitio, no camina
	turn_speed = 2.6
	detection_range = 13.0  # Detecta a distancia media-larga
	attack_range = 12.5     # Dispara desde lejos
	attack_damage = 10.0
	attack_cooldown = 3.2   # Tarda bastante entre disparos

func _build_collider() -> void:
	var col := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.36
	cylinder.height = 1.35
	col.shape = cylinder
	col.position = Vector3(0, 0.675, 0)
	add_child(col)

func _build_visuals() -> void:
	_idle_time = _rng.randf_range(0.0, 10.0)
	
	var stem_mat := _create_stem_material()
	var leaf_mat := _create_leaf_material()
	var bulb_mat := _create_flower_bulb_material()
	var mouth_inner_mat := _create_mouth_inner_material()
	var tooth_mat := _create_tooth_material()
	
	# 1. Raíces y hojas basales en el suelo
	_visual_root.add_child(_make_box(Vector3(0.46, 0.12, 0.46), Vector3(0, 0.06, 0), stem_mat))
	for i in range(4):
		var leaf_pivot := Node3D.new()
		leaf_pivot.position = Vector3(0, 0.12, 0)
		leaf_pivot.rotation.y = (PI * 0.5) * i + 0.4
		_visual_root.add_child(leaf_pivot)
		
		var leaf := _make_box(Vector3(0.24, 0.05, 0.48), Vector3(0, 0.04, -0.26), leaf_mat)
		leaf.rotation_degrees.x = -18.0
		leaf_pivot.add_child(leaf)
	
	# 2. Tallo articulado que se balancea
	_stem_pivot = Node3D.new()
	_stem_pivot.position = Vector3(0, 0.12, 0)
	_visual_root.add_child(_stem_pivot)
	
	_stem_pivot.add_child(_make_box(Vector3(0.16, 0.55, 0.16), Vector3(0, 0.275, 0), stem_mat))
	# Hojitas laterales en el tallo
	_stem_pivot.add_child(_make_box(Vector3(0.28, 0.04, 0.12), Vector3(-0.16, 0.34, 0), leaf_mat))
	_stem_pivot.add_child(_make_box(Vector3(0.28, 0.04, 0.12), Vector3(0.16, 0.44, 0), leaf_mat))
	
	# 3. Cabeza floral carnívora con mandíbula superior e inferior
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0, 0.58, 0)
	_stem_pivot.add_child(_head_pivot)
	
	# Cáliz verde en la base de la flor
	_head_pivot.add_child(_make_box(Vector3(0.36, 0.16, 0.36), Vector3(0, 0.06, 0), leaf_mat))
	
	# Mandíbula superior (con ojos/manchas y dientecitos)
	_upper_jaw = Node3D.new()
	_upper_jaw.position = Vector3(0, 0.22, 0.14)
	_head_pivot.add_child(_upper_jaw)
	_upper_jaw.add_child(_make_box(Vector3(0.48, 0.22, 0.52), Vector3(0, 0.11, -0.18), bulb_mat))
	_upper_jaw.add_child(_make_box(Vector3(0.40, 0.03, 0.44), Vector3(0, 0.005, -0.18), mouth_inner_mat))
	_add_teeth_row(_upper_jaw, true, tooth_mat)
	
	# Mandíbula inferior
	_lower_jaw = Node3D.new()
	_lower_jaw.position = Vector3(0, 0.20, 0.14)
	_head_pivot.add_child(_lower_jaw)
	_lower_jaw.add_child(_make_box(Vector3(0.44, 0.14, 0.48), Vector3(0, -0.07, -0.17), bulb_mat))
	_lower_jaw.add_child(_make_box(Vector3(0.36, 0.03, 0.40), Vector3(0, -0.005, -0.17), mouth_inner_mat))
	_add_teeth_row(_lower_jaw, false, tooth_mat)
	
	# 4. Orbe de carga luminoso dentro de la boca
	var orb_mesh := BoxMesh.new()
	orb_mesh.size = Vector3(0.18, 0.18, 0.18)
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.45, 1.0, 0.55)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.35, 1.0, 0.45)
	orb_mat.emission_energy_multiplier = 3.0
	orb_mesh.material = orb_mat
	
	_charge_orb = MeshInstance3D.new()
	_charge_orb.mesh = orb_mesh
	_charge_orb.position = Vector3(0, 0.21, -0.14)
	_charge_orb.scale = Vector3(0.01, 0.01, 0.01)
	_charge_orb.visible = false
	_head_pivot.add_child(_charge_orb)
	
	_mouth_light = OmniLight3D.new()
	_mouth_light.light_color = Color(0.4, 1.0, 0.5)
	_mouth_light.light_energy = 0.0
	_mouth_light.omni_range = 3.8
	_mouth_light.position = Vector3(0, 0.22, -0.22)
	_head_pivot.add_child(_mouth_light)

func _add_teeth_row(jaw: Node3D, is_upper: bool, tooth_mat: StandardMaterial3D) -> void:
	var y_pos := -0.03 if is_upper else 0.03
	for x_off in [-0.14, 0.0, 0.14]:
		jaw.add_child(_make_box(Vector3(0.05, 0.06, 0.05), Vector3(x_off, y_pos, -0.39), tooth_mat))
	for z_off in [-0.28, -0.16]:
		jaw.add_child(_make_box(Vector3(0.05, 0.05, 0.05), Vector3(-0.19, y_pos, z_off), tooth_mat))
		jaw.add_child(_make_box(Vector3(0.05, 0.05, 0.05), Vector3(0.19, y_pos, z_off), tooth_mat))

## Sobrescribimos para que nunca intente desplazarse aunque persiga al jugador
func _ai_wander_behavior(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func _ai_combat_behavior(delta: float, target_pos: Vector3, _dist: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	
	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length() > 0.01 and not _is_charging_shot:
		_rotate_toward(to_target.normalized(), delta)
		
	if _attack_timer <= 0.0 and not _is_charging_shot:
		_attack_timer = attack_cooldown
		_perform_attack(target_pos)

func _perform_attack(_target_pos: Vector3) -> void:
	if _is_charging_shot or _is_dead:
		return
		
	_is_charging_shot = true
	_charge_orb.visible = true
	_charge_orb.scale = Vector3(0.05, 0.05, 0.05)
	_mouth_light.light_energy = 0.2
	
	# 1. Fase de carga lenta (1.1 s): abre la boca de par en par y el orbe brillante crece
	var charge_tween := create_tween()
	charge_tween.set_parallel(true)
	charge_tween.tween_property(_stem_pivot, "rotation:x", deg_to_rad(22.0), 0.85).set_trans(Tween.TRANS_SINE)
	charge_tween.tween_property(_upper_jaw, "rotation:x", deg_to_rad(36.0), 0.75)
	charge_tween.tween_property(_lower_jaw, "rotation:x", deg_to_rad(-28.0), 0.75)
	charge_tween.tween_property(_charge_orb, "scale", Vector3(1.15, 1.15, 1.15), 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	charge_tween.tween_property(_mouth_light, "light_energy", 2.8, 1.05)
	
	await get_tree().create_timer(1.1).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	# 2. Disparo: impulsa la cabeza hacia adelante y escupe la bala luminosa lenta
	var shoot_tween := create_tween()
	shoot_tween.set_parallel(true)
	shoot_tween.tween_property(_stem_pivot, "rotation:x", deg_to_rad(-26.0), 0.14).set_trans(Tween.TRANS_BACK)
	shoot_tween.tween_property(_upper_jaw, "rotation:x", deg_to_rad(8.0), 0.14)
	shoot_tween.tween_property(_lower_jaw, "rotation:x", deg_to_rad(-6.0), 0.14)
	
	_charge_orb.visible = false
	_mouth_light.light_energy = 0.0
	
	var player_body := _find_player_body()
	var aim_pos := global_position + (-global_transform.basis.z * 6.0)
	if player_body:
		aim_pos = player_body.global_position
		
	var mouth_offset := Vector3(0, 0.85, 0) + (-global_transform.basis.z * 0.45)
	# Bala luminosa verde esmeralda lenta (6.2 m/s) fácil de ver y esquivar
	shoot_projectile(
		mouth_offset,
		aim_pos,
		6.2,
		Color(0.35, 1.0, 0.52),
		0.28,
		0.0
	)
	
	await get_tree().create_timer(0.22).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	# 3. Recuperación suave
	var recover_tween := create_tween()
	recover_tween.set_parallel(true)
	recover_tween.tween_property(_stem_pivot, "rotation:x", 0.0, 0.45)
	recover_tween.tween_property(_upper_jaw, "rotation:x", 0.0, 0.45)
	recover_tween.tween_property(_lower_jaw, "rotation:x", 0.0, 0.45)
	
	await recover_tween.finished
	if is_instance_valid(self):
		_is_charging_shot = false

func _animate_enemy(delta: float, _is_moving: bool) -> void:
	_idle_time += delta
	if _charge_orb.visible:
		_charge_orb.rotation += Vector3(4.0, 5.0, 3.0) * delta
		
	if _is_charging_shot:
		return
		
	# Balanceo orgánico elegante en reposo y masticación suave de mandíbulas
	_stem_pivot.rotation.z = sin(_idle_time * 2.1) * 0.08
	_stem_pivot.rotation.x = cos(_idle_time * 1.5) * 0.05
	_head_pivot.rotation.z = -sin(_idle_time * 2.1) * 0.06
	
	var chew := maxf(0.0, sin(_idle_time * 3.2))
	_upper_jaw.rotation.x = deg_to_rad(chew * 10.0)
	_lower_jaw.rotation.x = deg_to_rad(-chew * 8.0)

# --- TEXTURAS PIXELADAS PROCEDURALES ---

func _create_stem_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.18, 0.48, 0.20) if (x + y) % 2 == 0 else Color(0.13, 0.36, 0.15))
	return _make_pixel_mat(img, 0.82)

func _create_leaf_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			var vein := (x == 3 or x == 4)
			img.set_pixel(x, y, Color(0.36, 0.72, 0.28) if vein else Color(0.22, 0.56, 0.22))
	return _make_pixel_mat(img, 0.78)

func _create_flower_bulb_material() -> StandardMaterial3D:
	# Bulbo carnívoro magenta/carmesí con motas luminosas estilo planta mágica
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var petal := Color(0.76, 0.16, 0.36)
	var petal_dark := Color(0.56, 0.10, 0.26)
	var spot := Color(0.98, 0.75, 0.85)
	for y in range(16):
		for x in range(16):
			if (x == 4 and y == 4) or (x == 11 and y == 6) or (x == 6 and y == 12) or (x == 12 and y == 11):
				img.set_pixel(x, y, spot)
			elif (x + y) % 2 == 0:
				img.set_pixel(x, y, petal)
			else:
				img.set_pixel(x, y, petal_dark)
	return _make_pixel_mat(img, 0.7)

func _create_mouth_inner_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.32, 0.05, 0.12))
	return _make_pixel_mat(img, 0.9)

func _create_tooth_material() -> StandardMaterial3D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.96, 0.95, 0.88))
	return _make_pixel_mat(img, 0.6)
