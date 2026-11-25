class_name EnemyProjectile
extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 9.0
var damage: float = 8.0
var lifetime: float = 4.0
var gravity_pull: float = 0.0
var projectile_color: Color = Color(0.4, 0.9, 1.0)
var projectile_size: float = 0.22
var shooter: Node3D = null

var _velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	_velocity = direction.normalized() * speed
	_build_visual_and_collider()
	body_entered.connect(_on_body_entered)

func _build_visual_and_collider() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * projectile_size
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = projectile_color
	mat.emission_enabled = true
	mat.emission = projectile_color
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.3
	mesh.material = mat
	
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	add_child(inst)
	
	var light := OmniLight3D.new()
	light.light_color = projectile_color
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)
	
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = projectile_size * 0.65
	col.shape = sphere
	add_child(col)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
		
	_velocity.y -= gravity_pull * delta
	global_position += _velocity * delta
	rotation += Vector3(6.0, 8.0, 4.0) * delta

func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
		
	# Si golpea al PlayerBody, buscamos su nodo padre Player si tiene take_damage
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		queue_free()
	elif body.get_parent() and body.get_parent().has_method("take_damage"):
		body.get_parent().take_damage(damage, global_position)
		queue_free()
	elif body is StaticBody3D:
		# Impacto contra pared/suelo de la mazmorra
		queue_free()
