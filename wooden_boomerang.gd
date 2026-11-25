class_name WoodenBoomerang
extends WeaponBase

var _pivot: Node3D
var _throw_anim_timer: float = 0.0
var _active_projectile: _BoomerangProjectile = null
var _idle_time: float = 0.0

func _init() -> void:
	weapon_name = "Boomerang de Madera"
	damage = 2.5
	cooldown = 0.35

func _ready() -> void:
	_build_boomerang_mesh()
	_apply_handedness()

func set_handedness(left_slot: bool) -> void:
	is_left_hand = left_slot
	_apply_handedness()

func _apply_handedness() -> void:
	if not _pivot:
		return
	var side_sign := -1.0 if is_left_hand else 1.0
	# Elevado e inclinado hacia delante para que se vea claro en primera persona
	_pivot.position = Vector3(0.0, 0.15, -0.06)
	_pivot.rotation_degrees = Vector3(48.0, -26.0 * side_sign, -32.0 * side_sign)

func _build_boomerang_mesh() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	
	var wood_mat := _create_boomerang_wood_material()
	var stripe_mat := _create_tribal_stripe_material()
	
	# Brazo izquierdo en V abierta (más grueso y visible en mano)
	var arm_a := _make_box(Vector3(0.065, 0.028, 0.28), Vector3(-0.088, 0.0, -0.095), wood_mat)
	arm_a.rotation_degrees = Vector3(0.0, 34.0, 0.0)
	_pivot.add_child(arm_a)
	
	var tip_a := _make_box(Vector3(0.064, 0.030, 0.07), Vector3(-0.158, 0.0, -0.20), stripe_mat)
	tip_a.rotation_degrees = Vector3(0.0, 34.0, 0.0)
	_pivot.add_child(tip_a)
	
	# Brazo derecho en V abierta
	var arm_b := _make_box(Vector3(0.065, 0.028, 0.28), Vector3(0.088, 0.0, -0.095), wood_mat)
	arm_b.rotation_degrees = Vector3(0.0, -34.0, 0.0)
	_pivot.add_child(arm_b)
	
	var tip_b := _make_box(Vector3(0.064, 0.030, 0.07), Vector3(0.158, 0.0, -0.20), stripe_mat)
	tip_b.rotation_degrees = Vector3(0.0, -34.0, 0.0)
	_pivot.add_child(tip_b)
	
	# Codo central reforzado
	_pivot.add_child(_make_box(Vector3(0.095, 0.032, 0.085), Vector3(0.0, 0.0, 0.015), stripe_mat))

