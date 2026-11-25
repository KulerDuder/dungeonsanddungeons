class_name LoadingCampfire
extends CanvasLayer

var _root_control: Control
var _title_label: Label
var _sub_label: Label

var _skeleton_pivot: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _head: Node3D
var _flames: Array[MeshInstance3D] = []
var _fire_light: OmniLight3D
var _anim_time: float = 0.0
var _is_showing: bool = false

func _ready() -> void:
	layer = 50
	visible = false
	_build_loading_screen()

func _build_loading_screen() -> void:
	_root_control = Control.new()
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_control)
	
	# Fondo oscuro por seguridad
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.05, 1.0)
	_root_control.add_child(bg)
	
	# SubViewport 3D independiente con la habitación pequeña de la hoguera
	var vpc := SubViewportContainer.new()
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.stretch = true
	_root_control.add_child(vpc)
	
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vpc.add_child(vp)
	
	_build_3d_diorama(vp)
	
	# Textos inferiores estilo retro
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	vbox.offset_top = -125
	vbox.offset_bottom = -32
	vbox.add_theme_constant_override("separation", 6)
	_root_control.add_child(vbox)
	
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "¡MAZMORRA DESPEJADA!"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	_title_label.add_theme_constant_override("outline_size", 8)
	_title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.03))
	vbox.add_child(_title_label)
	
	_sub_label = Label.new()
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.text = "Calentando huesos antes de bajar al Piso 2..."
	_sub_label.add_theme_font_size_override("font_size", 20)
	_sub_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82))
	_sub_label.add_theme_constant_override("outline_size", 6)
	_sub_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.03))
	vbox.add_child(_sub_label)

func _build_3d_diorama(vp: SubViewport) -> void:
	var scene := Node3D.new()
	vp.add_child(scene)
	
	# Entorno cálido e íntimo
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.14, 0.16)
	env.ambient_light_energy = 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	
	# Cámara enfocando la habitación pequeña
	var cam := Camera3D.new()
	cam.fov = 52.0
	cam.position = Vector3(0.0, 1.35, 2.55)
	scene.add_child(cam)
	cam.look_at(Vector3(0.0, 0.58, 0.0), Vector3.UP)
	
	# Habitación pequeña de piedra medieval (suelo, pared trasera y pared izquierda)
	var stone_mat := _create_stone_wall_mat()
	var floor_mat := _create_stone_floor_mat()
	
	scene.add_child(_make_box(Vector3(3.4, 0.2, 3.4), Vector3(0, -0.1, 0), floor_mat))
	scene.add_child(_make_box(Vector3(3.4, 2.6, 0.2), Vector3(0, 1.2, -1.4), stone_mat))
	scene.add_child(_make_box(Vector3(0.2, 2.6, 3.4), Vector3(-1.5, 1.2, 0), stone_mat))
	scene.add_child(_make_box(Vector3(0.2, 2.6, 3.4), Vector3(1.5, 1.2, 0), stone_mat))
	
	# Hoguera a la derecha (x = 0.42)
	_build_campfire(scene, Vector3(0.42, 0.0, 0.05))
	
	# Esqueleto mono sentado a la izquierda mirando la hoguera (x = -0.42)
	_build_sitting_skeleton(scene, Vector3(-0.42, 0.0, 0.05))

func _build_campfire(parent: Node3D, pos: Vector3) -> void:
	var fire_root := Node3D.new()
	fire_root.position = pos
	parent.add_child(fire_root)
	
	var log_mat := _create_log_mat()
	var ash_mat := _create_ash_mat()
	
	# Círculo de piedritas y ceniza
	fire_root.add_child(_make_box(Vector3(0.62, 0.04, 0.62), Vector3(0, 0.02, 0), ash_mat))
	for i in range(8):
		var a := (TAU / 8.0) * i
		var stone := _make_box(Vector3(0.12, 0.09, 0.12), Vector3(cos(a) * 0.28, 0.045, sin(a) * 0.28), ash_mat)
		stone.rotation.y = a
		fire_root.add_child(stone)
		
	# Troncos cruzados
	var log1 := _make_box(Vector3(0.44, 0.08, 0.08), Vector3(0, 0.07, 0), log_mat)
	log1.rotation_degrees = Vector3(0, 28, 12)
	fire_root.add_child(log1)
	
	var log2 := _make_box(Vector3(0.44, 0.08, 0.08), Vector3(0, 0.08, 0), log_mat)
	log2.rotation_degrees = Vector3(0, -35, -10)
	fire_root.add_child(log2)
	
	# Llamas pixeladas animadas
	var flame_colors := [
		Color(1.0, 0.35, 0.08),
		Color(1.0, 0.68, 0.12),
		Color(1.0, 0.92, 0.35)
	]
	var flame_sizes := [
		Vector3(0.22, 0.30, 0.22),
		Vector3(0.15, 0.24, 0.15),
		Vector3(0.09, 0.16, 0.09)
	]
	_flames.clear()
	for i in range(3):
		var fm := StandardMaterial3D.new()
		fm.albedo_color = flame_colors[i]
		fm.emission_enabled = true
		fm.emission = flame_colors[i]
		fm.emission_energy_multiplier = 2.4
		var flame := _make_box(flame_sizes[i], Vector3(0, 0.16 + i * 0.04, 0), fm)
		fire_root.add_child(flame)
		_flames.append(flame)
		
	# Luz cálida parpadeante de la hoguera
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.58, 0.22)
	_fire_light.light_energy = 3.2
	_fire_light.omni_range = 4.5
	_fire_light.position = Vector3(0, 0.45, 0)
	fire_root.add_child(_fire_light)

