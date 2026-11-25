class_name WeaponBase
extends Node3D

@export var weapon_name: String = "Arma"
@export var damage: float = 10.0
@export var cooldown: float = 0.45

var is_left_hand: bool = false
var _cooldown_timer: float = 0.0
var _is_attacking: bool = false

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	_update_weapon_animation(delta)

## Llamado por el Player al hacer clic izquierdo o derecho
func trigger_use() -> void:
	if _cooldown_timer > 0.0 or _is_attacking:
		return
	_cooldown_timer = cooldown
	_on_attack_start()

## Sobrescribir en cada arma concreta
func _on_attack_start() -> void:
	pass

func _update_weapon_animation(_delta: float) -> void:
	pass

## Permite que cada arma calcule su daño individual (ej. crits o mejoras)
func get_attack_damage() -> float:
	return damage

## Aplica el daño individual de esta arma a cualquier enemigo
func _deal_damage_to(target: Node, hit_from: Vector3) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(get_attack_damage(), hit_from)
