class_name HealthGlobe
extends CanvasLayer

var _current_hp: float = 100.0
var _display_hp: float = 100.0
var _max_hp: float = 100.0
var _time: float = 0.0
var _hurt_flash: float = 0.0

var _globe_control: Control
var _hurt_vignette: ColorRect

const GLOBE_RADIUS := 64.0

func _ready() -> void:
	layer = 12
	_build_ui()

func _build_ui() -> void:
	# Viñeta roja en bordes de pantalla al recibir daño o morir
	_hurt_vignette = ColorRect.new()
	_hurt_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt_vignette.color = Color(0.75, 0.04, 0.04, 0.0)
	add_child(_hurt_vignette)
	
	# Contenedor del orbe abajo a la izquierda
	_globe_control = Control.new()
	_globe_control.name = "DiabloHealthGlobe"
	var diameter := GLOBE_RADIUS * 2.0 + 24.0
	_globe_control.custom_minimum_size = Vector2(diameter, diameter)
	_globe_control.size = Vector2(diameter, diameter)
	_globe_control.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_globe_control.offset_left = 22.0
	_globe_control.offset_top = -diameter - 22.0
	_globe_control.offset_right = 22.0 + diameter
	_globe_control.offset_bottom = -22.0
	_globe_control.draw.connect(_on_globe_draw)
	add_child(_globe_control)

func set_health(current: float, maximum: float, took_damage: bool = false) -> void:
	_current_hp = clampf(current, 0.0, maximum)
	_max_hp = maxf(1.0, maximum)
	if took_damage:
		_hurt_flash = 1.0

func _process(delta: float) -> void:
	_time += delta
	_display_hp = lerpf(_display_hp, _current_hp, delta * 9.0)
	
	if _hurt_flash > 0.0:
		_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.8)
		_hurt_vignette.color.a = _hurt_flash * 0.38
		
	if _globe_control:
		_globe_control.queue_redraw()

func _on_globe_draw() -> void:
	var center := _globe_control.size * 0.5
	var r := GLOBE_RADIUS
	var ratio := clampf(_display_hp / _max_hp, 0.0, 1.0)
	
	# 1. Sombra exterior
	_globe_control.draw_circle(center + Vector2(3, 4), r + 7.0, Color(0.02, 0.02, 0.03, 0.75))
	
	# 2. Fondo cristal oscuro vacío del orbe
	_globe_control.draw_circle(center, r, Color(0.09, 0.03, 0.04, 0.94))
	
	# 3. Líquido de sangre recortado dentro del círculo con oleaje en la superficie
	if ratio > 0.005:
		var fill_y := lerpf(center.y + r, center.y - r, ratio)
		var poly := PackedVector2Array()
		var steps := 48
		
		# Borde superior ondulado (de izquierda a derecha)
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var x := lerpf(center.x - r, center.x + r, t)
			var dx := x - center.x
			var max_half_h := sqrt(maxf(0.0, r * r - dx * dx))
			var wave := sin(t * 9.0 + _time * 4.5) * 3.2 * sin(t * PI)
			var y := clampf(fill_y + wave, center.y - max_half_h, center.y + max_half_h)
			poly.append(Vector2(x, y))
			
		# Arco inferior del círculo (de derecha a izquierda)
		for i in range(steps, -1, -1):
			var t := float(i) / float(steps)
			var x := lerpf(center.x - r, center.x + r, t)
			var dx := x - center.x
			var max_half_h := sqrt(maxf(0.0, r * r - dx * dx))
			poly.append(Vector2(x, center.y + max_half_h))
			
		if poly.size() >= 3:
			var blood_col := Color(0.76, 0.07, 0.09, 0.96).lerp(Color(1.0, 0.25, 0.2), _hurt_flash * 0.6)
			_globe_control.draw_colored_polygon(poly, blood_col)
			
			# Línea brillante en la superficie del líquido
			var surface_pts := PackedVector2Array()
			for i in range(steps + 1):
				surface_pts.append(poly[i])
			_globe_control.draw_polyline(surface_pts, Color(0.98, 0.36, 0.32, 0.9), 2.0, true)
	
	# 4. Reflejo de cristal estilo Diablo 2 (brillo curvo arriba a la izquierda)
	_globe_control.draw_circle(center + Vector2(-r * 0.34, -r * 0.34), r * 0.22, Color(1.0, 0.85, 0.85, 0.16))
	_globe_control.draw_circle(center + Vector2(-r * 0.44, -r * 0.16), r * 0.08, Color(1.0, 0.95, 0.95, 0.22))
	
	# 5. Aro metálico medieval con remaches dorados
	_globe_control.draw_arc(center, r + 2.0, 0.0, TAU, 64, Color(0.22, 0.20, 0.18, 1.0), 6.0, true)
	_globe_control.draw_arc(center, r + 4.5, 0.0, TAU, 64, Color(0.55, 0.46, 0.30, 1.0), 2.0, true)
	_globe_control.draw_arc(center, r - 1.0, 0.0, TAU, 64, Color(0.10, 0.06, 0.06, 0.9), 2.0, true)
	
	for k in range(8):
		var a := (TAU / 8.0) * k
		var rivet_pos := center + Vector2(cos(a), sin(a)) * (r + 2.0)
		_globe_control.draw_circle(rivet_pos, 2.6, Color(0.82, 0.68, 0.34, 1.0))
	
	# 6. Texto de vida actual / máxima en el centro
	var font := ThemeDB.fallback_font
	var hp_text := "%d / %d" % [int(ceil(_current_hp)), int(_max_hp)]
	var font_size := 15
	var text_size := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := center + Vector2(-text_size.x * 0.5, text_size.y * 0.32)
	
	_globe_control.draw_string(font, text_pos + Vector2(1, 1), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.05, 0.02, 0.02, 0.95))
	_globe_control.draw_string(font, text_pos, hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.92, 0.85, 1.0))
