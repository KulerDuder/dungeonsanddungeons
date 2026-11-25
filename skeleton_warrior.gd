class_name SkeletonWarrior
extends EnemyBase

var _pelvis: Node3D
var _torso: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _axe_blade_mat: StandardMaterial3D

var _walk_time: float = 0.0
var _is_attacking: bool = false
var _strafe_dir: float = 1.0
var _strafe_timer: float = 1.5
var _locked_attack_dir: Vector3 = Vector3.FORWARD

func _init() -> void:
	max_health = 8.5
	move_speed = 2.45
	turn_speed = 5.2
	detection_range = 11.5
	attack_range = 2.25
	attack_damage = 16.0
	attack_cooldown = 2.05

func _build_collider() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 2.25
	col.shape = cap
	col.position = Vector3(0.0, 1.12, 0.0)
	add_child(col)

func _build_visuals() -> void:
	_strafe_dir = -1.0 if _rng.randf() < 0.5 else 1.0
	_strafe_timer = _rng.randf_range(1.1, 2.2)
	
	# Más grande e imponente que el esqueleto normal
	_visual_root.scale = Vector3(1.32, 1.32, 1.32)
	
	var bone_mat := _create_aged_bone_material()
	var armor_mat := _create_dark_iron_material()
	var skull_mat := _create_warrior_skull_material()
	var wood_mat := _create_haft_wood_material()
	_axe_blade_mat = _create_axe_steel_material()
	
	# Pelvis con faldón de hierro
	_pelvis = Node3D.new()
	_pelvis.position = Vector3(0.0, 0.88, 0.0)
	_visual_root.add_child(_pelvis)
	_pelvis.add_child(_make_box(Vector3(0.36, 0.14, 0.22), Vector3.ZERO, armor_mat))
	
	# Piernas
	_left_leg = _build_leg(-0.11, bone_mat, armor_mat)
	_right_leg = _build_leg(0.11, bone_mat, armor_mat)
	_pelvis.add_child(_left_leg)
	_pelvis.add_child(_right_leg)
	
	# Torso con coraza oscura y hombreras
	_torso = Node3D.new()
	_torso.position = Vector3(0.0, 0.08, 0.0)
	_pelvis.add_child(_torso)
	_torso.add_child(_make_box(Vector3(0.10, 0.46, 0.10), Vector3(0.0, 0.23, 0.04), bone_mat))
	_torso.add_child(_make_box(Vector3(0.38, 0.36, 0.24), Vector3(0.0, 0.28, -0.01), armor_mat))
	
	# Hombreras reforzadas
	_torso.add_child(_make_box(Vector3(0.18, 0.14, 0.26), Vector3(-0.25, 0.43, 0.0), armor_mat))
	_torso.add_child(_make_box(Vector3(0.18, 0.14, 0.26), Vector3(0.25, 0.43, 0.0), armor_mat))
	
	# Cráneo con yelmo vikingo/medieval
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.52, 0.0)
	_torso.add_child(_head)
	_head.add_child(_make_box(Vector3(0.28, 0.28, 0.28), Vector3(0.0, 0.14, 0.0), bone_mat))
	# Casco superior y cuernos laterales
	_head.add_child(_make_box(Vector3(0.31, 0.11, 0.31), Vector3(0.0, 0.25, 0.0), armor_mat))
	_head.add_child(_make_box(Vector3(0.09, 0.12, 0.06), Vector3(-0.19, 0.29, 0.0), bone_mat))
	_head.add_child(_make_box(Vector3(0.09, 0.12, 0.06), Vector3(0.19, 0.29, 0.0), bone_mat))
	
	var face_quad := QuadMesh.new()
	face_quad.size = Vector2(0.28, 0.28)
	face_quad.material = skull_mat
	var face_inst := MeshInstance3D.new()
	face_inst.mesh = face_quad
	face_inst.position = Vector3(0.0, 0.14, -0.141)
	face_inst.rotation.y = PI
	_head.add_child(face_inst)
	
	# Brazo izquierdo con broquel redondo de hierro
	_left_arm = _build_arm(-0.26, bone_mat)
	_torso.add_child(_left_arm)
	_left_arm.add_child(_make_box(Vector3(0.05, 0.28, 0.28), Vector3(-0.06, -0.34, -0.05), armor_mat))
	
	# Brazo derecho con GRAN HACHA DE BATALLA
	_right_arm = _build_arm(0.26, bone_mat)
	_torso.add_child(_right_arm)
	
	var axe_pivot := Node3D.new()
	axe_pivot.position = Vector3(0.0, -0.42, -0.04)
	_right_arm.add_child(axe_pivot)
	
	# Mango largo del hacha
	axe_pivot.add_child(_make_box(Vector3(0.045, 0.045, 0.92), Vector3(0.0, 0.0, -0.34), wood_mat))
	# Cabeza central del hacha
	axe_pivot.add_child(_make_box(Vector3(0.07, 0.11, 0.14), Vector3(0.0, 0.0, -0.68), armor_mat))
	# Hoja curva grande de doble filo
	axe_pivot.add_child(_make_box(Vector3(0.032, 0.34, 0.24), Vector3(0.0, 0.06, -0.72), _axe_blade_mat))
	axe_pivot.add_child(_make_box(Vector3(0.024, 0.42, 0.10), Vector3(0.0, 0.06, -0.82), _axe_blade_mat))
	
	_right_arm.rotation_degrees = Vector3(-28.0, 0.0, -8.0)

