class_name ShieldBase
extends WeaponBase

@export var max_durability: float = 25.0

var _durability: float = 25.0
var _shield_pivot: Node3D
var _hp_label: Label3D
var _is_broken: bool = false
var _hit_shake: float = 0.0
var _bob_time: float = 0.0

func _ready() -> void:
	_durability = max_durability
	_shield_pivot = Node3D.new()
	add_child(_shield_pivot)
	
	_build_shield_mesh(_shield_pivot)
	_build_durability_label()
	_apply_handedness()

func set_handedness(left_slot: bool) -> void:
	is_left_hand = left_slot
	_apply_handedness()

func _apply_handedness() -> void:
	if not _shield_pivot:
		return
	var side_sign := -1.0 if is_left_hand else 1.0
	_shield_pivot.position = Vector3(-0.04 * side_sign, -0.02, -0.04)
	_shield_pivot.rotation_degrees = Vector3(6.0, -24.0 * side_sign, -8.0 * side_sign)

## Sobrescribir en cada escudo concreto para dibujar su geometría
func _build_shield_mesh(_pivot: Node3D) -> void:
	pass

## Color de las partículas al romperse (sobrescribir si es de hierro, hueso, cristal...)
func _get_break_shard_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.18)
	return mat

func _build_durability_label() -> void:
	_hp_label = Label3D.new()
	_hp_label.position = Vector3(0.0, 0.24, 0.02)
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.pixel_size = 0.0021
	_hp_label.font_size = 34
	_hp_label.outline_size = 8
	_hp_label.modulate = Color(0.55, 0.88, 1.0)
	_update_durability_text()
	add_child(_hp_label)

func _update_durability_text() -> void:
	if _hp_label:
		_hp_label.text = "%d/%d" % [int(ceil(_durability)), int(max_durability)]

func absorb_damage(incoming_damage: float) -> float:
	if _is_broken or _durability <= 0.0 or incoming_damage <= 0.0:
		return incoming_damage
		
	var absorbed := minf(_durability, incoming_damage)
	var leftover := incoming_damage - absorbed
	_durability -= absorbed
	_update_durability_text()
	
	if _durability <= 0.0:
		_break_shield()
	else:
		_hit_shake = 1.0
		_play_block_sound(false)
		
	return leftover

func _break_shield() -> void:
	if _is_broken:
		return
	_is_broken = true
	_play_block_sound(true)
	_spawn_break_shards()
	queue_free()

func _on_attack_start() -> void:
	_hit_shake = 0.35

func _update_weapon_animation(delta: float) -> void:
	if _is_broken or not _shield_pivot:
		return
		
	_bob_time += delta * 2.4
	var side_sign := -1.0 if is_left_hand else 1.0
	var idle_y := sin(_bob_time) * 0.006
	var shake_z := 0.0
	var shake_rot := 0.0
	
	if _hit_shake > 0.0:
		_hit_shake = maxf(0.0, _hit_shake - delta * 5.5)
		shake_z = _hit_shake * 0.07
		shake_rot = sin(_hit_shake * 28.0) * 14.0 * _hit_shake
		
	var target_pos := Vector3(-0.04 * side_sign, -0.02 + idle_y, -0.04 + shake_z)
	var target_rot := Vector3(6.0 - _hit_shake * 10.0, -24.0 * side_sign, -8.0 * side_sign + shake_rot)
	
	_shield_pivot.position = _shield_pivot.position.lerp(target_pos, delta * 16.0)
	_shield_pivot.rotation_degrees = _shield_pivot.rotation_degrees.lerp(target_rot, delta * 16.0)

func _spawn_break_shards() -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	var mat := _get_break_shard_material()
	for i in range(6):
		var m := BoxMesh.new()
		m.size = Vector3(randf_range(0.05, 0.11), randf_range(0.03, 0.07), 0.025)
		m.material = mat
		var shard := MeshInstance3D.new()
		shard.mesh = m
		scene_root.add_child(shard)
		shard.global_position = global_position + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0.0)
		shard.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		var drift := Vector3(randf_range(-0.7, 0.7), randf_range(-0.6, 0.2), randf_range(-0.7, 0.7))
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + drift, 0.35)
		tween.tween_property(shard, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
		tween.chain().tween_callback(shard.queue_free)

func _play_block_sound(is_break: bool) -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	var audio := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	audio.stream = gen
	audio.volume_db = -10.0
	scene_root.add_child(audio)
	audio.play()
	
	var pb := audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb:
		var dur := 0.20 if is_break else 0.10
		var frames := int(gen.mix_rate * dur)
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			var freq := lerpf(190.0, 55.0, t) if is_break else lerpf(240.0, 115.0, t)
			phase += freq / gen.mix_rate
			var sq := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			var noise := randf_range(-0.4, 0.4) if is_break else 0.0
			var wave := (sq * 0.7 + noise) * (1.0 - t) * 0.28
			pb.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(audio):
			audio.queue_free()
	)

func _add_part_to(parent: Node3D, box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	parent.add_child(inst)

func _to_pixel_mat(img: Image, rough: float) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
