class_name DungeonVegetation
extends StaticBody3D

enum Kind {
	FLOOR_FERN,
	FLOOR_MUSHROOMS,
	FLOOR_FLOWERS,
	FLOOR_LUSH_BUSH,
	FLOOR_FLOWERING_BUSH,
	CEILING_VINE,
	CEILING_HANGING_FLOWER
}

var kind: Kind = Kind.FLOOR_FERN
var ceiling_height: float = 4.2

var _sway_pivot: Node3D
var _is_broken: bool = false
var _primary_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D

# Física de bamboleo elástico (cute wobble)
var _sway_angle: Vector2 = Vector2.ZERO
var _sway_vel: Vector2 = Vector2.ZERO
var _idle_phase: float = 0.0
var _rustle_cooldown: float = 0.0

func _ready() -> void:
	_idle_phase = randf_range(0.0, TAU)
	_build_vegetation()
	_build_touch_sensor()

func _build_vegetation() -> void:
	var is_ceiling := (kind == Kind.CEILING_VINE or kind == Kind.CEILING_HANGING_FLOWER)
	var is_bush := (kind == Kind.FLOOR_LUSH_BUSH or kind == Kind.FLOOR_FLOWERING_BUSH)
	
	# Collider fino para recibir golpes de espadas, puños, dagas y fuego sin bloquear el paso
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	if is_bush:
		cyl.radius = 0.52
		cyl.height = 0.95
		col.position = Vector3(0.0, 0.48, 0.0)
	elif is_ceiling:
		cyl.radius = 0.36
		cyl.height = 1.45
		col.position = Vector3(0.0, -0.72, 0.0)
	else:
		cyl.radius = 0.36
		cyl.height = 0.78
		col.position = Vector3(0.0, 0.39, 0.0)
	col.shape = cyl
	add_child(col)
	
	_sway_pivot = Node3D.new()
	add_child(_sway_pivot)
	
	match kind:
		Kind.FLOOR_FERN:
			_build_floor_fern()
		Kind.FLOOR_MUSHROOMS:
			_build_floor_mushrooms()
		Kind.FLOOR_FLOWERS:
			_build_floor_flowers()
		Kind.FLOOR_LUSH_BUSH:
			_build_floor_lush_bush(false)
		Kind.FLOOR_FLOWERING_BUSH:
			_build_floor_lush_bush(true)
		Kind.CEILING_VINE:
			_build_ceiling_vine()
		Kind.CEILING_HANGING_FLOWER:
			_build_ceiling_hanging_flower()

func _build_floor_fern() -> void:
	_primary_mat = _create_leaf_mat(Color(0.18, 0.54, 0.22), Color(0.12, 0.38, 0.15))
	_accent_mat = _create_leaf_mat(Color(0.34, 0.72, 0.28), Color(0.22, 0.52, 0.20))
	
	# Base frondosa
	_add_part(Vector3(0.22, 0.20, 0.22), Vector3(0, 0.10, 0), _primary_mat)
	
	# Corona grande de frondas largas arqueadas
	var blades := randi_range(8, 11)
	for i in range(blades):
		var angle := (TAU / float(blades)) * i + randf_range(-0.18, 0.18)
		var len_b := randf_range(0.48, 0.72)
		var blade := _add_part(Vector3(0.14, 0.04, len_b), Vector3(0, 0.22, 0), _accent_mat if i % 2 == 0 else _primary_mat)
		blade.rotation.y = angle
		blade.rotation.x = deg_to_rad(randf_range(-42.0, -24.0))
		blade.position += Vector3(-sin(angle) * (len_b * 0.44), 0.10, -cos(angle) * (len_b * 0.44))