func _build_leg(offset_x: float, bone_mat: StandardMaterial3D, armor_mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(offset_x, 0.0, 0.0)
	pivot.add_child(_make_box(Vector3(0.09, 0.42, 0.09), Vector3(0.0, -0.21, 0.0), bone_mat))
	pivot.add_child(_make_box(Vector3(0.11, 0.12, 0.12), Vector3(0.0, -0.44, 0.0), armor_mat))
	pivot.add_child(_make_box(Vector3(0.08, 0.38, 0.08), Vector3(0.0, -0.66, 0.0), bone_mat))
	pivot.add_child(_make_box(Vector3(0.11, 0.07, 0.20), Vector3(0.0, -0.85, -0.04), armor_mat))
	return pivot

func _build_arm(offset_x: float, bone_mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(offset_x, 0.40, 0.0)
	pivot.add_child(_make_box(Vector3(0.085, 0.46, 0.085), Vector3(0.0, -0.23, 0.0), bone_mat))
	return pivot

func _ai_combat_behavior(delta: float, target_pos: Vector3, dist: float) -> void:
	if _is_attacking:
		# Durante el hachazo no sigue girando libremente: así el jugador puede esquivarlo lateralmente
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		return
		
	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length() > 0.01:
		to_target = to_target.normalized()
		_rotate_toward(to_target, delta)
		
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_dir = -_strafe_dir
		_strafe_timer = _rng.randf_range(0.9, 1.8)
		
	if dist > attack_range:
		# Se acerca con un leve zig-zag táctico (más hábil que el esqueleto básico)
		var strafe_vec := Vector3(-to_target.z, 0.0, to_target.x) * _strafe_dir
		var advance := (to_target + strafe_vec * 0.42).normalized()
		velocity.x = advance.x * move_speed
		velocity.z = advance.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_attack(target_pos)

func _perform_attack(target_pos: Vector3) -> void:
	if _is_attacking or _is_dead:
		return
	_is_attacking = true
	
	# Fijamos la dirección del golpe al iniciar la carga para que pueda esquivarse moviéndose a un lado
	var aim := target_pos - global_position
	aim.y = 0.0
	if aim.length() > 0.01:
		_locked_attack_dir = aim.normalized()
	else:
		_locked_attack_dir = -global_transform.basis.z
		
	# 1. Fase de aviso (0.62 s): levanta el hacha bien alto hacia atrás y brilla el acero
	if _axe_blade_mat:
		_axe_blade_mat.emission_enabled = true
		_axe_blade_mat.emission = Color(1.0, 0.55, 0.22)
		_axe_blade_mat.emission_energy_multiplier = 1.6
		
	var windup := create_tween()
	windup.set_parallel(true)
	windup.tween_property(_right_arm, "rotation_degrees", Vector3(-148.0, 12.0, -16.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	windup.tween_property(_torso, "rotation_degrees:x", 16.0, 0.55)
	windup.tween_property(_left_arm, "rotation_degrees:x", 24.0, 0.55)
	await windup.finished
	if not is_instance_valid(self) or _is_dead:
		return
		
	# Pequeña pausa dramática en lo alto antes de bajar el hacha
	await get_tree().create_timer(0.10).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	# 2. Golpe descendente pesado con pequeño paso hacia delante en la dirección fijada
	velocity.x = _locked_attack_dir.x * 4.2
	velocity.z = _locked_attack_dir.z * 4.2
	
	var slam := create_tween()
	slam.set_parallel(true)
	slam.tween_property(_right_arm, "rotation_degrees", Vector3(36.0, -8.0, 6.0), 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	slam.tween_property(_torso, "rotation_degrees:x", -24.0, 0.14)
	slam.tween_property(_left_arm, "rotation_degrees:x", -30.0, 0.14)
	await slam.finished
	if not is_instance_valid(self) or _is_dead:
		return
		
	if _axe_blade_mat:
		_axe_blade_mat.emission_enabled = false
		
	# Comprobación estricta del cono frontal fijado: si te apartaste, ¡esquivado!
	var player_body := _find_player_body()
	if player_body:
		var to_player := player_body.global_position - global_position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist <= attack_range + 0.45 and dist > 0.01:
			var forward_dot := _locked_attack_dir.dot(to_player.normalized())
			if forward_dot >= 0.72:
				var player_root := player_body.get_parent()
				if player_root and player_root.has_method("take_damage"):
					player_root.take_damage(attack_damage, global_position)
					
	# 3. Recuperación tras clavar el hacha (ventana extra para contraatacar)
	await get_tree().create_timer(0.28).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	var recover := create_tween()
	recover.set_parallel(true)
	recover.tween_property(_right_arm, "rotation_degrees", Vector3(-28.0, 0.0, -8.0), 0.28)
	recover.tween_property(_torso, "rotation_degrees:x", 0.0, 0.28)
	recover.tween_property(_left_arm, "rotation_degrees:x", 0.0, 0.28)
	await recover.finished
	if is_instance_valid(self):
		_is_attacking = false

func _animate_enemy(delta: float, is_moving: bool) -> void:
	if _is_attacking:
		return
		
	if is_moving:
		_walk_time += delta * 9.5
		var swing := sin(_walk_time) * 0.62
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		_left_arm.rotation.x = -swing * 0.55
		_right_arm.rotation.x = deg_to_rad(-28.0) + swing * 0.35
		_pelvis.position.y = 0.88 + absf(cos(_walk_time)) * 0.05
		_torso.rotation.z = sin(_walk_time * 0.5) * 0.07
	else:
		_walk_time += delta * 2.2
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, delta * 10.0)
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, delta * 10.0)
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, sin(_walk_time) * 0.08, delta * 8.0)
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, deg_to_rad(-28.0) - sin(_walk_time) * 0.08, delta * 8.0)
		_pelvis.position.y = lerpf(_pelvis.position.y, 0.88, delta * 10.0)
		_torso.rotation.z = lerpf(_torso.rotation.z, 0.0, delta * 10.0)

# --- TEXTURAS PIXELADAS ---

func _create_aged_bone_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var b1 := Color(0.84, 0.79, 0.68)
	var b2 := Color(0.71, 0.65, 0.55)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, b1 if (x + y) % 2 == 0 else b2)
	return _make_pixel_mat(img, 0.85)

