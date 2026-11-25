class_name CoinHUD
extends CanvasLayer

var _panel: PanelContainer
var _count_label: Label
var _icon_rect: TextureRect
var _coins: int = 0

func _ready() -> void:
	layer = 11
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -16
	_panel.offset_top = 240 # Justo debajo del minimapa
	_panel.offset_right = -16
	_panel.offset_bottom = 282
	add_child(_panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.border_color = Color(0.65, 0.52, 0.24, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 12
	_panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_panel.add_child(hbox)
	
	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(22, 22)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_rect.texture = _create_coin_icon_texture()
	hbox.add_child(_icon_rect)
	
	_count_label = Label.new()
	_count_label.text = "0"
	_count_label.add_theme_font_size_override("font_size", 20)
	_count_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.34))
	_count_label.add_theme_constant_override("outline_size", 5)
	_count_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	hbox.add_child(_count_label)

func set_coins(amount: int, animate_gain: bool = false) -> void:
	_coins = amount
	if _count_label:
		_count_label.text = str(_coins)
		if animate_gain:
			_count_label.pivot_offset = _count_label.size * 0.5
			_count_label.scale = Vector2(1.35, 1.35)
			var tween := create_tween()
			tween.tween_property(_count_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)

func _create_coin_icon_texture() -> ImageTexture:
	# Icono pixel-art 12x12 de moneda de oro brillante
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rim := Color(0.75, 0.50, 0.08, 1.0)
	var gold := Color(0.98, 0.78, 0.18, 1.0)
	var shine := Color(1.0, 0.97, 0.72, 1.0)
	
	for y in range(1, 11):
		for x in range(2, 10):
			var is_corner := (x == 2 or x == 9) and (y == 1 or y == 10)
			if is_corner:
				continue
			if x == 2 or x == 9 or y == 1 or y == 10:
				img.set_pixel(x, y, rim)
			elif (x == 4 and y >= 3 and y <= 6) or (x == 5 and y == 3):
				img.set_pixel(x, y, shine)
			else:
				img.set_pixel(x, y, gold)
	return ImageTexture.create_from_image(img)
