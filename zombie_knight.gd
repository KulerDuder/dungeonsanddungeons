class_name ZombieKnight
extends EnemyBase

var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _head: Node3D
var _walk_time: float = 0.0
var _is_winding_up_attack: bool = false

func _init() -> void:
	max_health = 3.0
	move_speed = 0.85      # Muy lento al caminar
	turn_speed = 1.8       # Gira pesado por la armadura
	detection_range = 9.0
	attack_range = 1.65    # Algo más de alcance por su espada rota
	attack_damage = 16.0   # Golpe pesado
	attack_cooldown = 2.4  # Tarda bastante entre ataques

func _build_collider() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.45
	col.shape = capsule
	col.position = Vector3(0, 0.725, 0)
	add_child(col)

func _build_visuals() -> void:
	_walk_time = _rng.randf_range(0.0, 10.0)
	var armor_mat := _create_broken_armor_material()
	var zombie_skin_mat := _create_zombie_skin_material()
	var helmet_face_mat := _create_helmet_visor_material()
	var rust_mat := _create_rusty_blade_material()
	
	# 1. Piernas blindadas pesadas
	_left_leg = _create_limb(Vector3(-0.14, 0.42, 0), Vector3(0.15, 0.42, 0.16), armor_mat)
	_right_leg = _create_limb(Vector3(0.14, 0.42, 0), Vector3(0.15, 0.42, 0.16), armor_mat)
	
	# 2. Faldón de armadura y torso ancho con grietas
	_visual_root.add_child(_make_box(Vector3(0.44, 0.14, 0.28), Vector3(0, 0.46, 0), armor_mat))
	_visual_root.add_child(_make_box(Vector3(0.48, 0.38, 0.30), Vector3(0, 0.72, 0), armor_mat))
	
	# Hombrera izquierda intacta, derecha rota/más pequeña
	_visual_root.add_child(_make_box(Vector3(0.18, 0.14, 0.32), Vector3(-0.30, 0.88, 0), armor_mat))
	_visual_root.add_child(_make_box(Vector3(0.12, 0.08, 0.24), Vector3(0.28, 0.85, 0.02), armor_mat))
	
	# 3. Brazo izquierdo (desarmado, con mano zombie verdosa)
	_left_arm = _create_limb(Vector3(-0.31, 0.84, 0), Vector3(0.13, 0.34, 0.13), armor_mat)
	_left_arm.add_child(_make_box(Vector3(0.11, 0.10, 0.11), Vector3(0, -0.37, 0), zombie_skin_mat))
	
	# 4. Brazo derecho con la ESPADA OXIDADA ROTA
	_right_arm = _create_limb(Vector3(0.31, 0.84, 0), Vector3(0.13, 0.34, 0.13), armor_mat)
	_right_arm.add_child(_make_box(Vector3(0.11, 0.10, 0.11), Vector3(0, -0.37, 0), zombie_skin_mat))
	_attach_broken_rusty_sword(_right_arm, rust_mat)
	
	# 5. Yelmo medieval abollado
	_head = Node3D.new()
	_head.position = Vector3(0, 0.93, 0)
	_visual_root.add_child(_head)
	
	var helm_mesh := BoxMesh.new()
	helm_mesh.size = Vector3(0.44, 0.42, 0.44)
	helm_mesh.material = armor_mat
	var helm_inst := MeshInstance3D.new()
	helm_inst.mesh = helm_mesh
	helm_inst.position = Vector3(0, 0.21, 0)
	_head.add_child(helm_inst)
	
	# Visor frontal con ojos zombie brillantes asomando por la rendija
	var visor_plane := QuadMesh.new()
	visor_plane.size = Vector2(0.44, 0.42)
	visor_plane.material = helmet_face_mat
	var visor_inst := MeshInstance3D.new()
	visor_inst.mesh = visor_plane
	visor_inst.position = Vector3(0, 0.21, -0.221)
	visor_inst.rotation.y = PI
	_head.add_child(visor_inst)

func _attach_broken_rusty_sword(arm_pivot: Node3D, rust_mat: StandardMaterial3D) -> void:
	var sword_root := Node3D.new()
	sword_root.position = Vector3(0, -0.36, -0.06)
	sword_root.rotation_degrees = Vector3(-75.0, 0.0, 0.0)
	arm_pivot.add_child(sword_root)
	
	# Empuñadura y guarda oxidada
	sword_root.add_child(_make_box(Vector3(0.05, 0.16, 0.05), Vector3(0, 0.04, 0), rust_mat))
	sword_root.add_child(_make_box(Vector3(0.24, 0.05, 0.07), Vector3(0, 0.14, 0), rust_mat))
	
	# Hoja rota e irregular (escalonada en la punta para que parezca partida)
	sword_root.add_child(_make_box(Vector3(0.11, 0.26, 0.03), Vector3(0, 0.29, 0), rust_mat))
	sword_root.add_child(_make_box(Vector3(0.06, 0.08, 0.03), Vector3(-0.025, 0.45, 0), rust_mat))

