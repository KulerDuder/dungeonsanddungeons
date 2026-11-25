class_name BareFists
extends WeaponBase

var _arm_pivot: Node3D
var _thumb_mesh: MeshInstance3D
var _punch_anim_timer: float = 0.0
var _hit_applied: bool = false
var _is_left_hand: bool = false

func _init() -> void:
	weapon_name = "Puñitos"
	damage = 6.0
	cooldown = 0.36

func _ready() -> void:
	_build_cute_fist_mesh()
	_apply_handedness()

func set_handedness(is_left: bool) -> void:
	_is_left_hand = is_left
	_apply_handedness()

func _apply_handedness() -> void:
	if _thumb_mesh:
		# Pulgar apuntando hacia el centro de la pantalla en cada mano
		_thumb_mesh.position.x = 0.042 if _is_left_hand else -0.042

func _build_cute_fist_mesh() -> void:
	_arm_pivot = Node3D.new()
	add_child(_arm_pivot)
	
	var skin_mat := _create_skin_material()
	var sleeve_mat := _create_sleeve_material()
	var cuff_mat := _create_cuff_material()
	
	# Manga de túnica atrás
	_add_part(Vector3(0.11, 0.11, 0.18), Vector3(0.0, 0.0, 0.14), sleeve_mat)
	# Puño de manga/brazalete
	_add_part(Vector3(0.12, 0.12, 0.05), Vector3(0.0, 0.0, 0.03), cuff_mat)
	# Antebrazo/muñeca mono
	_add_part(Vector3(0.095, 0.095, 0.08), Vector3(0.0, 0.0, -0.03), skin_mat)
	# Puñito cerrado redondeado (bloque principal + nudillos frontales + pulgar)
	_add_part(Vector3(0.13, 0.12, 0.13), Vector3(0.0, 0.005, -0.12), skin_mat)
	_add_part(Vector3(0.11, 0.09, 0.04), Vector3(0.0, 0.01, -0.19), skin_mat)
	_thumb_mesh = _add_part(Vector3(0.045, 0.055, 0.07), Vector3(-0.042, 0.075, -0.11), skin_mat)

func _add_part(box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	_arm_pivot.add_child(inst)
	return inst

func _on_attack_start() -> void:
	_punch_anim_timer = 0.24
	_hit_applied = false
	_play_punch_whoosh()

func _update_weapon_animation(delta: float) -> void:
	if _punch_anim_timer > 0.0:
		_punch_anim_timer -= delta
		var t := 1.0 - (_punch_anim_timer / 0.24)
		
		# Ejecutamos el impacto en el punto máximo del puñetazo
		if t >= 0.35 and not _hit_applied:
			_hit_applied = true
			_perform_punch_hit()
			
		if t < 0.45:
			var f := t / 0.45
			_arm_pivot.position.z = lerpf(0.0, -0.34, f)
			_arm_pivot.position.y = lerpf(0.0, 0.04, f)
			_arm_pivot.rotation_degrees.x = lerpf(0.0, -14.0, f)
		else:
			var r := (t - 0.45) / 0.55
			_arm_pivot.position.z = lerpf(-0.34, 0.0, r)
			_arm_pivot.position.y = lerpf(0.04, 0.0, r)
			_arm_pivot.rotation_degrees.x = lerpf(-14.0, 0.0, r)
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
	
	# Comprobación por raycast directo frente a la cámara (muy preciso para enemigos y jarrones)
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
			
	# Respaldo en cono corto cuerpo a cuerpo por si el objetivo está ligeramente descentrado
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
	_play_synth_sound(280.0, 110.0, 0.07, -14.0, false)

func _play_punch_thud() -> void:
	_play_synth_sound(160.0, 52.0, 0.10, -10.0, true)

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

# --- TEXTURAS PIXELADAS ---

func _create_skin_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var base := Color(0.96, 0.77, 0.62)
	var shade := Color(0.88, 0.67, 0.52)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, base if (x + y) % 3 != 0 else shade)
	return _to_pixel_mat(img, 0.75)

func _create_sleeve_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var cloth := Color(0.24, 0.36, 0.58)
	var cloth_dark := Color(0.18, 0.27, 0.45)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, cloth if (x + y) % 2 == 0 else cloth_dark)
	return _to_pixel_mat(img, 0.88)

func _create_cuff_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.84, 0.68, 0.34))
	return _to_pixel_mat(img, 0.6)

func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
