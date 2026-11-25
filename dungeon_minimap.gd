class_name DungeonMinimap
extends CanvasLayer

var _dungeon: Node3D
var _player: Node3D
var _enemies_container: Node3D
var _chests_container: Node3D

var _panel: PanelContainer
var _map_tex_rect: TextureRect
var _overlay_control: Control
var _title_label: Label

var _grid_width: int = 44
var _grid_height: int = 44
var _tile_size: float = 3.0
var _is_expanded: bool = false

const MINI_SIZE := Vector2(190, 190)
const EXPANDED_SIZE := Vector2(460, 460)

func _ready() -> void:
	layer = 10
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	add_child(_panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	style.border_color = Color(0.45, 0.42, 0.36, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)
	
	var map_holder := Control.new()
	map_holder.name = "MapHolder"
	map_holder.custom_minimum_size = MINI_SIZE
	vbox.add_child(map_holder)
	
	_map_tex_rect = TextureRect.new()
	_map_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_holder.add_child(_map_tex_rect)
	
	_overlay_control = Control.new()
	_overlay_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_control.draw.connect(_on_overlay_draw)
	map_holder.add_child(_overlay_control)
	
	_title_label = Label.new()
	_title_label.text = "[M] Ampliar mapa"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74))
	vbox.add_child(_title_label)
	
	_apply_layout_mode()

func setup(dungeon: Node3D, player: Node3D, enemies: Node3D, chests: Node3D) -> void:
	_dungeon = dungeon
	_player = player
	_enemies_container = enemies
	_chests_container = chests
	refresh_dungeon_texture()

func refresh_dungeon_texture() -> void:
	if not _dungeon or not _dungeon.has_method("get_map_data"):
		return
		
	var data: Dictionary = _dungeon.get_map_data()
	_grid_width = data.get("width", 44)
	_grid_height = data.get("height", 44)
	_tile_size = data.get("tile_size", 3.0)
	var grid: Array = data.get("grid", [])
	
	if grid.is_empty():
		return
		
	var img := Image.create(_grid_width, _grid_height, false, Image.FORMAT_RGBA8)
	var col_void := Color(0.03, 0.03, 0.05, 0.9)
	var col_floor := Color(0.24, 0.25, 0.30, 1.0)
	var col_wall := Color(0.58, 0.55, 0.50, 1.0)
	
	for x in range(_grid_width):
		for y in range(_grid_height):
			var cell: int = grid[x][y]
			if cell == 1:
				img.set_pixel(x, y, col_floor)
			elif cell == 2:
				img.set_pixel(x, y, col_wall)
			else:
				img.set_pixel(x, y, col_void)
				
	_map_tex_rect.texture = ImageTexture.create_from_image(img)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M or event.keycode == KEY_TAB:
			_is_expanded = not _is_expanded
			_apply_layout_mode()

func _apply_layout_mode() -> void:
	if not _panel:
		return
	var map_holder := _panel.find_child("MapHolder", true, false) as Control
	if _is_expanded:
		if map_holder:
			map_holder.custom_minimum_size = EXPANDED_SIZE
		_title_label.text = "[M] Cerrar mapa  |  Verde: Tú  Rojo: Enemigo  Dorado: Cofre"
		_panel.set_anchors_preset(Control.PRESET_CENTER)
		_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		_panel.offset_left = 0
		_panel.offset_top = 0
		_panel.offset_right = 0
		_panel.offset_bottom = 0
	else:
		if map_holder:
			map_holder.custom_minimum_size = MINI_SIZE
		_title_label.text = "[M] Mapa"
		_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_panel.grow_vertical = Control.GROW_DIRECTION_END
		_panel.offset_left = -16
		_panel.offset_top = 16
		_panel.offset_right = -16
		_panel.offset_bottom = 16

func _process(_delta: float) -> void:
	if _overlay_control:
		_overlay_control.queue_redraw()

func _world_to_map_px(world_pos: Vector3, rect_size: Vector2) -> Vector2:
	# En DungeonGenerator la celda (x, y) está centrada en (x * tile_size, y * tile_size)
	var gx := (world_pos.x / _tile_size) + 0.5
	var gy := (world_pos.z / _tile_size) + 0.5
	return Vector2(
		(gx / float(_grid_width)) * rect_size.x,
		(gy / float(_grid_height)) * rect_size.y
	)

func _on_overlay_draw() -> void:
	var rect_size := _overlay_control.size
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return
		
	var dot_scale := 1.6 if _is_expanded else 1.0
	
	# 1. Cofres (cuadraditos dorados)
	if _chests_container:
		for chest in _chests_container.get_children():
			if is_instance_valid(chest) and chest is Node3D:
				var p := _world_to_map_px(chest.global_position, rect_size)
				var s := 3.5 * dot_scale
				_overlay_control.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(1.0, 0.84, 0.25))
				
	# 2. Enemigos vivos (puntos rojos con borde oscuro)
	if _enemies_container:
		for enemy in _enemies_container.get_children():
			if is_instance_valid(enemy) and enemy is Node3D:
				var p := _world_to_map_px(enemy.global_position, rect_size)
				_overlay_control.draw_circle(p, 3.6 * dot_scale, Color(0.1, 0.02, 0.02))
				_overlay_control.draw_circle(p, 2.5 * dot_scale, Color(0.95, 0.22, 0.22))
				
	# 3. Jugador (triángulo verde orientado hacia donde mira)
	if _player:
		var player_body := _player.find_child("PlayerBody", true, false) as Node3D
		if player_body:
			var p := _world_to_map_px(player_body.global_position, rect_size)
			var forward := -player_body.global_transform.basis.z
			var angle := atan2(forward.z, forward.x)
			var r := 5.2 * dot_scale
			
			var tip := p + Vector2(cos(angle), sin(angle)) * r
			var left := p + Vector2(cos(angle + 2.45), sin(angle + 2.45)) * (r * 0.8)
			var right := p + Vector2(cos(angle - 2.45), sin(angle - 2.45)) * (r * 0.8)
			
			_overlay_control.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.25, 0.95, 0.45))
