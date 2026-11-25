class_name WoodenSword
extends WeaponBase

var _pivot: Node3D
var _hitbox: Area3D
var _swing_progress: float = 0.0
var _swing_duration: float = 0.28
var _hit_targets: Array[Node] = []

func _init() -> void:
	weapon_name = "Espada de Madera Cute"
	damage = 1.0
	cooldown = 0.42

func _ready() -> void:
	_build_sword_mesh()
	_build_hitbox()

func _build_sword_mesh() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	
	var wood_mat := _create_wood_blade_material()
	var grip_mat := _create_leather_grip_material()
	var gold_mat := _create_gold_pommel_material()
	
	# Pomo dorado redondeado
	_add_part(Vector3(0.07, 0.06, 0.07), Vector3(0, -0.05, 0), gold_mat)
	
	# Empuñadura de cuero
	_add_part(Vector3(0.045, 0.16, 0.045), Vector3(0, 0.06, 0), grip_mat)
	
	# Guarda cruzada gordita
	_add_part(Vector3(0.22, 0.055, 0.075), Vector3(0, 0.16, 0), wood_mat)
	
	# Hoja de madera con punta escalonada voxel
	_add_part(Vector3(0.11, 0.42, 0.032), Vector3(0, 0.39, 0), wood_mat)
	_add_part(Vector3(0.075, 0.07, 0.032), Vector3(0, 0.63, 0), wood_mat)
	_add_part(Vector3(0.04, 0.05, 0.032), Vector3(0, 0.68, 0), wood_mat)
	
	_pivot.rotation_degrees = Vector3(-18.0, 0.0, 0.0)

func _add_part(box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	_pivot.add_child(inst)

func _build_hitbox() -> void:
	_hitbox = Area3D.new()
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	_pivot.add_child(_hitbox)
	
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.75, 0.55)
	col.shape = box
	col.position = Vector3(0, 0.42, -0.15)
	_hitbox.add_child(col)
	
	_hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_attack_start() -> void:
	_is_attacking = true
	_swing_progress = 0.0
	_hit_targets.clear()
	_hitbox.monitoring = true

func _update_weapon_animation(delta: float) -> void:
	if not _is_attacking:
		_pivot.rotation_degrees = _pivot.rotation_degrees.lerp(Vector3(-18.0, 0.0, 0.0), delta * 14.0)
		return
		
	_swing_progress += delta / _swing_duration
	var side_sign := -1.0 if is_left_hand else 1.0
	
	if _swing_progress < 0.25:
		var t := _swing_progress / 0.25
		_pivot.rotation_degrees = Vector3(
			lerpf(-18.0, 22.0, t),
			lerpf(0.0, -25.0 * side_sign, t),
			lerpf(0.0, -20.0 * side_sign, t)
		)
	elif _swing_progress < 0.75:
		var t := (_swing_progress - 0.25) / 0.50
		var ease_t := 1.0 - pow(1.0 - t, 3.0)
		_pivot.rotation_degrees = Vector3(
			lerpf(22.0, -82.0, ease_t),
			lerpf(-25.0 * side_sign, 38.0 * side_sign, ease_t),
			lerpf(-20.0 * side_sign, 32.0 * side_sign, ease_t)
		)
	elif _swing_progress < 1.0:
		_hitbox.monitoring = false
		var t := (_swing_progress - 0.75) / 0.25
		_pivot.rotation_degrees = Vector3(
			lerpf(-82.0, -18.0, t),
			lerpf(38.0 * side_sign, 0.0, t),
			lerpf(32.0 * side_sign, 0.0, t)
		)
	else:
		_is_attacking = false
		_hitbox.monitoring = false
		_hit_targets.clear()

func _on_hitbox_body_entered(body: Node3D) -> void:
	if not _is_attacking:
		return
	if body in _hit_targets:
		return
	if body.has_method("take_damage"):
		_hit_targets.append(body)
		_deal_damage_to(body, global_position)

# --- TEXTURAS PIXELADAS PROCEDURALES ---

func _create_wood_blade_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var wood_light := Color(0.79, 0.56, 0.34)
	var wood_mid := Color(0.68, 0.45, 0.25)
	var wood_grain := Color(0.55, 0.34, 0.18)
	var edge_highlight := Color(0.89, 0.69, 0.46)
	
	for y in range(16):
		for x in range(16):
			if x == 0 or x == 15:
				img.set_pixel(x, y, edge_highlight)
			elif (x == 5 and y % 4 != 0) or (x == 11 and (y + 2) % 5 != 0):
				img.set_pixel(x, y, wood_grain)
			elif (x + y) % 3 == 0:
				img.set_pixel(x, y, wood_light)
			else:
				img.set_pixel(x, y, wood_mid)
	return _to_pixel_mat(img, 0.78)

func _create_leather_grip_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var leather_a := Color(0.36, 0.20, 0.13)
	var leather_b := Color(0.27, 0.14, 0.09)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, leather_a if (y % 2 == 0) else leather_b)
	return _to_pixel_mat(img, 0.85)

func _create_gold_pommel_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var gold := Color(0.95, 0.78, 0.26)
	var shine := Color(1.0, 0.94, 0.65)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, shine if (x < 3 and y < 3) else gold)
	return _to_pixel_mat(img, 0.4)
	
func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
