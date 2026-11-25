extends Node3D

@export_group("Dimensiones de la Dungeon")
@export var grid_width: int = 44
@export var grid_height: int = 44
@export var tile_size: float = 3.0
@export var wall_height: float = 4.2

@export_group("Parámetros de Salas")
@export var room_attempts: int = 35
@export var min_room_size: int = 4
@export var max_room_size: int = 8

@export_group("Estilo Visual")
@export var pixel_resolution: int = 32

enum Tile { VOID = 0, FLOOR = 1, WALL = 2 }

var _grid: Array = []
var _rooms: Array[Rect2i] = []
var _rng := RandomNumberGenerator.new()

func generate_dungeon(custom_seed: int = -1) -> Vector3:
	for child in get_children():
		child.queue_free()
	_rooms.clear()
	
	if custom_seed >= 0:
		_rng.seed = custom_seed
	else:
		_rng.randomize()
		
	_init_grid()
	_carve_rooms()
	_connect_rooms()
	_build_perimeter_walls()
	_instantiate_3d_geometry()
	
	if _rooms.size() > 0:
		var start_center: Vector2i = _rooms[0].get_center()
		return Vector3(start_center.x * tile_size, 0.0, start_center.y * tile_size)
	return Vector3.ZERO

func get_map_data() -> Dictionary:
	return {
		"width": grid_width,
		"height": grid_height,
		"tile_size": tile_size,
		"grid": _grid
	}

func get_enemy_spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in range(1, _rooms.size()):
		var center: Vector2i = _rooms[i].get_center()
		points.append(Vector3(center.x * tile_size, 0.0, center.y * tile_size))
	return points

func get_chest_spawn_points() -> Array[Dictionary]:
	var chests: Array[Dictionary] = []
	if _rooms.is_empty():
		return chests
		
	var first_room := _rooms[0]
	var c0 := first_room.get_center()
	chests.append({
		"pos": Vector3((c0.x + 1) * tile_size, 0.0, c0.y * tile_size),
		"rot_y": -PI * 0.5
	})
	
	for i in range(2, _rooms.size(), 3):
		var ci := _rooms[i].get_center()
		chests.append({
			"pos": Vector3(ci.x * tile_size, 0.0, ci.y * tile_size),
			"rot_y": _rng.randf_range(0.0, TAU)
		})
	return chests

func get_pot_spawn_points() -> Array[Vector3]:
	var pot_positions: Array[Vector3] = []
	for room in _rooms:
		var center := room.get_center()
		var candidates: Array[Vector2i] = []
		
		for rx in range(room.position.x, room.end.x):
			for ry in range(room.position.y, room.end.y):
				var is_border := (rx == room.position.x or rx == room.end.x - 1 or ry == room.position.y or ry == room.end.y - 1)
				if not is_border:
					continue
				var is_corner := (rx == room.position.x or rx == room.end.x - 1) and (ry == room.position.y or ry == room.end.y - 1)
				if is_corner and room.size.x >= 5 and room.size.y >= 5:
					continue
				if Vector2i(rx, ry) == center:
					continue
				candidates.append(Vector2i(rx, ry))
				
		candidates.shuffle()
		var count := mini(candidates.size(), _rng.randi_range(1, 3))
		for i in range(count):
			var cell := candidates[i]
			var jitter := Vector3(_rng.randf_range(-0.45, 0.45), 0.0, _rng.randf_range(-0.45, 0.45))
			pot_positions.append(Vector3(cell.x * tile_size, 0.0, cell.y * tile_size) + jitter)
			
	return pot_positions

func get_vegetation_spawn_points() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var floor_cells: Array[Vector2i] = []
	
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			if _grid[x][y] == Tile.FLOOR:
				floor_cells.append(Vector2i(x, y))
				
	floor_cells.shuffle()
	
	# Jardín frondoso en suelo (~44% de las casillas transitables, con arbustos grandes y flores)
	var floor_count := int(floor_cells.size() * 0.44)
	for i in range(mini(floor_count, floor_cells.size())):
		var c := floor_cells[i]
		# Empujamos ligeramente hacia los laterales de la baldosa para dejar paso cómodo por el centro
		var side_x := _rng.randf_range(0.45, 1.05) * (-1.0 if _rng.randf() < 0.5 else 1.0)
		var side_z := _rng.randf_range(0.45, 1.05) * (-1.0 if _rng.randf() < 0.5 else 1.0)
		var edge_offset := Vector3(side_x, 0.0, side_z)
		
		var roll := _rng.randf()
		var kind := DungeonVegetation.Kind.FLOOR_LUSH_BUSH
		if roll < 0.24:
			kind = DungeonVegetation.Kind.FLOOR_LUSH_BUSH
		elif roll < 0.46:
			kind = DungeonVegetation.Kind.FLOOR_FLOWERING_BUSH
		elif roll < 0.68:
			kind = DungeonVegetation.Kind.FLOOR_FERN
		elif roll < 0.86:
			kind = DungeonVegetation.Kind.FLOOR_FLOWERS
		else:
			kind = DungeonVegetation.Kind.FLOOR_MUSHROOMS
			
		entries.append({
			"pos": Vector3(c.x * tile_size, 0.0, c.y * tile_size) + edge_offset,
			"ceiling": false,
			"kind": kind
		})
		
	# Techo cubierto de enredaderas y farolillos florales (~42% de las casillas)
	floor_cells.shuffle()
	var ceil_count := int(floor_cells.size() * 0.42)
	for i in range(mini(ceil_count, floor_cells.size())):
		var c := floor_cells[i]
		var offset := Vector3(_rng.randf_range(-1.05, 1.05), wall_height, _rng.randf_range(-1.05, 1.05))
		var kind := DungeonVegetation.Kind.CEILING_VINE if _rng.randf() < 0.65 else DungeonVegetation.Kind.CEILING_HANGING_FLOWER
		entries.append({
			"pos": Vector3(c.x * tile_size, 0.0, c.y * tile_size) + offset,
			"ceiling": true,
			"kind": kind
		})
		
	return entries

