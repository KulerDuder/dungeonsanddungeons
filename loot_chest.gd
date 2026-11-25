class_name LootChest
extends StaticBody3D

## Pool de armas disponibles para este cofre
var weapon_pool: Array[GDScript] = [
	WoodenSword,
	WoodenDagger,
	WoodenShield,
	BasicFireStaff,
	WoodenBoomerang
]

var _lid_pivot: Node3D
var _prompt_label: Label3D
var _is_open: bool = false
var _player_in_range: bool = false
var _offered_weapon: WeaponBase = null
var _float_tween: Tween = null

func _ready() -> void:
	_build_chest_mesh()
	_build_interaction_area()
	_build_prompt_label()

func _build_chest_mesh() -> void:
	var wood_mat := _create_wood_material()
	var iron_mat := _create_iron_material()
	var gold_mat := _create_gold_material()
	
	# Colisión física del cofre
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.1, 0.85, 0.75)
	col.shape = box_shape
	col.position = Vector3(0.0, 0.425, 0.0)
	add_child(col)
	
	# Base del cofre
	var base := _make_box(Vector3(1.06, 0.52, 0.72), Vector3(0.0, 0.26, 0.0), wood_mat)
	add_child(base)
	
	# Bandas metálicas en la base
	add_child(_make_box(Vector3(0.08, 0.54, 0.75), Vector3(-0.38, 0.27, 0.0), iron_mat))
	add_child(_make_box(Vector3(0.08, 0.54, 0.75), Vector3(0.38, 0.27, 0.0), iron_mat))
	
	# Cerradura dorada frontal
	add_child(_make_box(Vector3(0.16, 0.18, 0.06), Vector3(0.0, 0.46, 0.37), gold_mat))
	
	# Pivote trasero de la tapa para abrirse hacia atrás
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0.0, 0.52, -0.36)
	add_child(_lid_pivot)
	
	var lid := _make_box(Vector3(1.08, 0.28, 0.74), Vector3(0.0, 0.14, 0.36), wood_mat)
	_lid_pivot.add_child(lid)
	_lid_pivot.add_child(_make_box(Vector3(0.08, 0.30, 0.76), Vector3(-0.38, 0.15, 0.36), iron_mat))
	_lid_pivot.add_child(_make_box(Vector3(0.08, 0.30, 0.76), Vector3(0.38, 0.15, 0.36), iron_mat))

func _make_box(box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = box_size
	m.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = m
	inst.position = pos
	return inst

func _build_interaction_area() -> void:
	var area := Area3D.new()
	area.monitoring = true
	area.monitorable = false
	add_child(area)
	
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	col.shape = sphere
	col.position = Vector3(0.0, 0.6, 0.0)
	area.add_child(col)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _build_prompt_label() -> void:
	_prompt_label = Label3D.new()
	_prompt_label.text = "[E] Abrir Cofre"
	_prompt_label.position = Vector3(0.0, 1.35, 0.0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.pixel_size = 0.004
	_prompt_label.font_size = 34
	_prompt_label.outline_size = 8
	_prompt_label.modulate = Color(1.0, 0.92, 0.55)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _on_body_entered(body: Node3D) -> void:
	if _is_player_node(body):
		_player_in_range = true
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if _is_player_node(body):
		_player_in_range = false
		_update_prompt()

func _is_player_node(node: Node) -> bool:
	if not node:
		return false
	return node.name == "PlayerBody" or (node.get_parent() and node.get_parent().has_method("equip_weapon"))

func _update_prompt() -> void:
	if not _player_in_range:
		_prompt_label.visible = false
		return
	_prompt_label.visible = true
	if not _is_open:
		_prompt_label.text = "[E] Abrir Cofre"
	elif is_instance_valid(_offered_weapon):
		_prompt_label.text = "%s\n[1] Mano Izq.   [2] Mano Der." % _offered_weapon.weapon_name
	else:
		_prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not _is_open and event.keycode == KEY_E:
			_open_chest()
		elif _is_open and is_instance_valid(_offered_weapon):
			if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				_give_weapon_to_player(true)
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				_give_weapon_to_player(false)

func _open_chest() -> void:
	_is_open = true
	_play_chest_creak()
	
	# Animación suave de apertura de la tapa
	var tween := create_tween()
	tween.tween_property(_lid_pivot, "rotation_degrees:x", -68.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if weapon_pool.is_empty():
		return
	var chosen_script: GDScript = weapon_pool[randi() % weapon_pool.size()]
	_offered_weapon = chosen_script.new() as WeaponBase
	if _offered_weapon:
		_offered_weapon.position = Vector3(0.0, 0.85, 0.0)
		_offered_weapon.rotation_degrees = Vector3(0.0, 0.0, -35.0)
		add_child(_offered_weapon)
		
		# Guardamos el tween de flotación para poder matarlo al recoger el arma
		_float_tween = create_tween().set_loops()
		_float_tween.tween_property(_offered_weapon, "position:y", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		_float_tween.tween_property(_offered_weapon, "position:y", 0.82, 0.8).set_trans(Tween.TRANS_SINE)
		
	_update_prompt()

func _process(delta: float) -> void:
	if _is_open and is_instance_valid(_offered_weapon):
		_offered_weapon.rotation.y += delta * 1.8

func _give_weapon_to_player(left_hand: bool) -> void:
	var player := _find_player_root()
	if not player or not is_instance_valid(_offered_weapon):
		return
		
	# IMPORTANTE: Matamos el tween del cofre para que no siga moviendo position.y en tu mano
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null
		
	var weapon_to_equip := _offered_weapon
	_offered_weapon = null
	remove_child(weapon_to_equip)
	
	weapon_to_equip.position = Vector3.ZERO
	weapon_to_equip.rotation = Vector3.ZERO
	weapon_to_equip.scale = Vector3.ONE
	
	player.equip_weapon(weapon_to_equip, left_hand)
	_update_prompt()

func _find_player_root() -> Node:
	var root := get_tree().current_scene
	if not root:
		return null
	return _search_equipper(root)

func _search_equipper(node: Node) -> Node:
	if node.has_method("equip_weapon"):
		return node
	for child in node.get_children():
		var found := _search_equipper(child)
		if found:
			return found
	return null

func _play_chest_creak() -> void:
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	audio.stream = gen
	audio.volume_db = -10.0
	add_child(audio)
	audio.global_position = global_position + Vector3(0, 0.6, 0)
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * 0.16)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			phase += lerpf(160.0, 290.0, t) / gen.mix_rate
			var wave := sin(phase * TAU) * (1.0 - t) * 0.22
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

func _create_wood_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var base := Color(0.42, 0.25, 0.13)
	var dark := Color(0.28, 0.16, 0.08)
	for y in range(16):
		for x in range(16):
			img.set_pixel(x, y, dark if y % 4 == 0 else base)
	return _to_pixel_mat(img, 0.85)

func _create_iron_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.24, 0.26, 0.30))
	return _to_pixel_mat(img, 0.6)

func _create_gold_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.78, 0.22))
	return _to_pixel_mat(img, 0.4)

func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
