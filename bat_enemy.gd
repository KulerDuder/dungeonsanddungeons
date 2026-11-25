class_name BatEnemy
extends EnemyBase

var _body_pivot: Node3D
var _left_wing: Node3D
var _right_wing: Node3D
var _head: Node3D
var _mouth_orb: MeshInstance3D

var _is_perched: bool = false
var _state_switch_timer: float = 4.0
var _flap_time: float = 0.0
var _strafe_dir: float = 1.0
var _is_charging_shot: bool = false

const FLY_HEIGHT := 1.45

func _init() -> void:
	max_health = 3.0
	move_speed = 2.7
	turn_speed = 5.0
	detection_range = 12.0
	attack_range = 10.5
	attack_damage = 8.0
	attack_cooldown = 2.3

func _build_collider() -> void:
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.34
	col.shape = sphere
	col.position = Vector3(0.0, 0.35, 0.0)
	add_child(col)

func _build_visuals() -> void:
	_flap_time = _rng.randf_range(0.0, TAU)
	_state_switch_timer = _rng.randf_range(3.5, 6.0)
	_strafe_dir = -1.0 if _rng.randf() < 0.5 else 1.0
	
	var fur_mat := _create_bat_fur_material()
	var wing_mat := _create_wing_membrane_material()
	var face_mat := _create_bat_face_material()
	var ear_inner_mat := _create_ear_inner_material()
	
	_body_pivot = Node3D.new()
	_body_pivot.position = Vector3(0.0, 0.35, 0.0)
	_visual_root.add_child(_body_pivot)
	
	# Torso peludo compacto y patitas
	_body_pivot.add_child(_make_box(Vector3(0.24, 0.26, 0.22), Vector3(0.0, 0.0, 0.0), fur_mat))
	_body_pivot.add_child(_make_box(Vector3(0.05, 0.10, 0.05), Vector3(-0.06, -0.17, 0.02), ear_inner_mat))
	_body_pivot.add_child(_make_box(Vector3(0.05, 0.10, 0.05), Vector3(0.06, -0.17, 0.02), ear_inner_mat))
	
	# Cabeza con orejas puntiagudas y carita pixelada
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.16, -0.02)
	_body_pivot.add_child(_head)
	_head.add_child(_make_box(Vector3(0.28, 0.24, 0.26), Vector3(0.0, 0.08, 0.0), fur_mat))
	
	# Orejas grandes
	_head.add_child(_make_box(Vector3(0.07, 0.15, 0.05), Vector3(-0.09, 0.25, 0.0), fur_mat))
	_head.add_child(_make_box(Vector3(0.04, 0.10, 0.055), Vector3(-0.09, 0.24, -0.005), ear_inner_mat))
	_head.add_child(_make_box(Vector3(0.07, 0.15, 0.05), Vector3(0.09, 0.25, 0.0), fur_mat))
	_head.add_child(_make_box(Vector3(0.04, 0.10, 0.055), Vector3(0.09, 0.24, -0.005), ear_inner_mat))
	
	var face_plane := QuadMesh.new()
	face_plane.size = Vector2(0.28, 0.24)
	face_plane.material = face_mat
	var face_inst := MeshInstance3D.new()
	face_inst.mesh = face_plane
	face_inst.position = Vector3(0.0, 0.08, -0.131)
	face_inst.rotation.y = PI
	_head.add_child(face_inst)
	
	# Orbe sónico en la boca al cargar disparo
	var orb_mesh := BoxMesh.new()
	orb_mesh.size = Vector3(0.11, 0.11, 0.11)
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.82, 0.35, 1.0)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.75, 0.25, 1.0)
	orb_mat.emission_energy_multiplier = 3.0
	orb_mesh.material = orb_mat
	
	_mouth_orb = MeshInstance3D.new()
	_mouth_orb.mesh = orb_mesh
	_mouth_orb.position = Vector3(0.0, 0.03, -0.17)
	_mouth_orb.visible = false
	_head.add_child(_mouth_orb)
	
	# Alas articuladas izquierda y derecha
	_left_wing = _build_wing(-1.0, fur_mat, wing_mat)
	_right_wing = _build_wing(1.0, fur_mat, wing_mat)
	_body_pivot.add_child(_left_wing)
	_body_pivot.add_child(_right_wing)

