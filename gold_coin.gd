class_name GoldCoin
extends Area3D

signal collected(amount: int)

@export var value: int = 1
@export var magnet_radius: float = 2.6
@export var move_speed: float = 9.5

var _visual_pivot: Node3D
var _velocity: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _is_collected: bool = false

func _ready() -> void:
	_build_visual_and_collider()
	# Pequeño salto inicial al salir del jarrón
	_velocity = Vector3(randf_range(-1.8, 1.8), randf_range(3.2, 4.6), randf_range(-1.8, 1.8))
	body_entered.connect(_on_body_entered)

func _build_visual_and_collider() -> void:
	_visual_pivot = Node3D.new()
	add_child(_visual_pivot)
	
	var gold_mat := _create_shiny_gold_material()
	
	# Disco voxel octogonal/cruzado para que parezca una moneda gruesa brillante
	var main_disc := BoxMesh.new()
	main_disc.size = Vector3(0.24, 0.24, 0.06)
	main_disc.material = gold_mat
	var inst1 := MeshInstance3D.new()
	inst1.mesh = main_disc
	_visual_pivot.add_child(inst1)
	
	var cross_disc := BoxMesh.new()
	cross_disc.size = Vector3(0.18, 0.28, 0.06)
	cross_disc.material = gold_mat
	var inst2 := MeshInstance3D.new()
	inst2.mesh = cross_disc
	_visual_pivot.add_child(inst2)
	
	# Brillo cálido dorado alrededor de la moneda
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.25)
	light.light_energy = 1.1
	light.omni_range = 2.4
	add_child(light)
	
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	col.shape = sphere
	add_child(col)

func _physics_process(delta: float) -> void:
	if _is_collected:
		return
		
	_time += delta
	_visual_pivot.rotation.y += delta * 3.8
	_visual_pivot.position.y = sin(_time * 4.5) * 0.05
	
	# Rebote simple contra el suelo (y = 0.22)
	if global_position.y > 0.22 or _velocity.y > 0.0:
		_velocity.y -= 12.0 * delta
		global_position += _velocity * delta
		if global_position.y <= 0.22:
			global_position.y = 0.22
			if abs(_velocity.y) > 1.2:
				_velocity.y = -_velocity.y * 0.45
				_velocity.x *= 0.6
				_velocity.z *= 0.6
			else:
				_velocity = Vector3.ZERO
				
	# Atracción suave hacia el jugador cuando se acerca
	var player_body := _find_player_body()
	if player_body:
		var target := player_body.global_position + Vector3(0, 0.7, 0)
		var dist := global_position.distance_to(target)
		if dist <= magnet_radius:
			global_position = global_position.lerp(target, delta * move_speed)
			if dist <= 0.65:
				_collect()

func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
	if body.name == "PlayerBody" or (body.get_parent() and body.get_parent().has_method("equip_weapon")):
		_collect()

func _collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	collected.emit(value)
	_play_coin_pickup_sound()
	
	# Pequeño destello hacia arriba antes de desaparecer
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual_pivot, "position:y", 0.6, 0.16)
	tween.tween_property(_visual_pivot, "scale", Vector3(0.05, 0.05, 0.05), 0.16)
	tween.chain().tween_callback(queue_free)

func _play_coin_pickup_sound() -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	var audio := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.22
	audio.stream = gen
	audio.volume_db = -12.0
	scene_root.add_child(audio)
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * 0.16)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			# Doble tono agudo clásico de moneda (B5 -> E6)
			var freq := 987.77 if t < 0.35 else 1318.51
			phase += freq / gen.mix_rate
			var env := 1.0 - maxf(0.0, (t - 0.35) / 0.65)
			var wave := sin(phase * TAU) * env * 0.24
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.28).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

func _find_player_body() -> Node3D:
	var root := get_tree().current_scene
	if not root:
		return null
	return root.find_child("PlayerBody", true, false) as Node3D

func _create_shiny_gold_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var gold := Color(0.98, 0.78, 0.18)
	var shine := Color(1.0, 0.97, 0.68)
	var rim := Color(0.78, 0.54, 0.08)
	for y in range(8):
		for x in range(8):
			if x == 0 or x == 7 or y == 0 or y == 7:
				img.set_pixel(x, y, rim)
			elif (x >= 2 and x <= 3 and y >= 2 and y <= 4):
				img.set_pixel(x, y, shine)
			else:
				img.set_pixel(x, y, gold)
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.72, 0.15)
	mat.emission_energy_multiplier = 0.75
	mat.roughness = 0.25
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
