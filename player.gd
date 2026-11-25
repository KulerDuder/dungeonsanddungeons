extends Node3D

signal health_changed(current_hp: float, max_hp: float, took_damage: bool)
signal died

@export_group("Movimiento")
@export var walk_speed: float = 5.2
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.0022

@export_group("Salud")
@export var max_health: float = 100.0

var _body: CharacterBody3D
var _head: Node3D
var _camera: Camera3D
var _left_hand_pivot: Node3D
var _right_hand_pivot: Node3D
var _left_weapon: WeaponBase = null
var _right_weapon: WeaponBase = null

var _current_health: float = 100.0
var _is_dead: bool = false
var _invuln_timer: float = 0.0
var _bob_time: float = 0.0
var _left_hand_base_pos := Vector3(-0.34, -0.28, -0.48)
var _right_hand_base_pos := Vector3(0.34, -0.28, -0.48)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	_build_player_rig()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_current_health = max_health
	health_changed.emit(_current_health, max_health, false)

func _build_player_rig() -> void:
	_body = CharacterBody3D.new()
	_body.name = "PlayerBody"
	add_child(_body)
	
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	col.shape = capsule
	col.position = Vector3(0, 0.85, 0)
	_body.add_child(col)
	
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.52, 0)
	_body.add_child(_head)
	
	_camera = Camera3D.new()
	_camera.name = "FirstPersonCamera"
	_camera.fov = 75.0
	_camera.current = true
	_head.add_child(_camera)
	
	# Linterna / antorcha ambiental del explorador
	var torch := OmniLight3D.new()
	torch.light_color = Color(1.0, 0.84, 0.62)
	torch.light_energy = 2.4
	torch.omni_range = 14.0
	torch.omni_attenuation = 1.35
	torch.position = Vector3(0.0, -0.1, -0.2)
	_camera.add_child(torch)
	
	# Pivotes de ambas manos frente a la cámara
	_left_hand_pivot = Node3D.new()
	_left_hand_pivot.name = "LeftHandSlot"
	_left_hand_pivot.position = _left_hand_base_pos
	_camera.add_child(_left_hand_pivot)
	
	_right_hand_pivot = Node3D.new()
	_right_hand_pivot.name = "RightHandSlot"
	_right_hand_pivot.position = _right_hand_base_pos
	_camera.add_child(_right_hand_pivot)

func spawn_at(world_pos: Vector3) -> void:
	if _body:
		_body.global_position = world_pos + Vector3(0, 0.15, 0)
		_body.velocity = Vector3.ZERO
	_is_dead = false
	_invuln_timer = 0.5
	_current_health = max_health
	health_changed.emit(_current_health, max_health, false)
	_ensure_unarmed_fallback()

func clear_weapons() -> void:
	if is_instance_valid(_left_weapon):
		_left_weapon.queue_free()
	_left_weapon = null
	if is_instance_valid(_right_weapon):
		_right_weapon.queue_free()
	_right_weapon = null

func equip_weapon(weapon: WeaponBase, left_slot: bool = false) -> void:
	if not weapon:
		return
	weapon.is_left_hand = left_slot
	if weapon.has_method("set_handedness"):
		weapon.set_handedness(left_slot)
		
	if left_slot:
		if is_instance_valid(_left_weapon):
			_left_weapon.queue_free()
		_left_weapon = weapon
		_left_hand_pivot.add_child(weapon)
	else:
		if is_instance_valid(_right_weapon):
			_right_weapon.queue_free()
		_right_weapon = weapon
		_right_hand_pivot.add_child(weapon)

## Si una mano queda vacía (al empezar, al gastar las dagas o al romperse un escudo), equipa Puñitos
func _ensure_unarmed_fallback() -> void:
	if not _left_hand_pivot or not _right_hand_pivot:
		return
		
	if not is_instance_valid(_left_weapon) or _left_weapon.is_queued_for_deletion():
		_left_weapon = null
		var left_fist := BareFists.new()
		equip_weapon(left_fist, true)
		
	if not is_instance_valid(_right_weapon) or _right_weapon.is_queued_for_deletion():
		_right_weapon = null
		var right_fist := BareFists.new()
		equip_weapon(right_fist, false)

func take_damage(amount: float, hit_from: Vector3 = Vector3.ZERO) -> void:
	if _is_dead or _invuln_timer > 0.0:
		return
		
	var remaining_damage := amount
	
	# Si llevamos uno o dos escudos equipados, absorben daño pasivamente antes que la vida
	if is_instance_valid(_left_weapon) and not _left_weapon.is_queued_for_deletion() and _left_weapon.has_method("absorb_damage"):
		remaining_damage = _left_weapon.absorb_damage(remaining_damage)
		
	if remaining_damage > 0.0 and is_instance_valid(_right_weapon) and not _right_weapon.is_queued_for_deletion() and _right_weapon.has_method("absorb_damage"):
		remaining_damage = _right_weapon.absorb_damage(remaining_damage)
		
	_invuln_timer = 0.45
	
	if _body and hit_from != Vector3.ZERO:
		var push := (_body.global_position - hit_from)
		push.y = 0.0
		if push.length() > 0.01:
			_body.velocity += push.normalized() * 4.5 + Vector3(0, 2.0, 0)
			
	if remaining_damage > 0.0:
		_current_health = maxf(0.0, _current_health - remaining_damage)
		health_changed.emit(_current_health, max_health, true)
		
	if _current_health <= 0.0:
		_is_dead = true
		died.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _body and _head:
			_body.rotate_y(-event.relative.x * mouse_sensitivity)
			_head.rotate_x(-event.relative.y * mouse_sensitivity)
			_head.rotation.x = clampf(_head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
			
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if _is_dead:
			return
		if event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(_left_weapon):
			_left_weapon.trigger_use()
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_instance_valid(_right_weapon):
			_right_weapon.trigger_use()
			
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not _body:
		return
		
	_ensure_unarmed_fallback()
	
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		
	if not _body.is_on_floor():
		_body.velocity.y -= _gravity * delta
		
	if _is_dead:
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, 12.0 * delta)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, 12.0 * delta)
		_body.move_and_slide()
		return
		
	if Input.is_key_pressed(KEY_SPACE) and _body.is_on_floor():
		_body.velocity.y = jump_velocity
		
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()
	
	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	var direction := (_body.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	
	if direction.length() > 0.01:
		_body.velocity.x = direction.x * speed
		_body.velocity.z = direction.z * speed
	else:
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, speed * 10.0 * delta)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, speed * 10.0 * delta)
		
	_body.move_and_slide()
	_animate_view_bob(delta, Vector2(_body.velocity.x, _body.velocity.z).length() > 0.3 and _body.is_on_floor())

func _animate_view_bob(delta: float, is_walking: bool) -> void:
	if is_walking:
		_bob_time += delta * 10.5
		var bob_x: float = cos(_bob_time * 0.5) * 0.014
		var bob_y: float = absf(sin(_bob_time)) * 0.018
		_left_hand_pivot.position = _left_hand_base_pos + Vector3(bob_x, -bob_y, 0.0)
		_right_hand_pivot.position = _right_hand_base_pos + Vector3(bob_x, -bob_y, 0.0)
	else:
		_left_hand_pivot.position = _left_hand_pivot.position.lerp(_left_hand_base_pos, delta * 10.0)
		_right_hand_pivot.position = _right_hand_pivot.position.lerp(_right_hand_base_pos, delta * 10.0)