func _build_wing(side_sign: float, bone_mat: StandardMaterial3D, membrane_mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.12 * side_sign, 0.06, 0.02)
	
	# Brazo superior del ala + membrana interior
	pivot.add_child(_make_box(Vector3(0.26, 0.035, 0.035), Vector3(0.13 * side_sign, 0.04, 0.0), bone_mat))
	pivot.add_child(_make_box(Vector3(0.25, 0.18, 0.015), Vector3(0.13 * side_sign, -0.05, 0.01), membrane_mat))
	
	# Punta exterior del ala + membrana exterior
	var tip := _make_box(Vector3(0.24, 0.03, 0.03), Vector3(0.35 * side_sign, 0.01, -0.02), bone_mat)
	tip.rotation.z = deg_to_rad(-18.0 * side_sign)
	pivot.add_child(tip)
	
	var outer_mem := _make_box(Vector3(0.23, 0.15, 0.015), Vector3(0.34 * side_sign, -0.07, -0.01), membrane_mat)
	outer_mem.rotation.z = deg_to_rad(-18.0 * side_sign)
	pivot.add_child(outer_mem)
	
	return pivot

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
		
	_state_switch_timer -= delta
	if _state_switch_timer <= 0.0 and not _is_charging_shot:
		_is_perched = not _is_perched
		_strafe_dir = -_strafe_dir
		if _is_perched:
			# Se posa en el suelo durante 2.4 - 3.8 segundos
			_state_switch_timer = _rng.randf_range(2.4, 3.8)
		else:
			# Vuelve a levantar el vuelo durante 4.5 - 7.0 segundos
			_state_switch_timer = _rng.randf_range(4.5, 7.0)
			
	if _attack_timer > 0.0:
		_attack_timer -= delta
		
	# Control vertical: cuando vuela mantiene altura; cuando se posa cae por gravedad hasta el suelo
	if _is_perched:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
	else:
		var height_diff := FLY_HEIGHT - global_position.y
		velocity.y = clampf(height_diff * 4.5, -3.5, 4.2)
		
	var player_body := _find_player_body()
	var dist_to_player := INF
	if player_body:
		dist_to_player = global_position.distance_to(player_body.global_position)
		
	if player_body and dist_to_player <= detection_range:
		_ai_combat_behavior(delta, player_body.global_position, dist_to_player)
	else:
		_ai_wander_behavior(delta)
		
	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	_animate_enemy(delta, horizontal_speed > 0.15)

func _ai_wander_behavior(delta: float) -> void:
	if _is_perched:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		return
	super._ai_wander_behavior(delta)

func _ai_combat_behavior(delta: float, target_pos: Vector3, dist: float) -> void:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length() > 0.01:
		to_target = to_target.normalized()
		_rotate_toward(to_target, delta)
		
	if _is_perched:
		# Posado en el suelo no camina, pero sigue girando y disparando
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	else:
		# En el aire se acerca hasta distancia media y revolotea lateralmente
		if dist > attack_range * 0.75:
			velocity.x = to_target.x * move_speed
			velocity.z = to_target.z * move_speed
		elif dist < 3.5:
			# Guarda un poco de distancia si te acercas demasiado
			velocity.x = -to_target.x * (move_speed * 0.7)
			velocity.z = -to_target.z * (move_speed * 0.7)
		else:
			var strafe := Vector3(-to_target.z, 0.0, to_target.x) * _strafe_dir
			velocity.x = strafe.x * (move_speed * 0.75)
			velocity.z = strafe.z * (move_speed * 0.75)
			
	if _attack_timer <= 0.0 and not _is_charging_shot:
		_attack_timer = attack_cooldown
		_perform_attack(target_pos)

func _perform_attack(_target_pos: Vector3) -> void:
	if _is_charging_shot or _is_dead:
		return
		
	_is_charging_shot = true
	_mouth_orb.visible = true
	_mouth_orb.scale = Vector3(0.2, 0.2, 0.2)
	
	# Pequeño aviso antes de disparar (0.45 s)
	var charge_tween := create_tween()
	charge_tween.set_parallel(true)
	charge_tween.tween_property(_mouth_orb, "scale", Vector3(1.15, 1.15, 1.15), 0.42)
	charge_tween.tween_property(_head, "rotation:x", deg_to_rad(18.0), 0.35)
	
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	_mouth_orb.visible = false
	_head.rotation.x = deg_to_rad(-15.0)
	
	var player_body := _find_player_body()
	var aim_pos := global_position + (-global_transform.basis.z * 6.0)
	if player_body:
		aim_pos = player_body.global_position
		
	var mouth_offset := Vector3(0.0, 0.42, 0.0) + (-global_transform.basis.z * 0.25)
	# Lanza bala enemiga morada usando la utilidad nativa de EnemyBase
	shoot_projectile(
		mouth_offset,
		aim_pos,
		8.2,
		Color(0.82, 0.32, 1.0),
		0.22,
		0.0
	)
	
	var recover := create_tween()
	recover.tween_property(_head, "rotation:x", 0.0, 0.22)
	await recover.finished
	if is_instance_valid(self):
		_is_charging_shot = false