func _create_limb(pivot_pos: Vector3, limb_size: Vector3, mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_visual_root.add_child(pivot)
	pivot.add_child(_make_box(limb_size, Vector3(0, -limb_size.y * 0.5, 0), mat))
	return pivot

func _rotate_toward(dir: Vector3, delta: float) -> void:
	if _is_winding_up_attack:
		return
	super._rotate_toward(dir, delta)

func _perform_attack(_target_pos: Vector3) -> void:
	if _is_winding_up_attack or _is_dead:
		return
		
	_is_winding_up_attack = true
	
	# 1. Aviso muy lento y pesado: levanta el brazo derecho con la espada oxidada (0.75 s)
	var windup := create_tween()
	windup.set_parallel(true)
	windup.tween_property(_visual_root, "rotation:x", deg_to_rad(18.0), 0.45)
	windup.tween_property(_right_arm, "rotation:x", deg_to_rad(-155.0), 0.45)
	windup.tween_property(_left_arm, "rotation:x", deg_to_rad(25.0), 0.45)
	
	await get_tree().create_timer(0.75).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	# 2. Espadazo vertical lento hacia abajo
	var strike := create_tween()
	strike.set_parallel(true)
	strike.tween_property(_visual_root, "rotation:x", deg_to_rad(-28.0), 0.16)
	strike.tween_property(_right_arm, "rotation:x", deg_to_rad(-20.0), 0.16)
	
	_check_heavy_sword_hit()
	
	await get_tree().create_timer(0.28).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	# 3. Recuperación pesada
	var recover := create_tween()
	recover.set_parallel(true)
	recover.tween_property(_visual_root, "rotation:x", 0.0, 0.38)
	recover.tween_property(_right_arm, "rotation:x", 0.0, 0.38)
	recover.tween_property(_left_arm, "rotation:x", 0.0, 0.38)
	
	await recover.finished
	if is_instance_valid(self):
		_is_winding_up_attack = false

func _check_heavy_sword_hit() -> void:
	var player_body := _find_player_body()
	if not player_body:
		return
		
	var to_player := player_body.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > attack_range + 0.2 or dist < 0.01:
		return
		
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	# Cono frontal estrecho: si el jugador rodea al caballero mientras levanta la espada, falla
	if forward.dot(to_player.normalized()) >= 0.74:
		var player_root := player_body.get_parent()
		if player_root and player_root.has_method("take_damage"):
			player_root.take_damage(attack_damage, global_position)

func _animate_enemy(delta: float, is_moving: bool) -> void:
	if _is_winding_up_attack:
		return
		
	if is_moving:
		# Cojera marcada de zombie pesado
		_walk_time += delta * 5.2
		var swing := sin(_walk_time) * 0.35
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing * 0.65
		_left_arm.rotation.x = -swing * 0.5
		_right_arm.rotation.x = deg_to_rad(-18.0) + swing * 0.35
		_visual_root.rotation.z = sin(_walk_time) * 0.11
		_head.rotation.z = deg_to_rad(8.0) - sin(_walk_time) * 0.08
	else:
		_walk_time += delta * 1.6
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, delta * 5.0)
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, delta * 5.0)
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.0, delta * 5.0)
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, deg_to_rad(-15.0), delta * 5.0)
		_visual_root.rotation.z = lerpf(_visual_root.rotation.z, 0.0, delta * 5.0)
		_head.rotation.z = deg_to_rad(10.0) + sin(_walk_time) * 0.06

# --- TEXTURAS PIXELADAS PROCEDURALES ---

func _create_broken_armor_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var steel := Color(0.32, 0.34, 0.39)
	var steel_dark := Color(0.20, 0.21, 0.25)
	var rust := Color(0.45, 0.24, 0.14)
	var crack := Color(0.08, 0.08, 0.10)
	var rot_skin := Color(0.33, 0.46, 0.28)
	
	for y in range(16):
		for x in range(16):
			if (x == 6 and y >= 4 and y <= 11) or (x == 7 and y >= 7 and y <= 12):
				# Grieta en la placa por donde asoma carne zombie
				img.set_pixel(x, y, rot_skin if y % 2 == 0 else crack)
			elif (x + y * 3) % 7 == 0:
				img.set_pixel(x, y, rust)
			elif (x + y) % 2 == 0:
				img.set_pixel(x, y, steel)
			else:
				img.set_pixel(x, y, steel_dark)
	return _make_pixel_mat(img, 0.65)

func _create_zombie_skin_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.36, 0.50, 0.30) if (x + y) % 2 == 0 else Color(0.28, 0.40, 0.24))
	return _make_pixel_mat(img, 0.9)

func _create_rusty_blade_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var old_iron := Color(0.38, 0.36, 0.37)
	var rust_orange := Color(0.56, 0.26, 0.12)
	var rust_dark := Color(0.35, 0.16, 0.09)
	for y in range(16):
		for x in range(16):
			if (x * 3 + y) % 4 == 0:
				img.set_pixel(x, y, rust_orange)
			elif (x + y * 2) % 3 == 0:
				img.set_pixel(x, y, rust_dark)
			else:
				img.set_pixel(x, y, old_iron)
	return _make_pixel_mat(img, 0.85)

func _create_helmet_visor_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var steel := Color(0.32, 0.34, 0.39)
	var steel_shade := Color(0.21, 0.22, 0.26)
	var slit := Color(0.06, 0.06, 0.08)
	var eye_glow := Color(0.75, 0.92, 0.30) # Ojos zombie amarillo-verdoso
	
	img.fill(steel)
	for i in range(16):
		img.set_pixel(i, 0, steel_shade)
		img.set_pixel(i, 15, steel_shade)
		img.set_pixel(0, i, steel_shade)
		img.set_pixel(15, i, steel_shade)
		
	# Rendija horizontal del visor con muesca rota
	for x in range(2, 14):
		img.set_pixel(x, 7, slit)
		img.set_pixel(x, 8, slit)
	img.set_pixel(4, 9, slit) # Abolladura en el visor
	
	# Ojos zombie asomando dentro del yelmo
	img.set_pixel(4, 7, eye_glow)
	img.set_pixel(5, 8, eye_glow)
	img.set_pixel(11, 7, eye_glow)
	
	# Respiraderos inferiores del yelmo
	for y in range(11, 14):
		img.set_pixel(4, y, slit)
		img.set_pixel(6, y, slit)
		img.set_pixel(9, y, slit)
		img.set_pixel(11, y, slit)
		
	return _make_pixel_mat(img, 0.65)