func _build_floor_mushrooms() -> void:
	var stem_mat := _create_stem_mat()
	var is_glow_blue := randf() < 0.5
	if is_glow_blue:
		_primary_mat = _create_mushroom_cap_mat(Color(0.22, 0.76, 0.98), Color(0.80, 0.98, 1.0), true)
	else:
		_primary_mat = _create_mushroom_cap_mat(Color(0.88, 0.22, 0.28), Color(1.0, 0.94, 0.84), false)
	_accent_mat = stem_mat
	
	# Grupo grande de 3 a 5 setas de jardín mágico
	var count := randi_range(3, 5)
	for i in range(count):
		var scale_f := 1.45 if i == 0 else randf_range(0.75, 1.15)
		var offset := Vector3.ZERO if i == 0 else Vector3(randf_range(-0.28, 0.28), 0.0, randf_range(-0.28, 0.28))
		var h_stem := 0.28 * scale_f
		_add_part(Vector3(0.09 * scale_f, h_stem, 0.09 * scale_f), offset + Vector3(0, h_stem * 0.5, 0), stem_mat)
		_add_part(Vector3(0.30 * scale_f, 0.12 * scale_f, 0.30 * scale_f), offset + Vector3(0, h_stem + 0.05 * scale_f, 0), _primary_mat)
		_add_part(Vector3(0.19 * scale_f, 0.06 * scale_f, 0.19 * scale_f), offset + Vector3(0, h_stem + 0.13 * scale_f, 0), _primary_mat)

func _build_floor_flowers() -> void:
	_primary_mat = _create_leaf_mat(Color(0.20, 0.56, 0.24), Color(0.14, 0.40, 0.17))
	var petal_colors := [
		Color(1.0, 0.84, 0.22),  # Dorado solar
		Color(0.88, 0.48, 0.98), # Lavanda brillante
		Color(1.0, 0.52, 0.68),  # Rosa jardín
		Color(0.42, 0.88, 0.96)  # Campanilla celeste
	]
	_accent_mat = _create_solid_pixel_mat(petal_colors[randi() % petal_colors.size()], 0.65)
	var second_petal := _create_solid_pixel_mat(petal_colors[randi() % petal_colors.size()], 0.65)
	
	# Alfombra densa de hojas basales
	_add_part(Vector3(0.46, 0.06, 0.22), Vector3(0, 0.04, 0), _primary_mat)
	_add_part(Vector3(0.22, 0.06, 0.46), Vector3(0, 0.04, 0), _primary_mat)
	_add_part(Vector3(0.34, 0.08, 0.34), Vector3(0, 0.07, 0), _primary_mat)
	
	# Ramo alto de 5 a 7 flores con pétalos en cruz
	for i in range(randi_range(5, 7)):
		var ox := randf_range(-0.22, 0.22)
		var oz := randf_range(-0.22, 0.22)
		var h := randf_range(0.38, 0.68)
		var mat_p := _accent_mat if i % 2 == 0 else second_petal
		_add_part(Vector3(0.04, h, 0.04), Vector3(ox, h * 0.5, oz), _primary_mat)
		_add_part(Vector3(0.18, 0.045, 0.08), Vector3(ox, h + 0.02, oz), mat_p)
		_add_part(Vector3(0.08, 0.045, 0.18), Vector3(ox, h + 0.02, oz), mat_p)
		_add_part(Vector3(0.07, 0.06, 0.07), Vector3(ox, h + 0.04, oz), _create_solid_pixel_mat(Color(1.0, 0.96, 0.55), 0.5))

