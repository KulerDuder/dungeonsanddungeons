class_name EnemyBase
extends CharacterBody3D

@export_group("Estadísticas Base")
@export var max_health: float = 30.0
@export var move_speed: float = 1.6
@export var turn_speed: float = 4.5
@export var detection_range: float = 10.0
@export var attack_range: float = 1.5
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.3

var _health: float
var _visual_root: Node3D
var _move_dir: Vector3 = Vector3.ZERO
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

static var _hurt_red_mat: StandardMaterial3D

func _ready() -> void:
	_health = max_health
	_rng.randomize()
	_ensure_hurt_material()
	
	_visual_root = Node3D.new()
	add_child(_visual_root)
	
	_build_collider()
	_build_visuals()
	_pick_new_wander_direction()

func _ensure_hurt_material() -> void:
	if not _hurt_red_mat:
		_hurt_red_mat = StandardMaterial3D.new()
		_hurt_red_mat.albedo_color = Color(1.0, 0.15, 0.15)
		_hurt_red_mat.emission_enabled = true
		_hurt_red_mat.emission = Color(0.9, 0.05, 0.05)
		_hurt_red_mat.emission_energy_multiplier = 1.5

## Métodos virtuales para sobrescribir en cada enemigo concreto
func _build_collider() -> void:
	pass

func _build_visuals() -> void:
	pass

func _animate_enemy(_delta: float, _is_moving: bool) -> void:
	pass

func _perform_attack(_target_pos: Vector3) -> void:
	pass

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
		
	if not is_on_floor():
		velocity.y -= _gravity * delta
		
	if _attack_timer > 0.0:
		_attack_timer -= delta
		
	var player_body := _find_player_body()
	var dist_to_player := INF
	if player_body:
		dist_to_player = global_position.distance_to(player_body.global_position)
		
	if player_body and dist_to_player <= detection_range:
		_ai_combat_behavior(delta, player_body.global_position, dist_to_player)
	else:
		_ai_wander_behavior(delta)
		
	move_and_slide()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	_animate_enemy(delta, horizontal_speed > 0.15)

func _ai_wander_behavior(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_pick_new_wander_direction()
		
	if is_on_wall() and _move_dir.length() > 0.0:
		_move_dir = _move_dir.bounce(get_wall_normal()).normalized()
		_move_dir.y = 0.0
		_state_timer = _rng.randf_range(1.5, 3.0)
		
	if _move_dir.length() > 0.01:
		velocity.x = _move_dir.x * move_speed
		velocity.z = _move_dir.z * move_speed
		_rotate_toward(_move_dir, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

func _ai_combat_behavior(delta: float, target_pos: Vector3, dist: float) -> void:
	var to_target := (target_pos - global_position)
	to_target.y = 0.0
	if to_target.length() > 0.01:
		to_target = to_target.normalized()
		_rotate_toward(to_target, delta)
		
	if dist > attack_range:
		velocity.x = to_target.x * (move_speed * 1.35)
		velocity.z = to_target.z * (move_speed * 1.35)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 2.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 2.0)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_attack(target_pos)

func _rotate_toward(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, delta * turn_speed)

func _pick_new_wander_direction() -> void:
	if _rng.randf() < 0.3:
		_move_dir = Vector3.ZERO
		_state_timer = _rng.randf_range(1.0, 2.2)
	else:
		var angle := _rng.randf_range(0.0, TAU)
		_move_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
		_state_timer = _rng.randf_range(2.0, 4.0)

## Utilidad lista para que cualquier enemigo lance hechizos o proyectiles
func shoot_projectile(
	spawn_offset: Vector3,
	target_pos: Vector3,
	proj_speed: float = 9.0,
	proj_color: Color = Color(0.95, 0.35, 0.2),
	proj_size: float = 0.22,
	gravity_pull: float = 0.0
) -> void:
	var proj := EnemyProjectile.new()
	proj.shooter = self
	proj.damage = attack_damage
	proj.speed = proj_speed
	proj.projectile_color = proj_color
	proj.projectile_size = proj_size
	proj.gravity_pull = gravity_pull
	
	var origin := global_position + spawn_offset
	var aim_target := target_pos + Vector3(0, 1.1, 0)
	proj.direction = (aim_target - origin).normalized()
	
	get_parent().add_child(proj)
	proj.global_position = origin

## Daño, numerito flotante, destello rojo, sonido procedural y retroceso compartidos
func take_damage(amount: float, hit_from: Vector3) -> void:
	if _is_dead:
		return
		
	_health -= amount
	_spawn_damage_number(amount)
	_play_retro_hit_sound(false)
	_flash_red()
	
	var knockback := (global_position - hit_from)
	knockback.y = 0.0
	if knockback.length() > 0.01:
		velocity += knockback.normalized() * 4.5 + Vector3(0, 2.4, 0)
		
	_visual_root.scale = Vector3(1.25, 0.75, 1.25)
	var tween := create_tween()
	tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.16)
	
	if _health <= 0.0:
		_die()

