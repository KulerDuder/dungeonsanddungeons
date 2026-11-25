class_name WoodenShield
extends ShieldBase

func _init() -> void:
	weapon_name = "Escudo de Madera (25 aguante)"
	max_durability = 25.0
	damage = 0.0
	cooldown = 0.25

func _build_shield_mesh(pivot: Node3D) -> void:
	var wood_mat := _create_shield_wood_material()
	var iron_mat := _create_iron_rim_material()
	var boss_mat := _create_gold_boss_material()
	
	# Cuerpo principal
	_add_part_to(pivot, Vector3(0.32, 0.36, 0.036), Vector3.ZERO, wood_mat)
	_add_part_to(pivot, Vector3(0.38, 0.26, 0.036), Vector3.ZERO, wood_mat)
	
	# Marco exterior
	_add_part_to(pivot, Vector3(0.34, 0.035, 0.044), Vector3(0.0, 0.18, 0.0), iron_mat)
	_add_part_to(pivot, Vector3(0.34, 0.035, 0.044), Vector3(0.0, -0.18, 0.0), iron_mat)
	_add_part_to(pivot, Vector3(0.035, 0.28, 0.044), Vector3(-0.185, 0.0, 0.0), iron_mat)
	_add_part_to(pivot, Vector3(0.035, 0.28, 0.044), Vector3(0.185, 0.0, 0.0), iron_mat)
	
	# Umbón central
	_add_part_to(pivot, Vector3(0.12, 0.12, 0.035), Vector3(0.0, 0.0, -0.028), iron_mat)
	_add_part_to(pivot, Vector3(0.07, 0.07, 0.025), Vector3(0.0, 0.0, -0.048), boss_mat)
	
	# Asa trasera
	_add_part_to(pivot, Vector3(0.03, 0.14, 0.04), Vector3(0.0, 0.0, 0.032), iron_mat)

func _get_break_shard_material() -> StandardMaterial3D:
	return _create_shield_wood_material()

func _create_shield_wood_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var plank_a := Color(0.56, 0.34, 0.17)
	var plank_b := Color(0.47, 0.27, 0.13)
	var seam := Color(0.26, 0.14, 0.06)
	for y in range(16):
		for x in range(16):
			if x % 4 == 0:
				img.set_pixel(x, y, seam)
			elif (x + y) % 3 == 0:
				img.set_pixel(x, y, plank_a)
			else:
				img.set_pixel(x, y, plank_b)
	return _to_pixel_mat(img, 0.82)

func _create_iron_rim_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var iron := Color(0.28, 0.31, 0.36)
	var rivet := Color(0.55, 0.58, 0.65)
	img.fill(iron)
	img.set_pixel(2, 2, rivet)
	img.set_pixel(5, 5, rivet)
	return _to_pixel_mat(img, 0.55)

func _create_gold_boss_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.92, 0.74, 0.24))
	img.set_pixel(2, 2, Color(1.0, 0.95, 0.68))
	return _to_pixel_mat(img, 0.4)