func _build_floor_lush_bush(with_blossoms: bool) -> void:
	# Paletas ricas de jardín exuberante
	var foliage_palettes := [
		[Color(0.18, 0.52, 0.22), Color(0.12, 0.36, 0.15), Color(0.30, 0.68, 0.28), Color(0.20, 0.48, 0.18)],
		[Color(0.22, 0.58, 0.26), Color(0.15, 0.42, 0.18), Color(0.38, 0.74, 0.30), Color(0.24, 0.54, 0.22)],
		[Color(0.16, 0.48, 0.28), Color(0.10, 0.34, 0.20), Color(0.26, 0.64, 0.36), Color(0.18, 0.46, 0.26)]
	]
	var pal: Array = foliage_palettes[randi() % foliage_palettes.size()]
	_primary_mat = _create_leaf_mat(pal[0], pal[1])
	var bright_leaf_mat := _create_leaf_mat(pal[2], pal[3])
	
	# Tronquitos leñosos ocultos en la base
	var bark_mat := _create_solid_pixel_mat(Color(0.34, 0.21, 0.12), 0.9)
	_add_part(Vector3(0.22, 0.26, 0.22), Vector3(0.0, 0.13, 0.0), bark_mat)
	
	# Copa principal grande y esponjosa (varios bloques solapados estilo arbusto voxel)
	_add_part(Vector3(0.88, 0.52, 0.84), Vector3(0.0, 0.42, 0.0), _primary_mat)
	_add_part(Vector3(0.68, 0.34, 0.66), Vector3(0.0, 0.72, 0.0), bright_leaf_mat)
	_add_part(Vector3(0.42, 0.22, 0.42), Vector3(0.04, 0.92, -0.03), bright_leaf_mat)
	
	# Bultos laterales asimétricos para que se vea orgánico y mullido
	_add_part(Vector3(0.54, 0.44, 0.52), Vector3(-0.34, 0.34, 0.14), bright_leaf_mat)
	_add_part(Vector3(0.52, 0.42, 0.54), Vector3(0.34, 0.36, -0.12), _primary_mat)
	_add_part(Vector3(0.50, 0.38, 0.50), Vector3(0.10, 0.32, 0.34), bright_leaf_mat)
	_add_part(Vector3(0.48, 0.40, 0.48), Vector3(-0.12, 0.35, -0.34), _primary_mat)
	
	if with_blossoms:
		var blossom_colors := [
			Color(1.0, 0.42, 0.58), # Rosas de jardín
			Color(1.0, 0.82, 0.24), # Flores doradas
			Color(0.85, 0.48, 1.0), # Hortensias lilas
			Color(0.38, 0.92, 0.98)  # Bayas luminosas celestes
		]
		var b_col: Color = blossom_colors[randi() % blossom_colors.size()]
		_accent_mat = _create_glow_blossom_mat(b_col)
		
		var flower_spots := [
			Vector3(-0.38, 0.52, 0.24),
			Vector3(0.36, 0.56, -0.22),
			Vector3(0.14, 0.78, 0.24),
			Vector3(-0.22, 0.74, -0.24),
			Vector3(0.42, 0.38, 0.26),
			Vector3(-0.44, 0.36, -0.18),
			Vector3(0.05, 0.98, 0.06),
			Vector3(0.22, 0.50, 0.40),
			Vector3(-0.18, 0.48, -0.40)
		]
		for spot in flower_spots:
			_add_part(Vector3(0.12, 0.12, 0.12), spot, _accent_mat)
	else:
		_accent_mat = bright_leaf_mat

func _build_ceiling_vine() -> void:
	_primary_mat = _create_leaf_mat(Color(0.18, 0.52, 0.21), Color(0.12, 0.36, 0.14))
	_accent_mat = _create_leaf_mat(Color(0.32, 0.68, 0.28), Color(0.22, 0.50, 0.19))
	
	# Parche de musgo frondoso pegado al techo en la raíz
	_add_part(Vector3(0.46, 0.08, 0.46), Vector3(0, -0.04, 0), _primary_mat)
	
	# Cortina de 2 a 3 lianas largas colgantes
	var strands := randi_range(2, 3)
	for s in range(strands):
		var sx := 0.0 if s == 0 else randf_range(-0.18, 0.18)
		var sz := 0.0 if s == 0 else randf_range(-0.18, 0.18)
		var segments := randi_range(6, 10)
		var seg_h := 0.20
		for i in range(segments):
			var y_pos := -(i + 0.5) * seg_h
			var jitter_x := sx + sin(float(i) * 1.2 + s) * 0.04
			_add_part(Vector3(0.065, seg_h + 0.01, 0.065), Vector3(jitter_x, y_pos, sz), _primary_mat)
			if i % 2 == 0:
				_add_part(Vector3(0.20, 0.05, 0.07), Vector3(jitter_x + 0.09, y_pos, sz), _accent_mat)
			else:
				_add_part(Vector3(0.07, 0.05, 0.20), Vector3(jitter_x, y_pos, sz + 0.09), _accent_mat)