## Genera un número flotante 3D encima del enemigo que salta y se desvanece
func _spawn_damage_number(amount: float) -> void:
	var lbl := Label3D.new()
	# Formatea sin decimales si es entero (ej. "12") o con 1 decimal si hace falta (ej. "7.5")
	if is_equal_approx(amount, round(amount)):
		lbl.text = str(int(round(amount)))
	else:
		lbl.text = "%.1f" % amount
		
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true # Siempre visible incluso si queda detrás de un brazo o pared cercana
	lbl.pixel_size = 0.0065
	lbl.font_size = 44
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.08, 0.04, 0.04, 1.0)
	lbl.modulate = Color(1.0, 0.92, 0.35, 1.0) # Amarillo cálido estilo retro
	
	# Lo añadimos al contenedor padre (Enemies) para que siga flotando aunque el enemigo muera
	var host: Node = get_parent() if get_parent() else self
	host.add_child(lbl)
	
	var jitter := Vector3(_rng.randf_range(-0.25, 0.25), 1.25, _rng.randf_range(-0.25, 0.25))
	var start_pos := global_position + jitter
	lbl.global_position = start_pos
	
	var peak_pos := start_pos + Vector3(_rng.randf_range(-0.35, 0.35), 0.85, _rng.randf_range(-0.35, 0.35))
	
	# Animación de salto pop-up + desvanecimiento
	lbl.scale = Vector3(0.4, 0.4, 0.4)
	var tween := lbl.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "global_position", peak_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "scale", Vector3(1.15, 1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(lbl, "scale", Vector3(0.85, 0.85, 0.85), 0.35)
	
	var fade_tween := lbl.create_tween()
	fade_tween.tween_interval(0.25)
	fade_tween.tween_property(lbl, "modulate:a", 0.0, 0.35)
	fade_tween.tween_property(lbl, "outline_modulate:a", 0.0, 0.35)
	fade_tween.chain().tween_callback(lbl.queue_free)

func _flash_red() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(_visual_root, meshes)
	for m in meshes:
		m.material_override = _hurt_red_mat
		
	get_tree().create_timer(0.11).timeout.connect(func() -> void:
		if is_instance_valid(self):
			for m in meshes:
				if is_instance_valid(m):
					m.material_override = null
	)

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		_collect_meshes(child, out)

func _die() -> void:
	_is_dead = true
	_play_retro_hit_sound(true)
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(_visual_root, "scale", Vector3(1.3, 0.05, 1.3), 0.22)
	tween.tween_callback(queue_free)

## Sintetizador procedural 8-bit de impacto/muerte
func _play_retro_hit_sound(is_death: bool) -> void:
	var player_audio := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	player_audio.stream = gen
	player_audio.unit_size = 6.0
	player_audio.volume_db = -36.0
	add_child(player_audio)
	player_audio.play()
	
	var playback := player_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(gen.mix_rate * (0.20 if is_death else 0.09))
		var phase := 0.0
		for i in range(frames):
			var t := float(i) / float(frames)
			var freq := lerpf(240.0, 55.0, t) if is_death else lerpf(320.0, 120.0, t)
			phase += freq / gen.mix_rate
			var wave := (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * (1.0 - t) * 0.35
			playback.push_frame(Vector2(wave, wave))
			
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(player_audio):
			player_audio.queue_free()
	)

func _find_player_body() -> Node3D:
	var root := get_tree().current_scene
	if not root:
		return null
	return root.find_child("PlayerBody", true, false) as Node3D

## Helpers compartidos para construir geometría y texturas pixeladas rápidas
func _make_box(s: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	return inst

func _make_pixel_mat(img: Image, rough: float = 0.85) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = rough
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