func _make_box(s: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	return inst

func _on_attack_start() -> void:
	# Si ya está volando, esperamos a que regrese a la mano
	if is_instance_valid(_active_projectile):
		return
		
	_throw_anim_timer = 0.22
	_play_throw_whoosh()
	_launch_boomerang()

func _launch_boomerang() -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
		
	var proj := _BoomerangProjectile.new()
	proj.damage = get_attack_damage()
	proj.hand_anchor = self
	proj.side_sign = -1.0 if is_left_hand else 1.0
	proj.wood_mat = _create_boomerang_wood_material()
	proj.stripe_mat = _create_tribal_stripe_material()
	
	var cam := get_viewport().get_camera_3d()
	if cam:
		proj.forward_dir = -cam.global_transform.basis.z
		proj.right_dir = cam.global_transform.basis.x
		scene_root.add_child(proj)
		proj.global_position = cam.global_position + (proj.forward_dir * 0.65) + Vector3(0.0, -0.15, 0.0)
	else:
		proj.forward_dir = -global_transform.basis.z
		proj.right_dir = global_transform.basis.x
		scene_root.add_child(proj)
		proj.global_position = global_position
		
	_active_projectile = proj
	_pivot.visible = false
	proj.tree_exited.connect(_on_boomerang_returned)

func _on_boomerang_returned() -> void:
	_active_projectile = null
	if is_instance_valid(_pivot):
		_pivot.visible = true
		_pivot.scale = Vector3(0.35, 0.35, 0.35)
		var catch_tween := create_tween()
		catch_tween.tween_property(_pivot, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_weapon_animation(delta: float) -> void:
	_idle_time += delta * 2.8
	var side_sign := -1.0 if is_left_hand else 1.0
	var base_pos := Vector3(0.0, 0.15, -0.06)
	var base_rot := Vector3(48.0, -26.0 * side_sign, -32.0 * side_sign)
	
	if _throw_anim_timer > 0.0:
		_throw_anim_timer -= delta
		var t := 1.0 - (_throw_anim_timer / 0.22)
		_pivot.position = base_pos + Vector3(0.0, 0.0, lerpf(0.0, -0.25, sin(t * PI)))
		_pivot.rotation_degrees = base_rot + Vector3(lerpf(0.0, -35.0, sin(t * PI)), 0.0, 0.0)
	else:
		var sway := sin(_idle_time) * 3.0
		_pivot.position = _pivot.position.lerp(base_pos, delta * 12.0)
		_pivot.rotation_degrees = _pivot.rotation_degrees.lerp(base_rot + Vector3(0.0, sway, 0.0), delta * 12.0)

func _play_throw_whoosh() -> void:
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	audio.stream = gen
	audio.volume_db = -12.0
	add_child(audio)
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * 0.14)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			var freq := lerpf(240.0, 460.0, sin(t * PI))
			phase += freq / gen.mix_rate
			var wave := sin(phase * TAU) * sin(t * PI) * 0.22
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.24).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

func _create_boomerang_wood_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var wood_a := Color(0.68, 0.44, 0.20)
	var wood_b := Color(0.56, 0.34, 0.14)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, wood_a if (x + y) % 2 == 0 else wood_b)
	return _to_pixel_mat(img, 0.72)

func _create_tribal_stripe_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.88, 0.26, 0.18))
	for x in range(8):
		img.set_pixel(x, 3, Color(0.98, 0.84, 0.32))
		img.set_pixel(x, 4, Color(0.98, 0.84, 0.32))
	return _to_pixel_mat(img, 0.65)

func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


