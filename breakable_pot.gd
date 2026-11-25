class_name BreakablePot
extends StaticBody3D

signal coin_spawned(coin: GoldCoin)

@export var coin_chance: float = 0.25 # Escaso: ~25% de los jarrones llevan moneda

var _visual_root: Node3D
var _is_broken: bool = false
var _pot_mat: StandardMaterial3D

func _ready() -> void:
	_build_pot()

func _build_pot() -> void:
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.26
	cyl.height = 0.58
	col.shape = cyl
	col.position = Vector3(0, 0.29, 0)
	add_child(col)
	
	_visual_root = Node3D.new()
	add_child(_visual_root)
	
	_pot_mat = _create_terracotta_material()
	var trim_mat := _create_pot_trim_material()
	
	# Base estrecha del jarrón
	_add_part(Vector3(0.26, 0.08, 0.26), Vector3(0, 0.04, 0), _pot_mat)
	# Panza gordita pixelada
	_add_part(Vector3(0.42, 0.26, 0.42), Vector3(0, 0.21, 0), _pot_mat)
	# Hombro con banda decorativa
	_add_part(Vector3(0.34, 0.09, 0.34), Vector3(0, 0.38, 0), trim_mat)
	# Cuello estrecho
	_add_part(Vector3(0.22, 0.08, 0.22), Vector3(0, 0.46, 0), _pot_mat)
	# Borde superior del jarrón
	_add_part(Vector3(0.28, 0.05, 0.28), Vector3(0, 0.52, 0), trim_mat)

func _add_part(s: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	_visual_root.add_child(inst)

## Compatible automáticamente con espadas, dagas lanzables y cualquier arma futura
func take_damage(_amount: float, hit_from: Vector3) -> void:
	if _is_broken:
		return
	_is_broken = true
	
	_play_shatter_sound()
	_spawn_ceramic_shards(hit_from)
	
	if randf() <= coin_chance:
		_spawn_gold_coin()
		
	queue_free()

func _spawn_gold_coin() -> void:
	var host := get_parent() if get_parent() else get_tree().current_scene
	if not host:
		return
	var coin := GoldCoin.new()
	host.add_child(coin)
	coin.global_position = global_position + Vector3(0, 0.35, 0)
	coin_spawned.emit(coin)

func _spawn_ceramic_shards(hit_from: Vector3) -> void:
	var host := get_parent() if get_parent() else get_tree().current_scene
	if not host:
		return
		
	var push_dir := (global_position - hit_from)
	push_dir.y = 0.0
	if push_dir.length() > 0.01:
		push_dir = push_dir.normalized()
		
	for i in range(7):
		var shard_mesh := BoxMesh.new()
		shard_mesh.size = Vector3(randf_range(0.08, 0.14), randf_range(0.04, 0.08), randf_range(0.08, 0.14))
		shard_mesh.material = _pot_mat
		
		var shard := MeshInstance3D.new()
		shard.mesh = shard_mesh
		host.add_child(shard)
		shard.global_position = global_position + Vector3(randf_range(-0.15, 0.15), randf_range(0.15, 0.45), randf_range(-0.15, 0.15))
		shard.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		var spread := Vector3(randf_range(-1.6, 1.6), randf_range(0.8, 2.0), randf_range(-1.6, 1.6)) + push_dir * 1.4
		var target_pos := Vector3(shard.global_position.x + spread.x, 0.04, shard.global_position.z + spread.z)
		
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "rotation", shard.rotation + Vector3(4.0, 5.0, 3.0), 0.35)
		tween.chain().tween_interval(0.35)
		tween.chain().tween_property(shard, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
		tween.chain().tween_callback(shard.queue_free)

func _play_shatter_sound() -> void:
	var host := get_parent() if get_parent() else get_tree().current_scene
	if not host:
		return
	var audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	audio.stream = gen
	audio.volume_db = -14.0
	host.add_child(audio)
	audio.global_position = global_position
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var frames := int(gen.mix_rate * 0.12)
		for i in range(frames):
			var t := float(i) / float(frames)
			var noise := randf_range(-1.0, 1.0) * (1.0 - t) * 0.25
			pb.push_frame(Vector2(noise, noise))
			
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

func _create_terracotta_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var clay_a := Color(0.64, 0.33, 0.20)
	var clay_b := Color(0.54, 0.26, 0.15)
	var clay_hi := Color(0.74, 0.42, 0.26)
	for y in range(16):
		for x in range(16):
			if x == 3 or x == 4:
				img.set_pixel(x, y, clay_hi)
			elif (x + y) % 3 == 0:
				img.set_pixel(x, y, clay_a)
			else:
				img.set_pixel(x, y, clay_b)
	return _to_pixel_mat(img)

func _create_pot_trim_material() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.84, 0.68, 0.36) if (x + y) % 2 == 0 else Color(0.38, 0.18, 0.11))
	return _to_pixel_mat(img)

func _to_pixel_mat(img: Image) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