func _init_grid() -> void:
	_grid.resize(grid_width)
	for x in range(grid_width):
		var col: Array[int] = []
		col.resize(grid_height)
		col.fill(Tile.VOID)
		_grid[x] = col

func _carve_rooms() -> void:
	for i in range(room_attempts):
		var w := _rng.randi_range(min_room_size, max_room_size)
		var h := _rng.randi_range(min_room_size, max_room_size)
		var x := _rng.randi_range(2, grid_width - w - 3)
		var y := _rng.randi_range(2, grid_height - h - 3)
		
		var new_room := Rect2i(x, y, w, h)
		var padded_room := new_room.grow(1)
		
		var overlaps := false
		for existing in _rooms:
			if padded_room.intersects(existing):
				overlaps = true
				break
				
		if not overlaps:
			_rooms.append(new_room)
			for rx in range(new_room.position.x, new_room.end.x):
				for ry in range(new_room.position.y, new_room.end.y):
					_grid[rx][ry] = Tile.FLOOR

func _connect_rooms() -> void:
	for i in range(1, _rooms.size()):
		var prev_center := _rooms[i - 1].get_center()
		var curr_center := _rooms[i].get_center()
		
		if _rng.randf() < 0.5:
			_carve_h_corridor(prev_center.x, curr_center.x, prev_center.y)
			_carve_v_corridor(prev_center.y, curr_center.y, curr_center.x)
		else:
			_carve_v_corridor(prev_center.y, curr_center.y, prev_center.x)
			_carve_h_corridor(prev_center.x, curr_center.x, curr_center.y)

func _carve_h_corridor(x1: int, x2: int, y: int) -> void:
	for x in range(min(x1, x2), max(x1, x2) + 1):
		_grid[x][y] = Tile.FLOOR

func _carve_v_corridor(y1: int, y2: int, x: int) -> void:
	for y in range(min(y1, y2), max(y1, y2) + 1):
		_grid[x][y] = Tile.FLOOR

