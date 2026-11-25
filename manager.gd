extends Node3D

@export var dungeon: Node3D
@export var player: Node3D
@export var min_enemies_per_room: int = 1
@export var max_enemies_per_room: int = 2

@export_group("Progresión de Tamaño")
@export var start_grid_size: int = 24
@export var start_room_attempts: int = 10
@export var grid_growth_per_floor: int = 6
@export var attempts_growth_per_floor: int = 6

@export_group("Economía")
@export var pot_coin_chance: float = 0.25

var enemy_pool: Array[Dictionary] = [
	{ "script": SkeletonEnemy,    "weight": 45 },
	{ "script": ZombieKnight,     "weight": 25 },
	{ "script": CarnivorousPlant, "weight": 30 }
]

var _current_floor: int = 1
var _player_coins: int = 0
var _is_transitioning_floor: bool = false

var _enemies_container: Node3D
var _chests_container: Node3D
var _pots_container: Node3D
var _minimap: DungeonMinimap
var _health_globe: HealthGlobe
var _coin_hud: CoinHUD
var _loading_screen: LoadingCampfire

func _ready() -> void:
	if not dungeon:
		dungeon = get_parent().get_node_or_null("dung")
	if not player:
		player = get_parent().get_node_or_null("player")
		
	_enemies_container = Node3D.new()
	_enemies_container.name = "Enemies"
	add_child(_enemies_container)
	
	_chests_container = Node3D.new()
	_chests_container.name = "Chests"
	add_child(_chests_container)
	
	_pots_container = Node3D.new()
	_pots_container.name = "Pots"
	add_child(_pots_container)
	
	_minimap = DungeonMinimap.new()
	_minimap.name = "DungeonMinimap"
	add_child(_minimap)
	
	_health_globe = HealthGlobe.new()
	_health_globe.name = "HealthGlobe"
	add_child(_health_globe)
	
	_coin_hud = CoinHUD.new()
	_coin_hud.name = "CoinHUD"
	add_child(_coin_hud)
	
	_loading_screen = LoadingCampfire.new()
	_loading_screen.name = "LoadingCampfire"
	add_child(_loading_screen)
	
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)
			
	_setup_environment()
	await get_tree().process_frame
	start_new_run()

func start_new_run(custom_seed: int = -1) -> void:
	if not dungeon or not player:
		var siblings: Array[String] = []
		if get_parent():
			for c in get_parent().get_children():
				siblings.append("%s (%s)" % [c.name, c.get_script().resource_path if c.get_script() else "sin script"])
		push_error("Manager: dungeon=%s | player=%s | Nodos hermanos: %s" % [dungeon, player, siblings])
		return
		
	_current_floor = 1
	_player_coins = 0
	_is_transitioning_floor = false
	
	if _coin_hud:
		_coin_hud.set_coins(_player_coins, false)
	if player.has_method("clear_weapons"):
		player.clear_weapons()
		
	_generate_floor(_current_floor, custom_seed)

func _generate_floor(floor_num: int, custom_seed: int = -1) -> void:
	var step := floor_num - 1
	dungeon.grid_width = start_grid_size + (step * grid_growth_per_floor)
	dungeon.grid_height = start_grid_size + (step * grid_growth_per_floor)
	dungeon.room_attempts = start_room_attempts + (step * attempts_growth_per_floor)
	
	var spawn_pos: Vector3 = dungeon.generate_dungeon(custom_seed)
	player.spawn_at(spawn_pos)
	_spawn_chests()
	_spawn_pots()
	_spawn_enemies()
	
	if _minimap:
		_minimap.setup(dungeon, player, _enemies_container, _chests_container)

func _process(_delta: float) -> void:
	if _is_transitioning_floor or not _enemies_container:
		return
		
	var alive_count := 0
	for child in _enemies_container.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			alive_count += 1
			
	if alive_count == 0 and dungeon and dungeon.get_child_count() > 0:
		_advance_to_next_floor()

func _advance_to_next_floor() -> void:
	_is_transitioning_floor = true
	_current_floor += 1
	
	if _loading_screen:
		await _loading_screen.show_transition(_current_floor, 2.6)
		
	_generate_floor(_current_floor)
	_is_transitioning_floor = false

func _on_player_health_changed(current_hp: float, max_hp: float, took_damage: bool) -> void:
	if _health_globe:
		_health_globe.set_health(current_hp, max_hp, took_damage)

func _on_player_died() -> void:
	if _is_transitioning_floor:
		return
	_is_transitioning_floor = true
	await get_tree().create_timer(0.45).timeout
	start_new_run()

func _spawn_chests() -> void:
	for child in _chests_container.get_children():
		child.queue_free()
	if not dungeon.has_method("get_chest_spawn_points"):
		return
	for entry in dungeon.get_chest_spawn_points():
		var chest := LootChest.new()
		chest.position = entry["pos"]
		chest.rotation.y = entry["rot_y"]
		_chests_container.add_child(chest)

func _spawn_pots() -> void:
	for child in _pots_container.get_children():
		child.queue_free()
	if not dungeon.has_method("get_pot_spawn_points"):
		return
	for pos in dungeon.get_pot_spawn_points():
		var pot := BreakablePot.new()
		pot.coin_chance = pot_coin_chance
		pot.position = pos
		pot.rotation.y = randf_range(0.0, TAU)
		pot.coin_spawned.connect(_on_pot_coin_spawned)
		_pots_container.add_child(pot)

func _on_pot_coin_spawned(coin: GoldCoin) -> void:
	if coin:
		coin.collected.connect(_on_coin_collected)

func _on_coin_collected(amount: int) -> void:
	_player_coins += amount
	if _coin_hud:
		_coin_hud.set_coins(_player_coins, true)

func _spawn_enemies() -> void:
	for child in _enemies_container.get_children():
		child.queue_free()
	if not dungeon.has_method("get_enemy_spawn_points") or enemy_pool.is_empty():
		return
	for room_center in dungeon.get_enemy_spawn_points():
		var count := randi_range(min_enemies_per_room, max_enemies_per_room)
		for i in range(count):
			var enemy_instance := _pick_random_enemy()
			if enemy_instance:
				var offset := Vector3(randf_range(-1.3, 1.3), 0.1, randf_range(-1.3, 1.3))
				enemy_instance.position = room_center + offset
				_enemies_container.add_child(enemy_instance)

func _pick_random_enemy() -> EnemyBase:
	var total_weight := 0
	for entry in enemy_pool:
		total_weight += entry.get("weight", 1)
	if total_weight <= 0:
		return null
	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for entry in enemy_pool:
		cumulative += entry.get("weight", 1)
		if roll <= cumulative:
			var enemy_script: GDScript = entry["script"]
			return enemy_script.new() as EnemyBase
	return null

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.12)
	env.fog_density = 0.03
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
