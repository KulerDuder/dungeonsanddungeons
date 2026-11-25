class_name SkeletonEnemy
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
	move_speed = 1.6
	turn_speed = 3.2 # Giro un poco más lento para que rodearlo sea más gratificante
	detection_range = 8.5
	attack_range = 1.35
	attack_damage = 6.0
	attack_cooldown = 1.55

func _build_collider() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.15
	col.shape = capsule
	col.position = Vector3(0, 0.575, 0)
	add_child(col)

func _build_visuals() -> void:
	_walk_time = _rng.randf_range(0.0, 10.0)
	var bone_mat := _create_bone_material()
	var rib_mat := _create_ribcage_material()
	var face_mat := _create_skull_face_material()
	
	_left_leg = _create_limb(Vector3(-0.11, 0.32, 0), Vector3(0.11, 0.32, 0.11), bone_mat)
	_right_leg = _create_limb(Vector3(0.11, 0.32, 0), Vector3(0.11, 0.32, 0.11), bone_mat)
	
	_visual_root.add_child(_make_box(Vector3(0.32, 0.10, 0.20), Vector3(0, 0.36, 0), bone_mat))
	_visual_root.add_child(_make_box(Vector3(0.34, 0.28, 0.22), Vector3(0, 0.55, 0), rib_mat))
	
	_left_arm = _create_limb(Vector3(-0.23, 0.66, 0), Vector3(0.09, 0.28, 0.09), bone_mat)
	_right_arm = _create_limb(Vector3(0.23, 0.66, 0), Vector3(0.09, 0.28, 0.09), bone_mat)
	
	_head = Node3D.new()
	_head.position = Vector3(0, 0.72, 0)
	_visual_root.add_child(_head)
	_head.add_child(_make_box(Vector3(0.46, 0.42, 0.44), Vector3(0, 0.21, 0), bone_mat))
	
	var face_plane := QuadMesh.new()
	face_plane.size = Vector2(0.46, 0.42)
	face_plane.material = face_mat
	var face_inst := MeshInstance3D.new()
	face_inst.mesh = face_plane
	face_inst.position = Vector3(0, 0.21, -0.221)
	face_inst.rotation.y = PI
	_head.add_child(face_inst)