func _create_dark_iron_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var iron := Color(0.22, 0.24, 0.28)
	var rust := Color(0.36, 0.23, 0.17)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, rust if (x * 3 + y) % 5 == 0 else iron)
	return _make_pixel_mat(img, 0.58)

func _create_haft_wood_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.36, 0.20, 0.11))
	return _make_pixel_mat(img, 0.85)

func _create_axe_steel_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var steel := Color(0.62, 0.66, 0.72)
	var edge := Color(0.88, 0.91, 0.96)
	img.fill(steel)
	for y in range(8):
		img.set_pixel(0, y, edge)
		img.set_pixel(7, y, edge)
	return _make_pixel_mat(img, 0.35)

func _create_warrior_skull_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color(0.82, 0.77, 0.66))
	# Ceño fruncido agresivo
	for x in range(3, 7):
		img.set_pixel(x, 5, Color(0.15, 0.12, 0.10))
	for x in range(9, 13):
		img.set_pixel(x, 5, Color(0.15, 0.12, 0.10))
	# Cuencas oculares con brillo naranja ámbar
	for y in range(6, 9):
		for x in range(3, 7):
			img.set_pixel(x, y, Color(0.08, 0.06, 0.06))
		for x in range(9, 13):
			img.set_pixel(x, y, Color(0.08, 0.06, 0.06))
	img.set_pixel(5, 7, Color(1.0, 0.45, 0.12))
	img.set_pixel(10, 7, Color(1.0, 0.45, 0.12))
	# Nariz y dientes
	img.set_pixel(7, 10, Color(0.15, 0.12, 0.10))
	img.set_pixel(8, 10, Color(0.15, 0.12, 0.10))
	for x in range(4, 12):
		img.set_pixel(x, 13, Color(0.15, 0.12, 0.10) if x % 2 == 0 else Color(0.95, 0.92, 0.85))
	return _make_pixel_mat(img)
