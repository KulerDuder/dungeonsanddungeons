class_name DungeonTextures
extends RefCounted

## Genera un StandardMaterial3D con textura pixelada de piedra medieval y mapa de normales
static func create_medieval_stone_material(
	base_tint: Color = Color.WHITE,
	uv_scale: Vector3 = Vector3(1.0, 1.0, 1.0),
	tex_size: int = 32,
	seed_offset: int = 0
) -> StandardMaterial3D:
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 42069 + seed_offset
	
	var img_albedo := Image.create(tex_size, tex_size, false, Image.FORMAT_RGB8)
	var img_height := Image.create(tex_size, tex_size, false, Image.FORMAT_L8)
	
	# Paleta retro de piedra medieval (mortero oscuro + tonos de roca fría/cálida)
	var mortar_color := Color(0.11, 0.11, 0.13)
	var stone_palette: Array[Color] = [
		Color(0.28, 0.28, 0.31),
		Color(0.34, 0.33, 0.36),
		Color(0.23, 0.24, 0.27),
		Color(0.38, 0.36, 0.35),
		Color(0.26, 0.28, 0.26) # Toque sutil de musgo/humedad
	]
	
	# Definimos 4 filas de sillares de piedra (8 píxeles de alto por fila en textura 32x32)
	var row_height := tex_size / 4
	var brick_colors := {}
	
	for row in range(4):
		var offset_x := (tex_size / 4) if (row % 2 == 1) else 0
		var brick_w := tex_size / 2
		
		for y in range(row * row_height, (row + 1) * row_height):
			for x in range(tex_size):
				var shifted_x := (x + offset_x) % tex_size
				var brick_id := Vector2i(shifted_x / brick_w, row)
				
				if not brick_colors.has(brick_id):
					brick_colors[brick_id] = stone_palette[rng.randi() % stone_palette.size()]
				
				var is_mortar_y := (y == row * row_height)
				var is_mortar_x := (shifted_x % brick_w == 0)
				
				# Pequeña irregularidad en el borde de la piedra para romper líneas rectas
				var chip := (rng.randf() < 0.12) and (y == row * row_height + 1 or shifted_x % brick_w == 1)
				
				if is_mortar_y or is_mortar_x or chip:
					var m_var := rng.randf_range(0.85, 1.15)
					img_albedo.set_pixel(x, y, mortar_color * m_var)
					img_height.set_pixel(x, y, Color(0.1, 0.1, 0.1))
				else:
					var col: Color = brick_colors[brick_id]
					# Bisel iluminado arriba/izquierda y sombra abajo/derecha de cada piedra
					var edge_shade := 1.0
					if y == row * row_height + 1 or shifted_x % brick_w == 1:
						edge_shade = 1.22
					elif y == (row + 1) * row_height - 1 or (shifted_x + 1) % brick_w == 0:
						edge_shade = 0.75
						
					var grain := rng.randf_range(0.90, 1.10)
					var final_col := (col * edge_shade * grain).clamp()
					img_albedo.set_pixel(x, y, final_col)
					
					var h_val := clampf(0.65 * edge_shade * grain, 0.25, 1.0)
					img_height.set_pixel(x, y, Color(h_val, h_val, h_val))
	
	# Convertir mapa de alturas a mapa de normales para que la linterna marque el relieve
	var img_normal := img_height.duplicate()
	img_normal.bump_map_to_normal_map(4.5)
	
	var tex_albedo := ImageTexture.create_from_image(img_albedo)
	var tex_normal := ImageTexture.create_from_image(img_normal)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_tint
	mat.albedo_texture = tex_albedo
	mat.normal_enabled = true
	mat.normal_texture = tex_normal
	mat.normal_scale = 1.2
	mat.roughness = 0.92
	
	# Clave para el aspecto pixel-art nítido sin borrosidad:
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# Mapeo triplanar para que paredes, suelos y pilares no estiren los píxeles
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = uv_scale
	
	return mat