func _create_limb(pivot_pos: Vector3, limb_size: Vector3, mat: StandardMaterial3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_visual_root.add_child(pivot)
	pivot.add_child(_make_box(limb_size, Vector3(0, -limb_size.y * 0.5, 0), mat))
	return pivot

## Evita que el esqueleto siga girando hacia el jugador mientras prepara el golpe
func _rotate_toward(dir: Vector3, delta: float) -> void:
	if _is_winding_up_attack:
		return
	super._rotate_toward(dir, delta)

func _perform_attack(_target_pos: Vector3) -> void:
	if _is_winding_up_attack or _is_dead:
		return
		
	_is_winding_up_attack = true
	
	# 1. Fase de aviso (wind-up): se echa atrás y levanta los bracitos (0.42 s para esquivar)
	var windup := create_tween()
	windup.set_parallel(true)
	windup.tween_property(_visual_root, "rotation:x", deg_to_rad(22.0), 0.22)
	windup.tween_property(_left_arm, "rotation:x", deg_to_rad(-135.0), 0.22)
	windup.tween_property(_right_arm, "rotation:x", deg_to_rad(-135.0), 0.22)
	
	await get_tree().create_timer(0.42).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	# 2. Fase de golpe hacia adelante en la dirección en la que quedó mirando
	var strike := create_tween()
	strike.set_parallel(true)
	strike.tween_property(_visual_root, "rotation:x", deg_to_rad(-34.0), 0.10)
	strike.tween_property(_left_arm, "rotation:x", deg_to_rad(-35.0), 0.10)
	strike.tween_property(_right_arm, "rotation:x", deg_to_rad(-35.0), 0.10)
	
	_check_frontal_melee_hit()
	
	await get_tree().create_timer(0.14).timeout
	if not is_instance_valid(self) or _is_dead:
		return
		
	# 3. Recuperación de postura
	var recover := create_tween()
	recover.set_parallel(true)
	recover.tween_property(_visual_root, "rotation:x", 0.0, 0.22)
	recover.tween_property(_left_arm, "rotation:x", 0.0, 0.22)
	recover.tween_property(_right_arm, "rotation:x", 0.0, 0.22)
	
	await recover.finished
	if is_instance_valid(self):
		_is_winding_up_attack = false

## Solo acierta si el jugador sigue cerca Y dentro de un cono estrecho frente a su cara
func _check_frontal_melee_hit() -> void:
	var player_body := _find_player_body()
	if not player_body:
		return
		
	var to_player := player_body.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > attack_range + 0.15 or dist < 0.01:
		return
		
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	# Dot > 0.72 equivale a un ángulo de ~44° a cada lado (fácil de esquivar rodeándolo)
	var alignment := forward.dot(to_player.normalized())
	if alignment >= 0.72:
		var player_root := player_body.get_parent()
		if player_root and player_root.has_method("take_damage"):
			player_root.take_damage(attack_damage, global_position)

func _animate_enemy(delta: float, is_moving: bool) -> void:
	if _is_winding_up_attack:
		return
		
	if is_moving:
		_walk_time += delta * 10.0
		var swing := sin(_walk_time) * 0.55
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		_left_arm.rotation.x = -swing * 0.8
		_right_arm.rotation.x = swing * 0.8
		_visual_root.rotation.z = cos(_walk_time) * 0.09
		_head.rotation.z = -cos(_walk_time) * 0.12
		_head.position.y = 0.72 + abs(sin(_walk_time)) * 0.03
	else:
		_walk_time += delta * 2.5
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, delta * 8.0)
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, delta * 8.0)
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.0, delta * 8.0)
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 0.0, delta * 8.0)
		_visual_root.rotation.z = lerpf(_visual_root.rotation.z, 0.0, delta * 8.0)
		_head.rotation.y = sin(_walk_time) * 0.25

func _create_bone_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.91, 0.88, 0.79) if ((x + y) % 3 != 0) else Color(0.82, 0.78, 0.68))
	return _make_pixel_mat(img)

func _create_ribcage_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			var is_bone := (x == 3 or x == 4) or ((y == 1 or y == 3 or y == 5) and x >= 1 and x <= 6)
			img.set_pixel(x, y, Color(0.91, 0.88, 0.79) if is_bone else Color(0.18, 0.16, 0.17))
	return _make_pixel_mat(img)

func _create_skull_face_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color(0.93, 0.90, 0.82))
	for i in range(16):
		img.set_pixel(i, 0, Color(0.76, 0.72, 0.63))
		img.set_pixel(i, 15, Color(0.76, 0.72, 0.63))
		img.set_pixel(0, i, Color(0.76, 0.72, 0.63))
		img.set_pixel(15, i, Color(0.76, 0.72, 0.63))
	for dy in range(3):
		for dx in range(3):
			img.set_pixel(3 + dx, 6 + dy, Color(0.08, 0.07, 0.10))
			img.set_pixel(10 + dx, 6 + dy, Color(0.08, 0.07, 0.10))
	img.set_pixel(4, 6, Color(0.95, 0.98, 1.0))
	img.set_pixel(11, 6, Color(0.95, 0.98, 1.0))
	img.set_pixel(2, 9, Color(0.88, 0.68, 0.66))
	img.set_pixel(13, 9, Color(0.88, 0.68, 0.66))
	img.set_pixel(7, 10, Color(0.08, 0.07, 0.10))
	img.set_pixel(8, 10, Color(0.08, 0.07, 0.10))
	for x in range(5, 11):
		img.set_pixel(x, 12, Color(0.08, 0.07, 0.10))
		if x % 2 == 1:
			img.set_pixel(x, 13, Color(0.08, 0.07, 0.10))
	return _make_pixel_mat(img)
