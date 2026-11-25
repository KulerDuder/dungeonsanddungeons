class_name WoodenDagger
extends WeaponBase

@export var max_ammo: int = 10

var _ammo: int = 10
var _pivot: Node3D
var _ammo_label: Label3D
var _throw_anim_timer: float = 0.0

func _init() -> void:
	weapon_name = "Dagas de Madera (x10)"
	damage = 15.0
	cooldown = 0.32

func _ready() -> void:
	_ammo = max_ammo
	_build_dagger_mesh()
	_build_ammo_counter()

func _build_dagger_mesh() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	
	var wood_mat := _create_wood_blade_material()
	var grip_mat := _create_leather_grip_material()
	var gold_mat := _create_gold_pommel_material()
	
	# Pomo dorado
	_add_part(Vector3(0.05, 0.045, 0.05), Vector3(0, -0.04, 0), gold_mat)
	# Empuñadura corta
	_add_part(Vector3(0.036, 0.12, 0.036), Vector3(0, 0.04, 0), grip_mat)
	# Guarda pequeña
	_add_part(Vector3(0.14, 0.04, 0.055), Vector3(0, 0.11, 0), wood_mat)
	# Hoja corta y afilada estilo daga cute
	_add_part(Vector3(0.08, 0.24, 0.026), Vector3(0, 0.25, 0), wood_mat)
	_add_part(Vector3(0.05, 0.05, 0.026), Vector3(0, 0.39, 0), wood_mat)
	_add_part(Vector3(0.026, 0.04, 0.026), Vector3(0, 0.43, 0), wood_mat)
	
	# Agarre invertido/listo para lanzar
	_pivot.rotation_degrees = Vector3(-28.0, 0.0, 0.0)

func _add_part(box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	_pivot.add_child(inst)

func _build_ammo_counter() -> void:
	_ammo_label = Label3D.new()
	_ammo_label.position = Vector3(0.0, 0.18, 0.05)
	_ammo_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ammo_label.no_depth_test = true
	_ammo_label.pixel_size = 0.0022
	_ammo_label.font_size = 34
	_ammo_label.outline_size = 8
	_ammo_label.modulate = Color(1.0, 0.93, 0.65)
	_update_ammo_text()
	add_child(_ammo_label)

func _update_ammo_text() -> void:
	if _ammo_label:
		_ammo_label.text = "%d/%d" % [_ammo, max_ammo]

func _on_attack_start() -> void:
	if _ammo <= 0:
		return
		
	_ammo -= 1
	_update_ammo_text()
	_throw_anim_timer = 0.22
	_play_throw_whoosh()
	_spawn_thrown_dagger()
	
	# Si era la última daga, ocultamos la malla y eliminamos el arma del slot tras la animación
	if _ammo <= 0:
		_pivot.visible = false
		_ammo_label.visible = false
		get_tree().create_timer(0.18).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
		)

func _spawn_thrown_dagger() -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
		
	var proj := ThrownDaggerProjectile.new()
	proj.damage = get_attack_damage()
	proj.speed = 22.0
	
	# Apuntamos exactamente hacia donde mira la cámara del jugador
	var cam := get_viewport().get_camera_3d()
	if cam:
		proj.direction = -cam.global_transform.basis.z
		scene_root.add_child(proj)
		proj.global_position = global_position + (-cam.global_transform.basis.z * 0.35)
	else:
		proj.direction = -global_transform.basis.z
		scene_root.add_child(proj)
		proj.global_position = global_position

func _update_weapon_animation(delta: float) -> void:
	if _throw_anim_timer > 0.0:
		_throw_anim_timer -= delta
		# Movimiento rápido de lanzamiento hacia adelante y recarga de la siguiente daga
		var t := 1.0 - (_throw_anim_timer / 0.22)
		if t < 0.45:
			_pivot.position.z = lerpf(0.0, -0.28, t / 0.45)
			_pivot.rotation_degrees.x = lerpf(-28.0, -95.0, t / 0.45)
		else:
			var rec := (t - 0.45) / 0.55
			_pivot.position.z = lerpf(0.12, 0.0, rec)
			_pivot.rotation_degrees.x = lerpf(15.0, -28.0, rec)
	else:
		_pivot.position = _pivot.position.lerp(Vector3.ZERO, delta * 14.0)
		_pivot.rotation_degrees = _pivot.rotation_degrees.lerp(Vector3(-28.0, 0.0, 0.0), delta * 14.0)

func _play_throw_whoosh() -> void:
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	audio.stream = gen
	audio.volume_db = -9.0
	add_child(audio)
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * 0.08)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			var freq := lerpf(520.0, 190.0, t)
			phase += freq / gen.mix_rate
			var wave := sin(phase * TAU) * (1.0 - t) * 0.25
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

# --- TEXTURAS PIXELADAS ---

func _create_wood_blade_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var wood_light := Color(0.83, 0.61, 0.39)
	var wood_mid := Color(0.71, 0.48, 0.28)
	var edge_highlight := Color(0.92, 0.74, 0.52)
	for y in range(16):
		for x in range(16):
			if x == 0 or x == 15:
				img.set_pixel(x, y, edge_highlight)
			elif (x + y) % 3 == 0:
				img.set_pixel(x, y, wood_light)
			else:
				img.set_pixel(x, y, wood_mid)
	return _to_pixel_mat(img, 0.75)

func _create_leather_grip_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.36, 0.20, 0.13) if (y % 2 == 0) else Color(0.27, 0.14, 0.09))
	return _to_pixel_mat(img, 0.85)

func _create_gold_pommel_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.78, 0.26))
	return _to_pixel_mat(img, 0.4)

func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