func _animate_enemy(delta: float, _is_moving: bool) -> void:
	if _mouth_orb.visible:
		_mouth_orb.rotation += Vector3(6.0, 8.0, 5.0) * delta
		
	if _is_perched and is_on_floor():
		# Posado en el suelo: pliega las alas alrededor del cuerpo y respira suavemente
		_flap_time += delta * 2.5
		_left_wing.rotation.y = lerpf(_left_wing.rotation.y, deg_to_rad(68.0), delta * 8.0)
		_right_wing.rotation.y = lerpf(_right_wing.rotation.y, deg_to_rad(-68.0), delta * 8.0)
		_left_wing.rotation.z = lerpf(_left_wing.rotation.z, deg_to_rad(-28.0), delta * 8.0)
		_right_wing.rotation.z = lerpf(_right_wing.rotation.z, deg_to_rad(28.0), delta * 8.0)
		_body_pivot.position.y = lerpf(_body_pivot.position.y, 0.26 + sin(_flap_time) * 0.012, delta * 8.0)
		_body_pivot.rotation.x = lerpf(_body_pivot.rotation.x, 0.0, delta * 8.0)
	else:
		# Volando: aleteo rápido y balanceo aéreo
		_flap_time += delta * 18.0
		var flap := sin(_flap_time)
		_left_wing.rotation.y = lerpf(_left_wing.rotation.y, 0.0, delta * 10.0)
		_right_wing.rotation.y = lerpf(_right_wing.rotation.y, 0.0, delta * 10.0)
		_left_wing.rotation.z = deg_to_rad(flap * 48.0)
		_right_wing.rotation.z = deg_to_rad(-flap * 48.0)
		_body_pivot.position.y = 0.35 - flap * 0.045
		_body_pivot.rotation.x = lerpf(_body_pivot.rotation.x, deg_to_rad(-14.0), delta * 6.0)

# --- TEXTURAS PIXELADAS ---

func _create_bat_fur_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var fur_dark := Color(0.18, 0.14, 0.24)
	var fur_mid := Color(0.25, 0.20, 0.33)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, fur_mid if (x + y) % 2 == 0 else fur_dark)
	return _make_pixel_mat(img, 0.88)

func _create_wing_membrane_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var mem_a := Color(0.32, 0.18, 0.38)
	var mem_b := Color(0.24, 0.13, 0.29)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, mem_a if (x + y) % 3 != 0 else mem_b)
	return _make_pixel_mat(img, 0.78)

func _create_ear_inner_material() -> StandardMaterial3D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.68, 0.36, 0.48))
	return _make_pixel_mat(img, 0.85)

func _create_bat_face_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color(0.22, 0.17, 0.29))
	# Ojos rojos brillantes
	img.set_pixel(4, 6, Color(1.0, 0.22, 0.25))
	img.set_pixel(5, 6, Color(1.0, 0.65, 0.65))
	img.set_pixel(10, 6, Color(1.0, 0.22, 0.25))
	img.set_pixel(11, 6, Color(1.0, 0.65, 0.65))
	# Hocico rosado
	img.set_pixel(7, 9, Color(0.75, 0.42, 0.52))
	img.set_pixel(8, 9, Color(0.75, 0.42, 0.52))
	# Boquita abierta con dos colmillitos blancos
	for x in range(5, 11):
		img.set_pixel(x, 11, Color(0.10, 0.04, 0.08))
		img.set_pixel(x, 12, Color(0.10, 0.04, 0.08))
	img.set_pixel(5, 11, Color(0.98, 0.96, 0.92))
	img.set_pixel(10, 11, Color(0.98, 0.96, 0.92))
	return _make_pixel_mat(img)
