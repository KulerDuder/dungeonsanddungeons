class_name StatusEffectManager
extends RefCounted

## Aplica o refresca un efecto de quemadura sobre cualquier nodo con take_damage()
static func apply_burn(target: Node3D, duration: float = 3.5, tick_damage: float = 1.0, tick_interval: float = 0.85) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
		
	var existing := target.get_node_or_null("BurnStatusEffect") as _BurnEffectNode
	if existing:
		existing.refresh(duration, tick_damage, tick_interval)
		return
		
	var effect := _BurnEffectNode.new()
	effect.name = "BurnStatusEffect"
	effect.setup(target, duration, tick_damage, tick_interval)
	target.add_child(effect)


class _BurnEffectNode extends Node3D:
	var _target: Node3D
	var _remaining_time: float = 3.5
	var _tick_damage: float = 1.0
	var _tick_interval: float = 0.85
	var _tick_timer: float = 0.85
	var _spark_timer: float = 0.0
	var _fire_light: OmniLight3D
	var _flame_core: MeshInstance3D

	func setup(target: Node3D, duration: float, tick_dmg: float, interval: float) -> void:
		_target = target
		_remaining_time = duration
		_tick_damage = tick_dmg
		_tick_interval = interval
		_tick_timer = interval

	func refresh(duration: float, tick_dmg: float, interval: float) -> void:
		_remaining_time = maxf(_remaining_time, duration)
		_tick_damage = maxf(_tick_damage, tick_dmg)
		_tick_interval = interval

	func _ready() -> void:
		position = Vector3(0.0, 0.55, 0.0)
		
		# Llama voxel parpadeante pegada al torso del enemigo
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.32, 0.42, 0.32)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.42, 0.08, 0.72)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.05)
		mat.emission_energy_multiplier = 2.4
		mesh.material = mat
		
		_flame_core = MeshInstance3D.new()
		_flame_core.mesh = mesh
		add_child(_flame_core)
		
		_fire_light = OmniLight3D.new()
		_fire_light.light_color = Color(1.0, 0.48, 0.12)
		_fire_light.light_energy = 1.8
		_fire_light.omni_range = 3.2
		add_child(_fire_light)

	func _process(delta: float) -> void:
		if not is_instance_valid(_target) or _target.is_queued_for_deletion():
			queue_free()
			return
			
		_remaining_time -= delta
		if _remaining_time <= 0.0:
			queue_free()
			return
			
		# Animación visual de fuego vivo
		var t := Time.get_ticks_msec() * 0.015
		if _flame_core:
			_flame_core.rotation.y += delta * 6.5
			_flame_core.scale = Vector3(
				0.9 + sin(t) * 0.18,
				0.85 + cos(t * 1.4) * 0.25,
				0.9 + sin(t * 0.8) * 0.18
			)
		if _fire_light:
			_fire_light.light_energy = 1.7 + sin(t * 1.7) * 0.45
			
		# Chispas ascendentes periódicas
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = 0.14
			_spawn_ember()
			
		# Daño periódico por quemadura
		_tick_timer -= delta
		if _tick_timer <= 0.0:
			_tick_timer = _tick_interval
			if _target.has_method("take_damage"):
				_target.take_damage(_tick_damage, _target.global_position)

	func _spawn_ember() -> void:
		var host := get_tree().current_scene
		if not host:
			return
		var ember_mesh := BoxMesh.new()
		ember_mesh.size = Vector3(0.06, 0.06, 0.06)
		var mat := StandardMaterial3D.new()
		var is_hot := randf() > 0.4
		mat.albedo_color = Color(1.0, 0.82, 0.22) if is_hot else Color(1.0, 0.35, 0.08)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 2.6
		ember_mesh.material = mat
		
		var ember := MeshInstance3D.new()
		ember.mesh = ember_mesh
		host.add_child(ember)
		ember.global_position = global_position + Vector3(randf_range(-0.22, 0.22), randf_range(-0.15, 0.25), randf_range(-0.22, 0.22))
		
		var target_pos := ember.global_position + Vector3(randf_range(-0.18, 0.18), randf_range(0.55, 0.95), randf_range(-0.18, 0.18))
		var tween := ember.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ember, "global_position", target_pos, 0.38)
		tween.tween_property(ember, "scale", Vector3(0.01, 0.01, 0.01), 0.38)
		tween.chain().tween_callback(ember.queue_free)