func _build_ceiling_hanging_flower() -> void:
	_primary_mat = _create_leaf_mat(Color(0.20, 0.54, 0.22), Color(0.14, 0.38, 0.16))
	var glow_colors := [
		Color(1.0, 0.58, 0.26), # Farolillo cálido naranja
		Color(0.96, 0.45, 0.85), # Orquídea magenta
		Color(0.36, 0.90, 0.96)  # Campánula azul brillante
	]
	var chosen_col: Color = glow_colors[randi() % glow_colors.size()]
	_accent_mat = _create_mushroom_cap_mat(chosen_col, Color(1.0, 0.95, 0.72), true)
	
	var drop_len := randf_range(0.85, 1.45)
	_add_part(Vector3(0.44, 0.08, 0.44), Vector3(0, -0.04, 0), _primary_mat)
	_add_part(Vector3(0.055, drop_len, 0.055), Vector3(0, -drop_len * 0.5, 0), _primary_mat)
	
	# Hojitas a lo largo del tallo colgante
	_add_part(Vector3(0.22, 0.04, 0.08), Vector3(0.10, -drop_len * 0.35, 0), _primary_mat)
	_add_part(Vector3(0.08, 0.04, 0.22), Vector3(0, -drop_len * 0.65, -0.10), _primary_mat)
	
	# Campánula floral grande y luminosa en la punta
	_add_part(Vector3(0.22, 0.16, 0.22), Vector3(0, -drop_len - 0.06, 0), _accent_mat)
	_add_part(Vector3(0.13, 0.09, 0.13), Vector3(0, -drop_len - 0.17, 0), _accent_mat)

