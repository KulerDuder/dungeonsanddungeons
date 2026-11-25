class_name LootChest
extends StaticBody3D

## Pool de armas disponibles para este cofre
var weapon_pool: Array[GDScript] = [
	WoodenSword,
	WoodenDagger
]

var _lid_pivot: Node3D
var _prompt_label: Label3D
var _weapon_preview_pivot: Node3D
var _player_in_range: Node3D = null
var _is_open: bool = false
var _is_looted: bool = false
var _selected_weapon_script: GDScript
var _preview_weapon_name: String = ""
var _spin_time: float = 0.0

func _ready() -> void:
	_pick_from_pool()
	_build_chest_mesh()
	_build_interaction_area()
	_build_floating_prompt()

func _pick_from_pool() -> void:
	if weapon_pool.is_empty():
		return
	_selected_weapon_script = weapon_pool[randi() % weapon_pool.size()]
	var temp_instance: WeaponBase = _selected_weapon_script.new()
	_preview_weapon_name = temp_instance.weapon_name
	temp_instance.queue_free()

func _build_chest_mesh() -> void:
	var wood_mat := _create_chest_wood_material()
	var iron_mat := _create_iron_band_material()
	var gold_mat := _create_lock_gold_material()
	
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(0.95, 0.72, 0.65)
	col.shape = box_col
	col.position = Vector3(0, 0.36, 0)
	add_child(col)
	
	_add_box(self, Vector3(0.92, 0.44, 0.62), Vector3(0, 0.22, 0), wood_mat)
	_add_box(self, Vector3(0.08, 0.45, 0.64), Vector3(-0.38, 0.225, 0), iron_mat)
	_add_box(self, Vector3(0.08, 0.45, 0.64), Vector3(0.38, 0.225, 0), iron_mat)
	
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0, 0.44, -0.31)
	add_child(_lid_pivot)
	
	_add_box(_lid_pivot, Vector3(0.92, 0.24, 0.62), Vector3(0, 0.12, 0.31), wood_mat)
	_add_box(_lid_pivot, Vector3(0.08, 0.25, 0.64), Vector3(-0.38, 0.125, 0.31), iron_mat)
	_add_box(_lid_pivot, Vector3(0.08, 0.25, 0.64), Vector3(0.38, 0.125, 0.31), iron_mat)
	_add_box(_lid_pivot, Vector3(0.14, 0.16, 0.06), Vector3(0, 0.02, 0.62), gold_mat)
	
	_weapon_preview_pivot = Node3D.new()
	_weapon_preview_pivot.position = Vector3(0, 0.85, 0)
	_weapon_preview_pivot.visible = false
	add_child(_weapon_preview_pivot)

func _add_box(parent: Node3D, s: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)

func _build_interaction_area() -> void:
	var area := Area3D.new()
	add_child(area)
	
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.3
	col.shape = sphere
	col.position = Vector3(0, 0.5, 0)
	area.add_child(col)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _build_floating_prompt() -> void:
	_prompt_label = Label3D.new()
	_prompt_label.position = Vector3(0, 1.35, 0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.pixel_size = 0.0045
	_prompt_label.font_size = 36
	_prompt_label.outline_size = 8
	_prompt_label.modulate = Color(1.0, 0.95, 0.75)
	_prompt_label.text = "[E] Abrir cofre"
	_prompt_label.visible = false
	add_child(_prompt_label)

func _on_body_entered(body: Node3D) -> void:
	if body.get_parent() and body.get_parent().has_method("equip_weapon"):
		_player_in_range = body.get_parent()
		_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body.get_parent() == _player_in_range:
		_player_in_range = null
		_prompt_label.visible = false

func _update_prompt() -> void:
	if not _player_in_range or _is_looted:
		_prompt_label.visible = false
		return
		
	_prompt_label.visible = true
	if not _is_open:
		_prompt_label.text = "[E] Abrir cofre"
	else:
		_prompt_label.text = "%s\n[1] Mano Izq.   [2] Mano Der." % _preview_weapon_name

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _is_looted:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if not _is_open and event.keycode == KEY_E:
			_open_chest()
		elif _is_open:
			if event.keycode == KEY_1:
				_give_weapon_to_player(true)
			elif event.keycode == KEY_2:
				_give_weapon_to_player(false)

func _open_chest() -> void:
	_is_open = true
	_update_prompt()
	
	if _selected_weapon_script:
		var preview: WeaponBase = _selected_weapon_script.new()
		preview.scale = Vector3(0.85, 0.85, 0.85)
		_weapon_preview_pivot.add_child(preview)
		_weapon_preview_pivot.visible = true

func _give_weapon_to_player(left_slot: bool) -> void:
	if not _selected_weapon_script or not _player_in_range:
		return
		
	var new_weapon: WeaponBase = _selected_weapon_script.new()
	_player_in_range.equip_weapon(new_weapon, left_slot)
	
	_is_looted = true
	_weapon_preview_pivot.visible = false
	_prompt_label.visible = false

func _process(delta: float) -> void:
	var target_lid_x := deg_to_rad(-68.0) if _is_open else 0.0
	_lid_pivot.rotation.x = lerpf(_lid_pivot.rotation.x, target_lid_x, delta * 8.0)
	
	if _weapon_preview_pivot.visible:
		_spin_time += delta
		_weapon_preview_pivot.rotation.y += delta * 2.2
		_weapon_preview_pivot.position.y = 0.85 + sin(_spin_time * 3.0) * 0.06

# --- TEXTURAS PIXELADAS DEL COFRE ---

func _create_chest_wood_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var plank_a := Color(0.48, 0.28, 0.14)
	var plank_b := Color(0.41, 0.23, 0.11)
	var seam := Color(0.22, 0.11, 0.05)
	for y in range(16):
		for x in range(16):
			if y % 4 == 0:
				img.set_pixel(x, y, seam)
			else:
				img.set_pixel(x, y, plank_a if ((x + y) % 2 == 0) else plank_b)
	return _to_pixel_mat(img)

func _create_iron_band_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var iron := Color(0.24, 0.26, 0.30)
	var rivet := Color(0.45, 0.48, 0.54)
	img.fill(iron)
	img.set_pixel(3, 2, rivet)
	img.set_pixel(3, 5, rivet)
	return _to_pixel_mat(img)

func _create_lock_gold_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.92, 0.74, 0.22))
	img.set_pixel(3, 4, Color(0.15, 0.12, 0.08))
	img.set_pixel(4, 4, Color(0.15, 0.12, 0.08))
	return _to_pixel_mat(img)

func _to_pixel_mat(img: Image) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
