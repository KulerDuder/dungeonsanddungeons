class_name ThrownDaggerProjectile
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 22.0
var damage: float = 15.0
var gravity_pull: float = 6.5
var shooter: Node3D = null

var _velocity: Vector3 = Vector3.ZERO
var _visual_pivot: Node3D
var _stuck: bool = false
var _lifetime: float = 4.0

func _ready() -> void:
	_velocity = direction.normalized() * speed
	_build_visual_and_collider()
	body_entered.connect(_on_body_entered)

func _build_visual_and_collider() -> void:
	_visual_pivot = Node3D.new()
	add_child(_visual_pivot)
	
	var wood_mat := _create_wood_mat()
	var grip_mat := _create_grip_mat()
	var gold_mat := _create_gold_mat()
	
	# Pomo dorado
	_add_part(Vector3(0.045, 0.045, 0.04), Vector3(0, 0, 0.16), gold_mat)
	# Empuñadura
	_add_part(Vector3(0.032, 0.032, 0.11), Vector3(0, 0, 0.09), grip_mat)
	# Guarda pequeña
	_add_part(Vector3(0.11, 0.038, 0.035), Vector3(0, 0, 0.02), wood_mat)
	# Hoja corta de daga apuntando hacia -Z
	_add_part(Vector3(0.065, 0.022, 0.22), Vector3(0, 0, -0.10), wood_mat)
	_add_part(Vector3(0.038, 0.022, 0.05), Vector3(0, 0, -0.23), wood_mat)
	
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.14
	col.shape = sphere
	add_child(col)

func _add_part(s: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = s
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	_visual_pivot.add_child(inst)

func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
		
	if _stuck:
		return
		
	_velocity.y -= gravity_pull * delta
	global_position += _velocity * delta
	
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity.normalized(), Vector3.UP)
	# Giro rápido sobre su eje mientras vuela
	_visual_pivot.rotate_x(delta * 26.0)

func _on_body_entered(body: Node3D) -> void:
	if _stuck or body == shooter:
		return
		
	# Ignorar al jugador que la lanzó
	if body.name == "PlayerBody" or (body.get_parent() and body.get_parent().has_method("equip_weapon")):
		return
		
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		queue_free()
	elif body is StaticBody3D:
		# Se queda clavada un segundo en el muro/suelo de piedra
		_stuck = true
		_lifetime = 1.4
		_visual_pivot.rotation.x = deg_to_rad(-18.0)

func _create_wood_mat() -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in range(8):
		for x in range(8):
			img.set_pixel(x, y, Color(0.82, 0.59, 0.36) if (x + y) % 2 == 0 else Color(0.68, 0.45, 0.25))
	return _to_mat(img)

func _create_grip_mat() -> StandardMaterial3D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.32, 0.17, 0.10))
	return _to_mat(img)

func _create_gold_mat() -> StandardMaterial3D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.78, 0.26))
	return _to_mat(img)

func _to_mat(img: Image) -> StandardMaterial3D:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat
