class_name BareFists
extends WeaponBase

var _arm_pivot: Node3D
var _fist_root: Node3D
var _thumb_group: Node3D
var _punch_anim_timer: float = 0.0
var _hit_applied: bool = false
var _is_left_hand: bool = false

func _init() -> void:
	weapon_name = "Puñitos"
	damage = 6.0
	cooldown = 0.36

func _ready() -> void:
	_build_realistic_voxel_fist()
	_apply_handedness()

func set_handedness(is_left: bool) -> void:
	_is_left_hand = is_left
	_apply_handedness()

func _apply_handedness() -> void:
	if not _fist_root:
		return
	var sign_x := -1.0 if _is_left_hand else 1.0
	# Postura natural de guardia: los puños apuntan ligeramente hacia el centro
	_fist_root.rotation_degrees = Vector3(12.0, -18.0 * sign_x, 14.0 * sign_x)
	if _thumb_group:
		# El pulgar siempre queda en el lado interior (hacia el centro de la pantalla)
		_thumb_group.scale.x = -1.0 if _is_left_hand else 1.0

func _build_realistic_voxel_fist() -> void:
	_arm_pivot = Node3D.new()
	add_child(_arm_pivot)
	
	_fist_root = Node3D.new()
	_arm_pivot.add_child(_fist_root)
	
	var back_hand_mat := _create_knuckle_back_material()
	var finger_mat := _create_curled_fingers_material()
	var palm_mat := _create_palm_crease_material()
	var wrist_mat := _create_wrist_skin_material()
	
	# 1. Muñeca corta y compacta (sin ropa, solo piel)
	_add_part(_fist_root, Vector3(0.095, 0.085, 0.11), Vector3(0.0, -0.02, 0.09), wrist_mat)
	
	# 2. Dorso de la mano / metacarpo (ancho y corto)
	_add_part(_fist_root, Vector3(0.135, 0.095, 0.115), Vector3(0.0, 0.005, -0.01), back_hand_mat)
	
	# 3. Fila de 4 nudillos marcados en el borde frontal superior
	var knuckle_offsets := [-0.048, -0.016, 0.016, 0.048]
	for kx in knuckle_offsets:
		_add_part(_fist_root, Vector3(0.028, 0.032, 0.035), Vector3(kx, 0.036, -0.072), back_hand_mat)
	
	# 4. Cuatro dedos doblados individualmente con ranuras entre ellos
	var finger_widths := [0.029, 0.031, 0.030, 0.026]
	var finger_heights := [0.068, 0.074, 0.070, 0.060]
	for i in range(4):
		var fx: float = knuckle_offsets[i]
		var fh: float = finger_heights[i]
		# Falange frontal vertical doblada
		_add_part(_fist_root, Vector3(finger_widths[i], fh, 0.036), Vector3(fx, 0.002, -0.082), finger_mat)
		# Punta del dedo metida hacia la palma por debajo
		_add_part(_fist_root, Vector3(finger_widths[i], 0.026, 0.045), Vector3(fx, -0.036, -0.056), palm_mat)
	
	# 5. Almohadilla inferior de la palma (donde se apoyan los dedos cerrados)
	_add_part(_fist_root, Vector3(0.125, 0.042, 0.085), Vector3(0.0, -0.032, -0.015), palm_mat)
	
	# 6. Pulgar doblado cruzando por delante/abajo de los dedos índice y corazón
	_thumb_group = Node3D.new()
	_fist_root.add_child(_thumb_group)
	
	# Base del pulgar en el lateral interior
	_add_part(_thumb_group, Vector3(0.038, 0.045, 0.065), Vector3(-0.074, -0.012, -0.022), wrist_mat)
	# Falange del pulgar doblada cerrando el puño por delante
	var thumb_tip := _add_part(_thumb_group, Vector3(0.075, 0.034, 0.034), Vector3(-0.036, -0.024, -0.088), finger_mat)
	thumb_tip.rotation_degrees = Vector3(0.0, -14.0, -10.0)

func _add_part(parent: Node3D, box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)
	return inst

func _on_attack_start() -> void:
	_punch_anim_timer = 0.24
	_hit_applied = false
	_play_punch_whoosh()

func _update_weapon_animation(delta: float) -> void:
	var sign_x := -1.0 if _is_left_hand else 1.0
	if _punch_anim_timer > 0.0:
		_punch_anim_timer -= delta
		var t := 1.0 - (_punch_anim_timer / 0.24)
		
		if t >= 0.35 and not _hit_applied:
			_hit_applied = true
			_perform_punch_hit()
			
		if t < 0.45:
			var f := t / 0.45
			# Directo hacia el centro de la mira girando ligeramente el puño en horizontal
			_arm_pivot.position.z = lerpf(0.0, -0.36, f)
			_arm_pivot.position.x = lerpf(0.0, -0.10 * sign_x, f)
			_arm_pivot.position.y = lerpf(0.0, 0.05, f)
			_arm_pivot.rotation_degrees.x = lerpf(0.0, -16.0, f)
			_arm_pivot.rotation_degrees.z = lerpf(0.0, 28.0 * sign_x, f)
		else:
			var r := (t - 0.45) / 0.55
			_arm_pivot.position.z = lerpf(-0.36, 0.0, r)
			_arm_pivot.position.x = lerpf(-0.10 * sign_x, 0.0, r)
			_arm_pivot.position.y = lerpf(0.05, 0.0, r)
			_arm_pivot.rotation_degrees.x = lerpf(-16.0, 0.0, r)
			_arm_pivot.rotation_degrees.z = lerpf(28.0 * sign_x, 0.0, r)
	else:
		_arm_pivot.position = _arm_pivot.position.lerp(Vector3.ZERO, delta * 14.0)
		_arm_pivot.rotation_degrees = _arm_pivot.rotation_degrees.lerp(Vector3.ZERO, delta * 14.0)