func _build_perimeter_walls() -> void:
	var dirs := [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			if _grid[x][y] == Tile.VOID:
				for d in dirs:
					if _grid[x + d.x][y + d.y] == Tile.FLOOR:
						_grid[x][y] = Tile.WALL
						break

func _instantiate_3d_geometry() -> void:
	var floor_transforms: Array[Transform3D] = []
	var ceiling_transforms: Array[Transform3D] = []
	var wall_transforms: Array[Transform3D] = []
	var pillar_transforms: Array[Transform3D] = []
	
	var physics_body := StaticBody3D.new()
	physics_body.name = "DungeonCollisions"
	add_child(physics_body)
	
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(tile_size, 0.2, tile_size)
	
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(tile_size, wall_height, tile_size)
	
	for x in range(grid_width):
		for y in range(grid_height):
			var world_x := x * tile_size
			var world_z := y * tile_size
			var cell: int = _grid[x][y]
			
			if cell == Tile.FLOOR:
				floor_transforms.append(Transform3D(Basis(), Vector3(world_x, -0.1, world_z)))
				ceiling_transforms.append(Transform3D(Basis(), Vector3(world_x, wall_height + 0.1, world_z)))
				_add_collider(physics_body, floor_shape, Vector3(world_x, -0.1, world_z))
				
			elif cell == Tile.WALL:
				wall_transforms.append(Transform3D(Basis(), Vector3(world_x, wall_height * 0.5, world_z)))
				_add_collider(physics_body, wall_shape, Vector3(world_x, wall_height * 0.5, world_z))

	for room in _rooms:
		if room.size.x >= 5 and room.size.y >= 5:
			var corners := [
				Vector2i(room.position.x, room.position.y),
				Vector2i(room.end.x - 1, room.position.y),
				Vector2i(room.position.x, room.end.y - 1),
				Vector2i(room.end.x - 1, room.end.y - 1)
			]
			for c in corners:
				pillar_transforms.append(Transform3D(Basis(), Vector3(c.x * tile_size, wall_height * 0.5, c.y * tile_size)))

	var floor_mat := _create_medieval_stone_material(Color(0.75, 0.78, 0.82), Vector3(0.5, 0.5, 0.5), pixel_resolution, 1)
	var ceiling_mat := _create_medieval_stone_material(Color(0.45, 0.45, 0.50), Vector3(0.4, 0.4, 0.4), pixel_resolution, 2)
	var wall_mat := _create_medieval_stone_material(Color(1.0, 0.98, 0.95), Vector3(0.35, 0.35, 0.35), pixel_resolution, 3)
	var pillar_mat := _create_medieval_stone_material(Color(0.85, 0.82, 0.80), Vector3(0.6, 0.6, 0.6), pixel_resolution, 4)

	_create_multimesh_batch("Floors", Vector3(tile_size, 0.2, tile_size), floor_transforms, floor_mat)
	_create_multimesh_batch("Ceilings", Vector3(tile_size, 0.2, tile_size), ceiling_transforms, ceiling_mat)
	_create_multimesh_batch("Walls", Vector3(tile_size, wall_height, tile_size), wall_transforms, wall_mat)
	_create_multimesh_batch("Pillars", Vector3(0.55, wall_height, 0.55), pillar_transforms, pillar_mat)

func _add_collider(parent: StaticBody3D, shape: Shape3D, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	parent.add_child(col)

func _create_multimesh_batch(batch_name: String, box_size: Vector3, transforms: Array[Transform3D], material: StandardMaterial3D) -> void:
	if transforms.is_empty():
		return
		
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		
	var mmi := MultiMeshInstance3D.new()
	mmi.name = batch_name
	mmi.multimesh = mm
	add_child(mmi)

@warning_ignore("integer_division")
func _create_medieval_stone_material(
	base_tint: Color = Color.WHITE,
	uv_scale: Vector3 = Vector3(1.0, 1.0, 1.0),
	tex_size: int = 32,
	seed_offset: int = 0
) -> StandardMaterial3D:
	
	var tex_rng := RandomNumberGenerator.new()
	tex_rng.seed = 42069 + seed_offset
	
	var img_albedo := Image.create(tex_size, tex_size, false, Image.FORMAT_RGB8)
	var img_height := Image.create(tex_size, tex_size, false, Image.FORMAT_L8)
	
	var mortar_color := Color(0.11, 0.11, 0.13)
	var stone_palette: Array[Color] = [
		Color(0.28, 0.28, 0.31),
		Color(0.34, 0.33, 0.36),
		Color(0.23, 0.24, 0.27),
		Color(0.38, 0.36, 0.35),
		Color(0.26, 0.28, 0.26)
	]
	
	var row_height: int = maxi(4, int(tex_size / 4))
	var brick_w: int = maxi(4, int(tex_size / 2))
	var quarter_w: int = int(tex_size / 4)
	var brick_colors := {}
	
	for row in range(4):
		var offset_x: int = quarter_w if (row % 2 == 1) else 0
		
		for y in range(row * row_height, mini(tex_size, (row + 1) * row_height)):
			for x in range(tex_size):
				var shifted_x: int = (x + offset_x) % tex_size
				var brick_id := Vector2i(int(shifted_x / brick_w), row)
				
				if not brick_colors.has(brick_id):
					brick_colors[brick_id] = stone_palette[tex_rng.randi() % stone_palette.size()]
				
				var is_mortar_y := (y == row * row_height)
				var is_mortar_x := (shifted_x % brick_w == 0)
				var chip := (tex_rng.randf() < 0.12) and (y == row * row_height + 1 or shifted_x % brick_w == 1)
				
				if is_mortar_y or is_mortar_x or chip:
					var m_var := tex_rng.randf_range(0.85, 1.15)
					img_albedo.set_pixel(x, y, mortar_color * m_var)
					img_height.set_pixel(x, y, Color(0.1, 0.1, 0.1))
				else:
					var col: Color = brick_colors[brick_id]
					var edge_shade := 1.0
					if y == row * row_height + 1 or shifted_x % brick_w == 1:
						edge_shade = 1.22
					elif y == (row + 1) * row_height - 1 or (shifted_x + 1) % brick_w == 0:
						edge_shade = 0.75
						
					var grain := tex_rng.randf_range(0.90, 1.10)
					var final_col := (col * edge_shade * grain).clamp()
					img_albedo.set_pixel(x, y, final_col)
					
					var h_val := clampf(0.65 * edge_shade * grain, 0.25, 1.0)
					img_height.set_pixel(x, y, Color(h_val, h_val, h_val))
	
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
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = uv_scale
	
	return mat
