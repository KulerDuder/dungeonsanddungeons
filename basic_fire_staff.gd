class_name BasicFireStaff
extends WeaponBase

@export var max_ammo: int = 10

var _ammo: int = 10
var _pivot: Node3D
var _gem_mesh: MeshInstance3D
var _gem_light: OmniLight3D
var _ammo_label: Label3D
var _cast_anim_timer: float = 0.0
var _pulse_time: float = 0.0

func _init() -> void:
	weapon_name = "Bastón de Fuego Básico (x10)"
	damage = 2.0
	cooldown = 0.44

func _ready() -> void:
	_ammo = max_ammo
	_build_staff_mesh()
	_build_ammo_counter()

func _build_staff_mesh() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	
	var wood_mat := _create_staff_wood_material()
	var gold_mat := _create_gold_crown_material()
	var gem_mat := _create_fire_gem_material()
	
	# Vara de madera oscura tallada
	_add_part(Vector3(0.045, 0.62, 0.045), Vector3(0.0, 0.14, 0.0), wood_mat)
	# Regatón dorado inferior
	_add_part(Vector3(0.056, 0.06, 0.056), Vector3(0.0, -0.18, 0.0), gold_mat)
	# Corona metálica que sujeta la gema en la punta
	_add_part(Vector3(0.075, 0.045, 0.075), Vector3(0.0, 0.46, 0.0), gold_mat)
	_add_part(Vector3(0.024, 0.08, 0.024), Vector3(-0.042, 0.51, 0.0), gold_mat)
	_add_part(Vector3(0.024, 0.08, 0.024), Vector3(0.042, 0.51, 0.0), gold_mat)
	
	# Gema de fuego flotante en la cúspide
	var gem_box := BoxMesh.new()
	gem_box.size = Vector3(0.085, 0.085, 0.085)
	gem_box.material = gem_mat
	_gem_mesh = MeshInstance3D.new()
	_gem_mesh.mesh = gem_box
	_gem_mesh.position = Vector3(0.0, 0.54, 0.0)
	_pivot.add_child(_gem_mesh)
	
	_gem_light = OmniLight3D.new()
	_gem_light.light_color = Color(1.0, 0.48, 0.14)
	_gem_light.light_energy = 1.1
	_gem_light.omni_range = 2.4
	_gem_light.position = Vector3(0.0, 0.54, 0.0)
	_pivot.add_child(_gem_light)
	
	_pivot.rotation_degrees = Vector3(-16.0, 0.0, 0.0)

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
	_ammo_label.position = Vector3(0.0, 0.25, 0.04)
	_ammo_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ammo_label.no_depth_test = true
	_ammo_label.pixel_size = 0.0022
	_ammo_label.font_size = 34
	_ammo_label.outline_size = 8
	_ammo_label.modulate = Color(1.0, 0.68, 0.30)
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
	_cast_anim_timer = 0.24
	_play_fire_cast_sound()
	_spawn_fire_bolt()
	
	# Al gastar la última carga, el bastón se consume y desaparece
	if _ammo <= 0:
		_pivot.visible = false
		_ammo_label.visible = false
		get_tree().create_timer(0.18).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
		)

func _spawn_fire_bolt() -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
		
	var bolt := FireBoltProjectile.new()
	bolt.damage = get_attack_damage()
	bolt.burn_duration = 3.5
	bolt.burn_tick_damage = 1.0
	
	var cam := get_viewport().get_camera_3d()
	if cam:
		bolt.direction = -cam.global_transform.basis.z
		scene_root.add_child(bolt)
		bolt.global_position = _gem_mesh.global_position + (-cam.global_transform.basis.z * 0.28)
	else:
		bolt.direction = -global_transform.basis.z
		scene_root.add_child(bolt)
		bolt.global_position = global_position

func _update_weapon_animation(delta: float) -> void:
	_pulse_time += delta * 4.5
	if _gem_mesh:
		_gem_mesh.rotation.y += delta * 2.8
		_gem_mesh.position.y = 0.54 + sin(_pulse_time) * 0.012
	if _gem_light:
		_gem_light.light_energy = 1.1 + sin(_pulse_time * 1.5) * 0.35
		
	if _cast_anim_timer > 0.0:
		_cast_anim_timer -= delta
		var t := 1.0 - (_cast_anim_timer / 0.24)
		if t < 0.4:
			var f := t / 0.4
			_pivot.position.z = lerpf(0.0, -0.18, f)
			_pivot.rotation_degrees.x = lerpf(-16.0, -48.0, f)
		else:
			var r := (t - 0.4) / 0.6
			_pivot.position.z = lerpf(-0.18, 0.0, r)
			_pivot.rotation_degrees.x = lerpf(-48.0, -16.0, r)
	else:
		_pivot.position = _pivot.position.lerp(Vector3.ZERO, delta * 12.0)
		_pivot.rotation_degrees = _pivot.rotation_degrees.lerp(Vector3(-16.0, 0.0, 0.0), delta * 12.0)

func _play_fire_cast_sound() -> void:
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	audio.stream = gen
	audio.volume_db = -10.0
	add_child(audio)
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * 0.14)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			var freq := lerpf(320.0, 680.0, sin(t * PI * 0.7))
			phase += freq / gen.mix_rate
			var tone := sin(phase * TAU) * 0.6
			var crackle := randf_range(-0.35, 0.35) * (1.0 - t)
			var wave := (tone + crackle) * (1.0 - t) * 0.24
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.24).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

# --- TEXTURAS PIXELADAS ---

func _create_staff_wood_material() -> StandardMaterial3D:
	var img := Image.create(8, 16, false, Image.FORMAT_RGB8)
	var dark_oak := Color(0.32, 0.18, 0.11)
	var grain := Color(0.23, 0.12, 0.07)
	var rune := Color(0.95, 0.45, 0.14)
	for y in range(16):
		for x in range(8):
			if (x == 3 or x == 4) and (y == 4 or y == 11):
				img.set_pixel(x, y, rune)
			elif (x + y) % 3 == 0:
				img.set_pixel(x, y, grain)
			else:
				img.set_pixel(x, y, dark_oak)
	return _to_pixel_mat(img, 0.8)

func _create_gold_crown_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.92, 0.74, 0.24))
	img.set_pixel(2, 2, Color(1.0, 0.95, 0.68))
	return _to_pixel_mat(img, 0.4)

func _create_fire_gem_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(1.0, 0.36, 0.08))
	for y in range(2, 6):
		for x in range(2, 6):
			img.set_pixel(x, y, Color(1.0, 0.85, 0.25))
	var mat := _to_pixel_mat(img, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.10)
	mat.emission_energy_multiplier = 2.2
	return mat

func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