func _build_sitting_skeleton(parent: Node3D, pos: Vector3) -> void:
	_skeleton_pivot = Node3D.new()
	_skeleton_pivot.position = pos
	# Girado hacia la hoguera (hacia +X y un poco hacia cámara para verle la carita)
	_skeleton_pivot.rotation_degrees = Vector3(0, -112.0, 0)
	parent.add_child(_skeleton_pivot)
	
	var bone_mat := _create_bone_mat()
	var rib_mat := _create_rib_mat()
	var face_mat := _create_cute_face_mat()
	
	# Piernitas estiradas hacia adelante (sentado en el suelo)
	var leg_l := _make_box(Vector3(0.10, 0.10, 0.28), Vector3(-0.10, 0.05, -0.14), bone_mat)
	var leg_r := _make_box(Vector3(0.10, 0.10, 0.28), Vector3(0.10, 0.05, -0.14), bone_mat)
	_skeleton_pivot.add_child(leg_l)
	_skeleton_pivot.add_child(leg_r)
	
	# Pelvis y torso sentado bajito
	_skeleton_pivot.add_child(_make_box(Vector3(0.30, 0.09, 0.20), Vector3(0, 0.09, 0), bone_mat))
	_skeleton_pivot.add_child(_make_box(Vector3(0.32, 0.26, 0.20), Vector3(0, 0.27, 0), rib_mat))
	
	# Bracitos extendidos hacia el fuego para calentar las manitas
	_left_arm = Node3D.new()
	_left_arm.position = Vector3(-0.21, 0.37, -0.02)
	_left_arm.rotation_degrees = Vector3(-68.0, -14.0, 0.0)
	_skeleton_pivot.add_child(_left_arm)
	_left_arm.add_child(_make_box(Vector3(0.08, 0.26, 0.08), Vector3(0, -0.13, 0), bone_mat))
	
	_right_arm = Node3D.new()
	_right_arm.position = Vector3(0.21, 0.37, -0.02)
	_right_arm.rotation_degrees = Vector3(-68.0, 14.0, 0.0)
	_skeleton_pivot.add_child(_right_arm)
	_right_arm.add_child(_make_box(Vector3(0.08, 0.26, 0.08), Vector3(0, -0.13, 0), bone_mat))
	
	# Cabeza grande chibi mirando con gusto al fuego
	_head = Node3D.new()
	_head.position = Vector3(0, 0.42, 0)
	_skeleton_pivot.add_child(_head)
	_head.add_child(_make_box(Vector3(0.44, 0.40, 0.42), Vector3(0, 0.20, 0), bone_mat))
	
	var face_plane := QuadMesh.new()
	face_plane.size = Vector2(0.44, 0.40)
	face_plane.material = face_mat
	var face_inst := MeshInstance3D.new()
	face_inst.mesh = face_plane
	face_inst.position = Vector3(0, 0.20, -0.211)
	face_inst.rotation.y = PI
	_head.add_child(face_inst)

func show_transition(next_floor: int, duration: float = 2.6) -> void:
	_title_label.text = "¡MAZMORRA DESPEJADA!"
	_sub_label.text = "El esqueleto calienta sus manitas... Descendiendo al Piso %d" % next_floor
	_is_showing = true
	visible = true
	_root_control.modulate.a = 0.0
	
	var fade_in := create_tween()
	fade_in.tween_property(_root_control, "modulate:a", 1.0, 0.28)
	
	await get_tree().create_timer(duration).timeout
	
	var fade_out := create_tween()
	fade_out.tween_property(_root_control, "modulate:a", 0.0, 0.32)
	await fade_out.finished
	
	visible = false
	_is_showing = false