func _add_part(s: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	_sway_pivot.add_child(inst)
	return inst

func _build_touch_sensor() -> void:
	var is_ceiling := (kind == Kind.CEILING_VINE or kind == Kind.CEILING_HANGING_FLOWER)
	var is_bush := (kind == Kind.FLOOR_LUSH_BUSH or kind == Kind.FLOOR_FLOWERING_BUSH)
	
	var area := Area3D.new()
	area.monitoring = true
	area.monitorable = false
	add_child(area)
	
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.72 if is_bush else 0.56
	cyl.height = 2.05 if is_ceiling else 1.15
	col.shape = cyl
	col.position = Vector3(0.0, -1.02 if is_ceiling else 0.58, 0.0)
	area.add_child(col)
	
	area.body_entered.connect(_on_body_touched)

func _on_body_touched(body: Node3D) -> void:
	if _is_broken or body == self or body is StaticBody3D:
		return
		
	var push := (global_position - body.global_position)
	push.y = 0.0
	if push.length() < 0.01:
		push = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	push = push.normalized()
	
	var is_ceiling := (kind == Kind.CEILING_VINE or kind == Kind.CEILING_HANGING_FLOWER)
	var is_bush := (kind == Kind.FLOOR_LUSH_BUSH or kind == Kind.FLOOR_FLOWERING_BUSH)
	var dir_sign := -1.0 if is_ceiling else 1.0
	var impulse := 5.8 if is_bush else 7.8
	
	_sway_vel.x += push.z * impulse * dir_sign
	_sway_vel.y += -push.x * impulse * dir_sign
	
	if _rustle_cooldown <= 0.0:
		_rustle_cooldown = 0.35
		_play_rustle_sound(false)

func _process(delta: float) -> void:
	if _is_broken or not _sway_pivot:
		return
		
	_idle_phase += delta * 2.2
	if _rustle_cooldown > 0.0:
		_rustle_cooldown -= delta
		
	var stiffness := 46.0
	var damping := 5.0
	_sway_vel += (-_sway_angle * stiffness - _sway_vel * damping) * delta
	_sway_angle += _sway_vel * delta
	
	var idle_x := sin(_idle_phase) * 0.032
	var idle_z := cos(_idle_phase * 0.8) * 0.032
	_sway_pivot.rotation.x = clampf(_sway_angle.x + idle_x, -0.62, 0.62)
	_sway_pivot.rotation.z = clampf(_sway_angle.y + idle_z, -0.62, 0.62)

func take_damage(_amount: float, hit_from: Vector3) -> void:
	if _is_broken:
		return
	_is_broken = true
	_play_rustle_sound(true)
	_spawn_leaf_bits(hit_from)
	queue_free()

func _spawn_leaf_bits(hit_from: Vector3) -> void:
	var host := get_parent() if get_parent() else get_tree().current_scene
	if not host:
		return
	var is_ceiling := (kind == Kind.CEILING_VINE or kind == Kind.CEILING_HANGING_FLOWER)
	var is_bush := (kind == Kind.FLOOR_LUSH_BUSH or kind == Kind.FLOOR_FLOWERING_BUSH)
	var origin_offset := Vector3(0, -0.65 if is_ceiling else 0.42, 0)
	var push := (global_position - hit_from)
	push.y = 0.0
	if push.length() > 0.01:
		push = push.normalized()
		
	var piece_count := 10 if is_bush else 7
	for i in range(piece_count):
		var m := BoxMesh.new()
		m.size = Vector3(randf_range(0.07, 0.13), randf_range(0.035, 0.07), randf_range(0.07, 0.13))
		m.material = _accent_mat if (i % 2 == 0 and _accent_mat) else _primary_mat
		var bit := MeshInstance3D.new()
		bit.mesh = m
		host.add_child(bit)
		bit.global_position = global_position + origin_offset + Vector3(randf_range(-0.22, 0.22), randf_range(-0.15, 0.2), randf_range(-0.22, 0.22))
		bit.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		var scatter := Vector3(randf_range(-1.1, 1.1), randf_range(-0.4, 0.8), randf_range(-1.1, 1.1)) + push * 0.75
		var tween := bit.create_tween()
		tween.set_parallel(true)
		tween.tween_property(bit, "global_position", bit.global_position + scatter, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bit, "rotation", bit.rotation + Vector3(5.0, 4.0, 6.0), 0.38)
		tween.tween_property(bit, "scale", Vector3(0.01, 0.01, 0.01), 0.38)
		tween.chain().tween_callback(bit.queue_free)

func _play_rustle_sound(is_break: bool) -> void:
	var host := get_parent() if get_parent() else get_tree().current_scene
	if not host:
		return
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.18
	audio.stream = gen
	audio.volume_db = -17.0 if is_break else -23.0
	host.add_child(audio)
	audio.global_position = global_position
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * (0.12 if is_break else 0.08))
		for i in range(frames):
			var t := float(i) / float(frames)
			var env := sin(t * PI) if not is_break else (1.0 - t)
			var wave := randf_range(-1.0, 1.0) * env * 0.16
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.22).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

# --- TEXTURAS PIXELADAS ---

func _create_leaf_mat(col_a: Color, col_b: Color) -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, col_a if (x + y) % 2 == 0 else col_b)
	return _to_pixel_mat(img, 0.85, false, Color.BLACK)

func _create_stem_mat() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.88, 0.84, 0.74) if (x + y) % 3 != 0 else Color(0.76, 0.71, 0.62))
	return _to_pixel_mat(img, 0.88, false, Color.BLACK)

func _create_mushroom_cap_mat(cap_col: Color, spot_col: Color, glowing: bool) -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(cap_col)
	img.set_pixel(2, 2, spot_col)
	img.set_pixel(5, 3, spot_col)
	img.set_pixel(3, 6, spot_col)
	img.set_pixel(6, 5, spot_col)
	return _to_pixel_mat(img, 0.7, glowing, cap_col)

func _create_glow_blossom_mat(col: Color) -> StandardMaterial3D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(col)
	img.set_pixel(1, 1, Color(1.0, 0.96, 0.82))
	return _to_pixel_mat(img, 0.55, true, col)

func _create_solid_pixel_mat(col: Color, rough: float) -> StandardMaterial3D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(col)
	return _to_pixel_mat(img, rough, false, Color.BLACK)

func _to_pixel_mat(img: Image, rough: float, glow: bool, glow_col: Color) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if glow:
		mat.emission_enabled = true
		mat.emission = glow_col
		mat.emission_energy_multiplier = 1.25
	return mat