class _BoomerangProjectile extends Area3D:
	var forward_dir: Vector3 = Vector3.FORWARD
	var right_dir: Vector3 = Vector3.RIGHT
	var side_sign: float = 1.0
	var damage: float = 2.5
	var hand_anchor: Node3D = null
	var wood_mat: StandardMaterial3D
	var stripe_mat: StandardMaterial3D
	
	var _spin_pivot: Node3D
	var _returning: bool = false
	var _travelled: float = 0.0
	var _max_distance: float = 8.5
	var _speed: float = 15.5
	var _return_time: float = 0.0
	var _whoosh_timer: float = 0.0
	var _hit_ids: Array[int] = []

	func _ready() -> void:
		forward_dir = forward_dir.normalized()
		right_dir = right_dir.normalized()
		_build_visual_and_collider()
		body_entered.connect(_on_body_entered)

	func _build_visual_and_collider() -> void:
		_spin_pivot = Node3D.new()
		add_child(_spin_pivot)
		
		var arm_a := MeshInstance3D.new()
		var box_a := BoxMesh.new()
		box_a.size = Vector3(0.08, 0.024, 0.34)
		box_a.material = wood_mat
		arm_a.mesh = box_a
		arm_a.position = Vector3(-0.10, 0.0, -0.11)
		arm_a.rotation_degrees = Vector3(0.0, 34.0, 0.0)
		_spin_pivot.add_child(arm_a)
		
		var tip_a := MeshInstance3D.new()
		var box_ta := BoxMesh.new()
		box_ta.size = Vector3(0.078, 0.026, 0.08)
		box_ta.material = stripe_mat
		tip_a.mesh = box_ta
		tip_a.position = Vector3(-0.18, 0.0, -0.23)
		tip_a.rotation_degrees = Vector3(0.0, 34.0, 0.0)
		_spin_pivot.add_child(tip_a)
		
		var arm_b := MeshInstance3D.new()
		var box_b := BoxMesh.new()
		box_b.size = Vector3(0.08, 0.024, 0.34)
		box_b.material = wood_mat
		arm_b.mesh = box_b
		arm_b.position = Vector3(0.10, 0.0, -0.11)
		arm_b.rotation_degrees = Vector3(0.0, -34.0, 0.0)
		_spin_pivot.add_child(arm_b)
		
		var tip_b := MeshInstance3D.new()
		var box_tb := BoxMesh.new()
		box_tb.size = Vector3(0.078, 0.026, 0.08)
		box_tb.material = stripe_mat
		tip_b.mesh = box_tb
		tip_b.position = Vector3(0.18, 0.0, -0.23)
		tip_b.rotation_degrees = Vector3(0.0, -34.0, 0.0)
		_spin_pivot.add_child(tip_b)
		
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.34
		cyl.height = 0.18
		col.shape = cyl
		add_child(col)

	func _physics_process(delta: float) -> void:
		if _spin_pivot:
			_spin_pivot.rotation.y += 26.0 * delta
			
		_whoosh_timer -= delta
		if _whoosh_timer <= 0.0:
			_whoosh_timer = 0.24
			_play_air_spin_tick()
			
		if not _returning:
			var progress := clampf(_travelled / _max_distance, 0.0, 1.0)
			var cur_speed := lerpf(_speed, _speed * 0.45, progress * progress)
			var curve_lateral := right_dir * (cos(progress * PI) * 3.8 * side_sign)
			var step_vec := (forward_dir * cur_speed + curve_lateral) * delta
			global_position += step_vec
			_travelled += cur_speed * delta
			
			if _travelled >= _max_distance:
				_start_return()
		else:
			_return_time += delta
			var target_pos := _get_return_target()
			var to_hand := target_pos - global_position
			var dist := to_hand.length()
			
			if dist <= 0.65 or _return_time >= 3.2:
				queue_free()
				return
				
			var arc_fade := clampf(dist / 5.0, 0.0, 1.0)
			var curve_back := -right_dir * (arc_fade * 3.2 * side_sign)
			var dir := to_hand.normalized()
			var ret_speed := lerpf(13.5, 19.5, clampf(_return_time * 1.4, 0.0, 1.0))
			global_position += (dir * ret_speed + curve_back) * delta

	func _start_return() -> void:
		if _returning:
			return
		_returning = true
		_hit_ids.clear()

	func _get_return_target() -> Vector3:
		if is_instance_valid(hand_anchor):
			return hand_anchor.global_position
		var cam := get_viewport().get_camera_3d()
		if cam:
			return cam.global_position + Vector3(0.0, -0.2, 0.0)
		return global_position

	func _on_body_entered(body: Node3D) -> void:
		if body.name == "PlayerBody" or (body.get_parent() and body.get_parent().has_method("equip_weapon")):
			if _returning:
				queue_free()
			return
			
		if body.has_method("take_damage"):
			var id := body.get_instance_id()
			if not _hit_ids.has(id):
				_hit_ids.append(id)
				body.take_damage(damage, global_position)
		elif body is StaticBody3D:
			if not _returning:
				_start_return()

	func _play_air_spin_tick() -> void:
		var audio := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.12
		audio.stream = gen
		audio.volume_db = -21.0
		add_child(audio)
		audio.play()
		
		var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb:
			var frames := int(gen.mix_rate * 0.07)
			var phase := 0.0
			for i in range(frames):
				var t := float(i) / float(frames)
				phase += lerpf(190.0, 310.0, t) / gen.mix_rate
				var wave := sin(phase * TAU) * sin(t * PI) * 0.18
				pb.push_frame(Vector2(wave, wave))
				
		get_tree().create_timer(0.15).timeout.connect(func() -> void:
			if is_instance_valid(audio):
				audio.queue_free()
		)