func _process(delta: float) -> void:
	if not _is_showing:
		return
		
	_anim_time += delta
	
	# Animación del esqueleto frotándose/calentándose las manitas frente al fuego
	if _left_arm and _right_arm:
		var rub := sin(_anim_time * 9.0)
		_left_arm.position.y = 0.37 + rub * 0.015
		_right_arm.position.y = 0.37 - rub * 0.015
		_left_arm.rotation_degrees.x = -68.0 + cos(_anim_time * 4.5) * 4.0
		_right_arm.rotation_degrees.x = -68.0 - cos(_anim_time * 4.5) * 4.0
		
	if _head:
		_head.rotation.z = sin(_anim_time * 2.4) * 0.09
		_head.rotation.x = deg_to_rad(-8.0) + cos(_anim_time * 3.0) * 0.04
		
	# Parpadeo de llamas y luz de la hoguera
	for i in range(_flames.size()):
		var f := _flames[i]
		var flicker := 0.85 + sin(_anim_time * (11.0 + i * 3.0) + i) * 0.22
		f.scale = Vector3(1.0, flicker, 1.0)
		f.rotation.y += delta * (1.8 if i % 2 == 0 else -2.2)
		
	if _fire_light:
		_fire_light.light_energy = 3.1 + sin(_anim_time * 14.0) * 0.45

# --- TEXTURAS PIXELADAS DEL DIORAMA ---

func _make_box(s: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	return inst

func _make_mat(img: Image) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.88
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat

func _create_stone_wall_mat() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in range(16):
		for x in range(16):
			var is_mortar := (y % 4 == 0) or ((x + (2 if (y / 4) % 2 == 1 else 0)) % 8 == 0)
			img.set_pixel(x, y, Color(0.12, 0.11, 0.13) if is_mortar else (Color(0.29, 0.27, 0.30) if (x + y) % 2 == 0 else Color(0.24, 0.23, 0.26)))
	var mat := _make_mat(img)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.6, 0.6, 0.6)
	return mat

func _create_stone_floor_mat() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in range(16):
		for x in range(16):
			img.set_pixel(x, y, Color(0.18, 0.17, 0.20) if (x + y) % 2 == 0 else Color(0.14, 0.14, 0.17))
	var mat := _make_mat(img)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.8, 0.8, 0.8)
	return mat

func _create_log_mat() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.34, 0.19, 0.10) if y % 2 == 0 else Color(0.24, 0.13, 0.07))
	return _make_mat(img)

func _create_ash_mat() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.22, 0.21, 0.23) if (x + y) % 2 == 0 else Color(0.15, 0.14, 0.16))
	return _make_mat(img)

func _create_bone_mat() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.92, 0.88, 0.79) if (x + y) % 3 != 0 else Color(0.83, 0.78, 0.68))
	return _make_mat(img)

func _create_rib_mat() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			var is_bone := (x == 3 or x == 4) or ((y == 1 or y == 3 or y == 5) and x >= 1 and x <= 6)
			img.set_pixel(x, y, Color(0.92, 0.88, 0.79) if is_bone else Color(0.18, 0.15, 0.16))
	return _make_mat(img)

func _create_cute_face_mat() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color(0.94, 0.90, 0.82))
	# Ojitos felices cerrados en arco (^ ^) calentándose al fuego
	img.set_pixel(3, 8, Color(0.1, 0.08, 0.1))
	img.set_pixel(4, 7, Color(0.1, 0.08, 0.1))
	img.set_pixel(5, 8, Color(0.1, 0.08, 0.1))
	img.set_pixel(10, 8, Color(0.1, 0.08, 0.1))
	img.set_pixel(11, 7, Color(0.1, 0.08, 0.1))
	img.set_pixel(12, 8, Color(0.1, 0.08, 0.1))
	# Mofletes cálidos por el fuego
	img.set_pixel(2, 9, Color(0.95, 0.62, 0.55))
	img.set_pixel(13, 9, Color(0.95, 0.62, 0.55))
	# Naricita y sonrisita
	img.set_pixel(7, 10, Color(0.1, 0.08, 0.1))
	img.set_pixel(8, 10, Color(0.1, 0.08, 0.1))
	for x in range(6, 10):
		img.set_pixel(x, 12, Color(0.1, 0.08, 0.1))
	return _make_mat(img)