func _perform_punch_hit() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
		
	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z
	var reach := 1.95
	
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * reach)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var player_body := _find_player_body()
	if player_body:
		query.exclude = [player_body.get_rid()]
		
	var hit := space.intersect_ray(query)
	if hit and hit.has("collider"):
		var target: Object = hit["collider"]
		if target and target.has_method("take_damage"):
			target.take_damage(get_attack_damage(), global_position)
			_play_punch_thud()
			return
			
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	for candidate in _find_damageable_nodes(scene_root):
		if candidate == player_body or (player_body and candidate == player_body.get_parent()):
			continue
		var to_cand := candidate.global_position + Vector3(0, 0.5, 0) - origin
		var dist := to_cand.length()
		if dist <= reach and dist > 0.01:
			if forward.dot(to_cand.normalized()) >= 0.78:
				candidate.take_damage(get_attack_damage(), global_position)
				_play_punch_thud()
				break

func _find_damageable_nodes(root: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in root.get_children():
		if child is Node3D and child.has_method("take_damage"):
			result.append(child)
		result.append_array(_find_damageable_nodes(child))
	return result

func _find_player_body() -> CollisionObject3D:
	var root := get_tree().current_scene
	if not root:
		return null
	return root.find_child("PlayerBody", true, false) as CollisionObject3D

func _play_punch_whoosh() -> void:
	_play_synth_sound(280.0, 110.0, 0.07, -34.0, false)

func _play_punch_thud() -> void:
	_play_synth_sound(160.0, 52.0, 0.10, -30.0, true)

func _play_synth_sound(f_start: float, f_end: float, dur: float, vol_db: float, square: bool) -> void:
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	audio.stream = gen
	audio.volume_db = vol_db
	add_child(audio)
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * dur)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			var freq := lerpf(f_start, f_end, t)
			phase += freq / gen.mix_rate
			var raw := (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) if square else sin(phase * TAU)
			var wave := raw * (1.0 - t) * 0.24
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

# --- TEXTURAS PIXEL-ART ANATÓMICAS (16x16) ---

func _create_knuckle_back_material() -> StandardMaterial3D:
	# Dorso de la mano con luces en los nudillos y sombras cálidas en los bordes
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var skin_base := Color(0.93, 0.72, 0.56)
	var skin_hi := Color(0.99, 0.83, 0.68)
	var skin_shade := Color(0.79, 0.57, 0.42)
	var tendon := Color(0.86, 0.64, 0.48)
	
	for y in range(16):
		for x in range(16):
			if x == 0 or x == 15 or y == 15:
				img.set_pixel(x, y, skin_shade)
			elif y <= 3 and (x % 4 == 1 or x % 4 == 2):
				# Brillo en los 4 nudillos
				img.set_pixel(x, y, skin_hi)
			elif y >= 4 and y <= 10 and (x == 4 or x == 8 or x == 12):
				# Surco sutil de tendones entre nudillos
				img.set_pixel(x, y, tendon)
			elif (x + y) % 4 == 0:
				img.set_pixel(x, y, skin_hi)
			else:
				img.set_pixel(x, y, skin_base)
	return _to_pixel_mat(img, 0.72)

func _create_curled_fingers_material() -> StandardMaterial3D:
	# Falanges dobladas con pliegue articular horizontal en medio y sombra profunda abajo
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var skin_base := Color(0.91, 0.69, 0.53)
	var skin_hi := Color(0.98, 0.80, 0.64)
	var crease := Color(0.64, 0.42, 0.29)
	var deep_shadow := Color(0.50, 0.31, 0.21)
	
	for y in range(16):
		for x in range(16):
			if x == 0 or x == 15:
				img.set_pixel(x, y, crease)
			elif y >= 13:
				img.set_pixel(x, y, deep_shadow)
			elif y == 7 or y == 8:
				# Pliegue de la falange al doblar el dedo
				img.set_pixel(x, y, crease)
			elif y <= 2 or y == 9:
				img.set_pixel(x, y, skin_hi)
			else:
				img.set_pixel(x, y, skin_base)
	return _to_pixel_mat(img, 0.76)

func _create_palm_crease_material() -> StandardMaterial3D:
	# Interior de la palma en sombra cálida con líneas de la mano
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var palm_base := Color(0.76, 0.53, 0.39)
	var palm_line := Color(0.55, 0.35, 0.24)
	for y in range(16):
		for x in range(16):
			if y == 5 or y == 10 or (x == y and x > 3 and x < 12):
				img.set_pixel(x, y, palm_line)
			else:
				img.set_pixel(x, y, palm_base)
	return _to_pixel_mat(img, 0.82)

func _create_wrist_skin_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var skin := Color(0.88, 0.66, 0.50)
	var shade := Color(0.75, 0.53, 0.39)
	for y in range(16):
		for x in range(16):
			if x <= 1 or x >= 14 or y >= 13:
				img.set_pixel(x, y, shade)
			else:
				img.set_pixel(x, y, skin if (x + y) % 3 != 0 else shade)
	return _to_pixel_mat(img, 0.78)

func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
