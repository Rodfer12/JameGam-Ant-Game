@tool
extends Node2D

const ROOM_SIZE := Vector2(480.0, 272.0)
const ROOM_MARGIN := 18.0
const SPRITE_CELL_SIZE := Vector2(90.0, 96.0)
const PLAYER_SPEED := 125.0
const ATTACK_COOLDOWN := 0.42
const POISON_SPEED := 260.0
const POISON_DAMAGE := 1
const POISON_DURATION := 1.4
const POISON_TICK_RATE := 1.0
const MAX_HEALTH := 3
const EFFECT_LIFETIME := 0.28
const DEATH_ANIMATION_DURATION := 0.9
const PAUSE_ITEMS := ["RESUME", "RESTART RUN", "MAIN MENU"]

const ANT_COLORS := [
	{"name": "BROWN", "column": 0},
	{"name": "RED", "column": 3},
	{"name": "GREEN", "column": 6},
	{"name": "GREY", "column": 9}
]

const LEVELS := [
	{"name": "ROOTBOUND ENTRY", "subtitle": "Find a way through", "enemy": "SCOUT", "quirk": "DASHES", "health": 5, "speed": 58.0, "color": "#5a382b"},
	{"name": "FUNGUS GALLERY", "subtitle": "The spores are moving", "enemy": "STALKER", "quirk": "ORBITS", "health": 7, "speed": 62.0, "color": "#3b4b38"},
	{"name": "CRYSTAL DESCENT", "subtitle": "No light reaches here", "enemy": "HUNTER", "quirk": "SIDESTEPS", "health": 9, "speed": 70.0, "color": "#303c5b"},
	{"name": "OLD NURSERY", "subtitle": "Something is guarding the eggs", "enemy": "GUARD", "quirk": "SIDESTEPS", "health": 10, "speed": 56.0, "color": "#4b3b57"},
	{"name": "SCARLET VEIN", "subtitle": "The colony runs deep", "enemy": "STALKER", "quirk": "ORBITS", "health": 12, "speed": 66.0, "color": "#5b3038"},
	{"name": "CRYSTAL WARREN", "subtitle": "The walls are listening", "enemy": "HUNTER", "quirk": "SIDESTEPS", "health": 13, "speed": 70.0, "color": "#303c5b"},
	{"name": "MUSHROOM GROTTO", "subtitle": "Spores hide the patrols", "enemy": "STALKER", "quirk": "ORBITS", "health": 14, "speed": 62.0, "color": "#3b4b38"},
	{"name": "OLD NURSERY", "subtitle": "Protect the next generation", "enemy": "GUARD", "quirk": "SIDESTEPS", "health": 15, "speed": 56.0, "color": "#4b3b57"},
	{"name": "QUEEN'S ANTECHAMBER", "subtitle": "The royal guard waits", "enemy": "GUARD", "quirk": "DASHES", "health": 17, "speed": 60.0, "color": "#5b3038"},
	{"name": "THE QUEEN'S NEST", "subtitle": "Face the colony's ruler", "enemy": "QUEEN", "quirk": "ENRAGES", "health": 22, "speed": 46.0, "color": "#5c293f"}
]

var ant_texture: Texture2D = preload("res://art/Ants.png")
var bug_texture: Texture2D = preload("res://art/Bugs.png")
var brown_floor_texture: Texture2D = preload("res://art/Cave Tileset/Cave Tileset/Brown_Tile_Terrain (16 x 16).png")
var gray_floor_texture: Texture2D = preload("res://art/Cave Tileset/Cave Tileset/Gray_Tile_Terrain (16 x 16).png")
var cave_background_texture: Texture2D = preload("res://art/Cave Tileset/Cave Tileset/_Complete_static_BG_(288 x 208).png")
var scaffolding_texture: Texture2D = preload("res://art/Cave Tileset/Cave Tileset/Scaffolding_and_BG_Parts (16 x 16).png")
var slash_texture: Texture2D = preload("res://sfx/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/addons/kenney_particle_pack/slash_01.png")
var spark_texture: Texture2D = preload("res://sfx/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/addons/kenney_particle_pack/spark_01.png")
var magic_texture: Texture2D = preload("res://sfx/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/addons/kenney_particle_pack/magic_01.png")
var ui_click: AudioStream = preload("res://audio/kenney_ui-audio/Audio/click1.ogg")
var attack_sound: AudioStream = preload("res://audio/kenney_rpg-audio/Audio/knifeSlice.ogg")
var hit_sound: AudioStream = preload("res://audio/kenney_rpg-audio/Audio/chop.ogg")
var hurt_sound: AudioStream = preload("res://audio/kenney_rpg-audio/Audio/cloth1.ogg")
var footstep_sound: AudioStream = preload("res://audio/kenney_rpg-audio/Audio/footstep00.ogg")
var door_sound: AudioStream = preload("res://audio/kenney_rpg-audio/Audio/doorOpen_1.ogg")
var player_position := Vector2(72.0, 136.0)
var enemy_position := Vector2(350.0, 136.0)
var player_health := MAX_HEALTH
var player_max_health := MAX_HEALTH
var enemy_health := 3
var enemy_poison_time := 0.0
var enemy_poison_tick := 0.0
var selected_ant := 0
var demo_mode := false
var level_index := 0
var attack_cooldown := 0.0
var attack_flash := 0.0
var enemy_flash := 0.0
var transition_time := 0.0
var run_complete := false
var game_over := false
var death_animation_time := 0.0
var paused := false
var pause_index := 0
var last_move_direction := Vector2.RIGHT
var player_anim_time := 0.0
var enemy_anim_time := 0.0
var player_is_moving := false
var effects: Array[Dictionary] = []
var poison_projectiles: Array[Dictionary] = []
var choosing_powerup := false
var powerup_choices: Array[Dictionary] = []
var enemy_behavior_time := 0.0
var enemy_contact_cooldown := 0.0
var enemy_orbit_direction := 1.0
var enemy_path_timer := 0.0
var step_timer := 0.0
var audio_player: AudioStreamPlayer
var room_entry_direction := 0
var room_enemy_health: Array[int] = []
var cleared_rooms: Array[bool] = []
var previous_player_position := Vector2.ZERO
var death_menu_layer: CanvasLayer
var death_menu: Control
@onready var torch_light: PointLight2D = $PlayerTorch
@onready var camera: Camera2D = $Camera2D
var torch_flicker_time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	selected_ant = get_node("/root/GameState").selected_ant
	demo_mode = get_node("/root/GameState").demo_mode
	player_max_health = get_node("/root/GameState").max_health
	player_health = player_max_health
	_populate_background_tile_map()
	_initialize_room_state()
	_start_level(0)
	camera.position = player_position
	$BackgroundTileMap.visible = true
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	_create_death_menu()
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_torch_light(delta)
	camera.position = player_position
	if choosing_powerup:
		queue_redraw()
		return
	if game_over:
		death_animation_time = minf(death_animation_time + delta, DEATH_ANIMATION_DURATION)
		player_anim_time += delta
		queue_redraw()
		return
	if paused or run_complete:
		queue_redraw()
		return
	if transition_time > 0.0:
		transition_time = maxf(transition_time - delta, 0.0)
		queue_redraw()
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	attack_flash = maxf(attack_flash - delta, 0.0)
	enemy_flash = maxf(enemy_flash - delta, 0.0)
	enemy_contact_cooldown = maxf(enemy_contact_cooldown - delta, 0.0)
	enemy_behavior_time += delta
	enemy_poison_time = maxf(enemy_poison_time - delta, 0.0)
	enemy_poison_tick = maxf(enemy_poison_tick - delta, 0.0)
	step_timer = maxf(step_timer - delta, 0.0)
	for effect in effects:
		effect["life"] = float(effect["life"]) - delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return float(effect["life"]) > 0.0)
	_update_poison_projectiles(delta)
	if enemy_poison_time > 0.0 and enemy_poison_tick <= 0.0 and enemy_health > 0:
		enemy_poison_tick = POISON_TICK_RATE
		enemy_health -= get_node("/root/GameState").poison_damage
		room_enemy_health[level_index] = enemy_health
		_spawn_effect(spark_texture, enemy_position, Color("#8bf08b"), 0.8)
		_play_sound(hit_sound, -8.0)
		if enemy_health <= 0:
			room_enemy_health[level_index] = 0
			cleared_rooms[level_index] = true
			_spawn_effect(magic_texture, enemy_position, Color("#8bf08b"), 1.8)
	player_anim_time += delta
	enemy_anim_time += delta
	_move_player(delta)
	_move_enemy(delta)
	_check_exit()
	queue_redraw()

func _update_torch_light(delta: float) -> void:
	torch_flicker_time += delta
	torch_light.position = player_position
	var slow_wave := sin(torch_flicker_time * 7.3) * 0.055
	var fast_wave := sin(torch_flicker_time * 19.0 + 1.7) * 0.025
	var irregular_pulse := sin(torch_flicker_time * 2.1 + sin(torch_flicker_time * 0.8)) * 0.035
	torch_light.energy = clampf(0.82 + slow_wave + fast_wave + irregular_pulse, 0.68, 0.98)
	torch_light.texture_scale = 1.05 + (torch_light.energy - 0.82) * 0.22

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if game_over:
			return
		if paused:
			_handle_pause_input(event.keycode)
			return
		match event.keycode:
			KEY_SPACE:
				if not paused and not game_over and not run_complete:
					if choosing_powerup:
						_choose_powerup(0)
					else:
						_attack()
			KEY_1, KEY_2, KEY_3:
				if choosing_powerup:
					_choose_powerup(event.keycode - KEY_1)
			KEY_ESCAPE:
				if not game_over and not run_complete:
					paused = not paused
					pause_index = 0
					_play_sound(ui_click)
			KEY_R:
				if game_over or run_complete:
					_restart_run()
			KEY_ENTER, KEY_KP_ENTER:
				pass

func _handle_pause_input(keycode: Key) -> void:
	match keycode:
		KEY_UP, KEY_W:
			pause_index = posmod(pause_index - 1, PAUSE_ITEMS.size())
			_play_sound(ui_click)
		KEY_DOWN, KEY_S:
			pause_index = posmod(pause_index + 1, PAUSE_ITEMS.size())
			_play_sound(ui_click)
		KEY_ESCAPE:
			paused = false
			_play_sound(ui_click)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			match pause_index:
				0:
					paused = false
					_play_sound(ui_click)
				1:
					_restart_run()
				2:
					get_tree().change_scene_to_file("res://main_menu.tscn")

func _start_level(index: int) -> void:
	level_index = clampi(index, 0, LEVELS.size() - 1)
	var level: Dictionary = LEVELS[level_index]
	player_position = $BackgroundTileMap.world_center($BackgroundTileMap.get_rooms()[level_index])
	enemy_position = $BackgroundTileMap.world_center($BackgroundTileMap.get_rooms()[level_index]) + Vector2(88.0, 0.0)
	enemy_health = room_enemy_health[level_index]
	choosing_powerup = false
	powerup_choices.clear()
	enemy_behavior_time = 0.0
	enemy_contact_cooldown = 0.0
	enemy_orbit_direction = -enemy_orbit_direction
	enemy_path_timer = 0.0
	enemy_poison_time = 0.0
	enemy_poison_tick = 0.0
	poison_projectiles.clear()
	transition_time = 0.0
	attack_cooldown = 0.0
	attack_flash = 0.0
	enemy_flash = 0.0
	effects.clear()
	death_animation_time = 0.0
	_spawn_effect(magic_texture, Vector2(ROOM_SIZE.x / 2.0, ROOM_SIZE.y / 2.0), Color("#a98cff"), 1.2)
	_play_sound(door_sound)

func _restart_run() -> void:
	get_node("/root/GameState").reset_run()
	_initialize_room_state()
	player_health = MAX_HEALTH
	player_max_health = MAX_HEALTH
	run_complete = false
	game_over = false
	death_animation_time = 0.0
	paused = false
	_start_level(0)

func _initialize_room_state() -> void:
	room_enemy_health.clear()
	cleared_rooms.clear()
	for level in LEVELS:
		room_enemy_health.append(int(level["health"]))
		cleared_rooms.append(false)

func _create_death_menu() -> void:
	death_menu_layer = CanvasLayer.new()
	death_menu_layer.name = "DeathMenuLayer"
	death_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	death_menu_layer.layer = 20
	add_child(death_menu_layer)
	death_menu = Control.new()
	death_menu.name = "DeathMenu"
	death_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	death_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	death_menu.visible = false
	death_menu_layer.add_child(death_menu)
	var shade := ColorRect.new()
	shade.color = Color("#0d1018", 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_menu.add_child(shade)
	var panel := Panel.new()
	panel.name = "DeathPanel"
	panel.position = Vector2(62, 38)
	panel.size = Vector2(356, 196)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#211a2a", 0.98)
	panel_style.border_color = Color("#d85b7d")
	panel_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_style)
	death_menu.add_child(panel)
	var title := Label.new()
	title.text = "COLONY LOST"
	title.position = Vector2(0, 25)
	title.size = Vector2(356, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ff9a9f"))
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE GUARD REACHED YOUR NEST"
	subtitle.position = Vector2(0, 62)
	subtitle.size = Vector2(356, 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color("#f4d9ad"))
	panel.add_child(subtitle)
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "RESTART RUN"
	restart.position = Vector2(78, 118)
	restart.size = Vector2(200, 28)
	restart.focus_mode = Control.FOCUS_ALL
	restart.pressed.connect(_restart_from_death_menu)
	panel.add_child(restart)
	var menu_button := Button.new()
	menu_button.name = "MainMenuButton"
	menu_button.text = "MAIN MENU"
	menu_button.position = Vector2(78, 153)
	menu_button.size = Vector2(200, 28)
	menu_button.focus_mode = Control.FOCUS_ALL
	menu_button.pressed.connect(_return_from_death_menu)
	panel.add_child(menu_button)
	restart.grab_focus()

func _show_death_menu() -> void:
	if death_menu != null:
		death_menu.visible = true
		get_tree().paused = true

func _restart_from_death_menu() -> void:
	get_tree().paused = false
	death_menu.visible = false
	_restart_run()
	enemy_contact_cooldown = 1.0
	player_health = player_max_health

func _return_from_death_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _populate_background_tile_map() -> void:
	$BackgroundTileMap.generate(1337)

func _move_player(delta: float) -> void:
	previous_player_position = player_position
	var movement := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	movement += Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	movement = movement.normalized()
	player_is_moving = movement != Vector2.ZERO
	if player_is_moving:
		last_move_direction = movement
		var movement_delta: Vector2 = movement * get_node("/root/GameState").player_speed * delta
		player_position = _move_with_walls(player_position, movement_delta, 11.0)
		if step_timer <= 0.0:
			step_timer = 0.18
			_play_sound(footstep_sound, -12.0)
	var entered_room: int = $BackgroundTileMap.room_index_at_world(player_position)
	if entered_room == -1 and not cleared_rooms[level_index]:
		player_position = previous_player_position
	elif entered_room >= 0 and entered_room != level_index and not cleared_rooms[level_index]:
		player_position = previous_player_position
	else:
		_check_room_transition()

func _move_with_walls(position: Vector2, movement: Vector2, radius: float) -> Vector2:
	var result := position
	var horizontal := Vector2(movement.x, 0.0)
	if not _hits_wall(result + horizontal, radius):
		result += horizontal
	var vertical := Vector2(0.0, movement.y)
	if not _hits_wall(result + vertical, radius):
		result += vertical
	return result

func _hits_wall(position: Vector2, radius: float) -> bool:
	return $BackgroundTileMap.is_wall_at_world(position, radius)

func _move_enemy(delta: float) -> void:
	if enemy_health <= 0:
		return
	var level: Dictionary = LEVELS[level_index]
	var direction := _enemy_path_direction(delta)
	var quirk: String = level["quirk"]
	var movement := direction
	if quirk == "ORBITS":
		movement = (direction * 0.45 + direction.rotated(PI / 2.0 * enemy_orbit_direction) * 0.9).normalized()
	elif quirk == "SIDESTEPS":
		movement = direction.rotated(sin(enemy_behavior_time * 5.0) * 0.8).normalized()
	elif quirk == "DASHES" and fmod(enemy_behavior_time, 2.4) < 0.35:
		movement = direction * 2.4
	elif quirk == "ENRAGES" and enemy_health <= level["health"] / 2:
		movement = direction * 1.8
	var previous_enemy_position := enemy_position
	enemy_position += movement * level["speed"] * delta
	enemy_position = _move_with_walls(previous_enemy_position, enemy_position - previous_enemy_position, 11.0)
	if enemy_position.distance_to(player_position) < 19.0 and enemy_contact_cooldown <= 0.0:
		enemy_contact_cooldown = 0.85
		player_health -= 1
		_spawn_effect(spark_texture, player_position, Color("#ff6b6b"), 0.8)
		_play_sound(hurt_sound)
		enemy_position = player_position - direction * 28.0
		if player_health <= 0:
			game_over = true
			death_animation_time = 0.0
			_show_death_menu()
			_spawn_effect(magic_texture, player_position, Color("#ff6b8a"), 1.4)
			_play_sound(door_sound, -8.0)

func _enemy_path_direction(delta: float) -> Vector2:
	enemy_path_timer -= delta
	if enemy_path_timer > 0.0:
		var direct_direction := enemy_position.direction_to(player_position)
		if not _projectile_hits_wall(enemy_position, enemy_position + direct_direction * 24.0):
			return direct_direction
	enemy_path_timer = 0.18
	var start := _navigation_cell(enemy_position)
	var target := _navigation_cell(player_position)
	if start == target:
		return enemy_position.direction_to(player_position)
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var found := false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == target:
			found = true
			break
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if next.x < 1 or next.x > 28 or next.y < 2 or next.y > 15:
				continue
			if next in came_from:
				continue
			var next_position := _navigation_position(next)
			if _hits_wall(next_position, 10.0):
				continue
			came_from[next] = current
			queue.append(next)
	if not found:
		return enemy_position.direction_to(player_position)
	var waypoint := target
	var path_steps := 0
	while came_from.has(waypoint) and came_from[waypoint] != start and path_steps < 64:
		waypoint = came_from[waypoint]
		path_steps += 1
	if not came_from.has(waypoint):
		return enemy_position.direction_to(player_position)
	return enemy_position.direction_to(_navigation_position(waypoint))

func _navigation_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(position.x / 16.0), 1, 28),
		clampi(floori(position.y / 16.0), 2, 15)
	)

func _navigation_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)

func _attack() -> void:
	if attack_cooldown > 0.0 or enemy_health <= 0:
		return
	attack_cooldown = get_node("/root/GameState").attack_cooldown
	attack_flash = 0.12
	poison_projectiles.append({
		"position": player_position + last_move_direction * 18.0,
		"velocity": last_move_direction * POISON_SPEED,
		"life": 1.2
	})
	_spawn_effect(slash_texture, player_position + last_move_direction * 16.0, Color("#8bf08b"), 0.7)
	_play_sound(attack_sound, -4.0)

func _update_poison_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for projectile in poison_projectiles:
		var previous_position: Vector2 = projectile["position"]
		var next_position: Vector2 = previous_position + projectile["velocity"] * delta
		projectile["life"] = float(projectile["life"]) - delta
		if _projectile_hits_wall(previous_position, next_position):
			_spawn_effect(spark_texture, next_position, Color("#8ba4b8"), 0.45)
			continue
		projectile["position"] = next_position
		if enemy_health > 0 and next_position.distance_to(enemy_position) < 24.0:
			enemy_poison_time = get_node("/root/GameState").poison_duration
			enemy_poison_tick = 0.0
			enemy_flash = 0.12
			_spawn_effect(spark_texture, enemy_position, Color("#8bf08b"), 1.0)
			_play_sound(hit_sound, -3.0)
			continue
		if float(projectile["life"]) > 0.0:
			remaining.append(projectile)
	poison_projectiles = remaining

func _projectile_hits_wall(start: Vector2, end: Vector2) -> bool:
	var distance := start.distance_to(end)
	var steps := maxi(1, ceili(distance / 4.0))
	for step in range(1, steps + 1):
		var point := start.lerp(end, float(step) / float(steps))
		if _hits_wall(point, 2.0):
			return true
	return false

func _check_exit() -> void:
	if enemy_health <= 0:
		_check_room_transition()

func _check_room_transition() -> void:
	var entered_room: int = $BackgroundTileMap.room_index_at_world(player_position)
	if entered_room < 0 or entered_room == level_index:
		return
	if enemy_health <= 0:
		cleared_rooms[level_index] = true
	level_index = entered_room
	enemy_position = $BackgroundTileMap.world_center($BackgroundTileMap.get_rooms()[level_index]) + Vector2(88.0, 0.0)
	enemy_health = 0 if cleared_rooms[level_index] else LEVELS[level_index]["health"]
	enemy_behavior_time = 0.0
	enemy_path_timer = 0.0
	enemy_contact_cooldown = 0.0
	if level_index == LEVELS.size() - 1 and enemy_health <= 0:
		_open_powerups()

func _open_powerups() -> void:
	if choosing_powerup:
		return
	choosing_powerup = true
	powerup_choices = [
		{"name": "TOXIC GLAND", "description": "+1 poison damage per tick", "type": "damage"},
		{"name": "LIGHT LEGS", "description": "+20% movement speed", "type": "speed"},
		{"name": "THICK CARAPACE", "description": "+1 maximum health and heal", "type": "health"}
	]
	if level_index == 1:
		powerup_choices[1] = {"name": "RAPID FANGS", "description": "Poison shots recharge faster", "type": "cooldown"}

func _choose_powerup(index: int) -> void:
	if index < 0 or index >= powerup_choices.size():
		return
	var state = get_node("/root/GameState")
	match powerup_choices[index]["type"]:
		"damage":
			state.poison_damage += 1
		"speed":
			state.player_speed *= 1.2
		"health":
			state.max_health += 1
			player_max_health = state.max_health
			player_health = player_max_health
		"cooldown":
			state.attack_cooldown = maxf(0.18, state.attack_cooldown - 0.08)
	choosing_powerup = false
	_play_sound(ui_click)
	if level_index == LEVELS.size() - 1:
		run_complete = true
		_spawn_effect(magic_texture, enemy_position, Color("#f6c85f"), 2.3)
		_play_sound(door_sound)

func _draw() -> void:
	_draw_room_background()
	_draw_enemy()
	_draw_player()
	_draw_effects()
	_draw_poison_projectiles()
	var camera_offset := camera.position - Vector2(240.0, 136.0)
	draw_set_transform(camera_offset)
	_draw_hud()
	if choosing_powerup:
		_draw_powerup_menu()
	elif paused:
		_draw_pause_menu()
	elif game_over:
		pass
	elif run_complete:
		_draw_state_overlay(Color("#f6c85f", 0.7))
	elif transition_time > 0.0:
		draw_rect(Rect2(0, 0, ROOM_SIZE.x, ROOM_SIZE.y), Color("#17131c", 0.82), true)
		draw_circle(Vector2(ROOM_SIZE.x / 2.0, ROOM_SIZE.y / 2.0), 26.0 + sin(transition_time * 12.0) * 5.0, Color("#a98cff", 0.5))
	draw_set_transform(Vector2.ZERO)

func _draw_room_background() -> void:
	if level_index >= 4:
		draw_texture_rect(cave_background_texture, Rect2(player_position - Vector2(144.0, 104.0), Vector2(288.0, 208.0)), false, Color(1.0, 1.0, 1.0, 0.12))

func _draw_tunnel_shadows() -> void:
	var shadow := Color("#261923", 0.72) if level_index == 3 else Color("#30201d", 0.58)
	match level_index:
		0:
			draw_rect(Rect2(176, 80, 16, 96), shadow, true)
			draw_rect(Rect2(288, 80, 16, 96), shadow, true)
			draw_circle(Vector2(240, 136), 26.0, shadow)
		1:
			for wall in [Rect2(96, 48, 16, 80), Rect2(96, 176, 16, 48), Rect2(224, 48, 16, 96), Rect2(224, 192, 16, 32), Rect2(352, 48, 16, 48), Rect2(352, 144, 16, 80)]:
				draw_rect(wall, shadow, true)
		2:
			draw_rect(Rect2(144, 80, 192, 16), shadow, true)
			draw_rect(Rect2(144, 176, 192, 16), shadow, true)
			draw_rect(Rect2(144, 80, 16, 112), shadow, true)
			draw_rect(Rect2(320, 80, 16, 112), shadow, true)
		3:
			draw_rect(Rect2(192, 64, 96, 16), shadow, true)
			draw_rect(Rect2(192, 192, 96, 16), shadow, true)
			draw_rect(Rect2(192, 64, 16, 144), shadow, true)
			draw_rect(Rect2(272, 64, 16, 144), shadow, true)
		4:
			draw_rect(Rect2(80, 80, 80, 96), shadow, true)
			draw_rect(Rect2(320, 80, 80, 96), shadow, true)
			draw_circle(Vector2(240, 136), 35.0, shadow)
		5:
			draw_circle(Vector2(240, 136), 56.0, shadow)

func _room_walls() -> Array[Rect2]:
	match level_index:
		0:
			return [
				Rect2(16, 32, 448, 16), Rect2(16, 224, 448, 16),
				Rect2(16, 32, 16, 80), Rect2(16, 160, 16, 80),
				Rect2(448, 32, 16, 80), Rect2(448, 160, 16, 80),
				Rect2(176, 80, 16, 96), Rect2(288, 80, 16, 96)
			]
		1:
			return [
				Rect2(16, 32, 448, 16), Rect2(16, 224, 448, 16),
				Rect2(16, 32, 16, 80), Rect2(16, 160, 16, 80),
				Rect2(448, 32, 16, 80), Rect2(448, 160, 16, 80),
				Rect2(96, 48, 16, 80), Rect2(96, 176, 16, 48),
				Rect2(224, 48, 16, 96), Rect2(224, 192, 16, 32),
				Rect2(352, 48, 16, 48), Rect2(352, 144, 16, 80)
			]
		2:
			return [
				Rect2(16, 32, 448, 16), Rect2(16, 224, 448, 16),
				Rect2(16, 32, 16, 80), Rect2(16, 160, 16, 80),
				Rect2(448, 32, 16, 80), Rect2(448, 160, 16, 80),
				Rect2(144, 80, 192, 16), Rect2(144, 176, 192, 16),
				Rect2(144, 80, 16, 112), Rect2(320, 80, 16, 112)
			]
		_:
			return [
				Rect2(16, 32, 448, 16), Rect2(16, 224, 448, 16),
				Rect2(16, 32, 16, 80), Rect2(16, 160, 16, 80),
				Rect2(448, 32, 16, 80), Rect2(448, 160, 16, 80),
				Rect2(192, 64, 32, 16), Rect2(256, 64, 32, 16),
				Rect2(192, 192, 32, 16), Rect2(256, 192, 32, 16),
				Rect2(192, 64, 16, 48), Rect2(192, 160, 16, 48),
				Rect2(272, 64, 16, 48), Rect2(272, 160, 16, 48)
			]

func _draw_room_walls() -> void:
	pass

func _draw_room_landmarks() -> void:
	match level_index:
		0:
			_draw_lantern(Vector2(80, 64), Color("#f6c85f"))
			_draw_lantern(Vector2(400, 208), Color("#f6c85f"))
			draw_circle(Vector2(240, 136), 24.0, Color("#6e4131"))
			draw_circle(Vector2(240, 136), 16.0, Color("#a96b4e"))
		1:
			for point in [Vector2(64, 72), Vector2(144, 200), Vector2(272, 72), Vector2(400, 200)]:
				_draw_mushroom(point, Color("#d36eaa"), 8.0)
			draw_circle(Vector2(400, 80), 18.0, Color("#9be69a", 0.18))
			draw_circle(Vector2(400, 80), 5.0, Color("#baf7ae", 0.65))
		2:
			for crystal in [[Vector2(72, 64), Color("#78d9e6"), 18.0], [Vector2(408, 64), Color("#ad7ee8"), 18.0], [Vector2(72, 208), Color("#63b8e8"), 18.0], [Vector2(408, 208), Color("#71d4d0"), 18.0]]:
				_draw_crystal(crystal[0], crystal[1], crystal[2])
			draw_circle(Vector2(240, 136), 22.0, Color("#527ec0", 0.32))
		3:
			draw_circle(Vector2(240, 136), 48.0, Color("#461c31"))
			draw_arc(Vector2(240, 136), 48.0, 0.0, TAU, 32, Color("#d15b6b"), 4.0)
			for point in [Vector2(128, 72), Vector2(352, 72), Vector2(128, 200), Vector2(352, 200)]:
				_draw_ellipse(point, Vector2(8, 11), Color("#c96b76"))
		4:
			for point in [Vector2(72, 72), Vector2(408, 72), Vector2(72, 200), Vector2(408, 200)]:
				_draw_rock(point, 11.0, Color("#8a4c55"))
			_draw_lantern(Vector2(240, 72), Color("#f6c85f"))
			_draw_lantern(Vector2(240, 200), Color("#f6c85f"))
			draw_circle(Vector2(240, 136), 28.0, Color("#7d4759"))
			draw_arc(Vector2(240, 136), 28.0, 0.0, TAU, 24, Color("#d58b9b"), 3.0)
		5:
			draw_circle(Vector2(240, 136), 48.0, Color("#411d31"))
			draw_arc(Vector2(240, 136), 48.0, 0.0, TAU, 32, Color("#f06b77"), 4.0)
			for point in [Vector2(104, 76), Vector2(376, 76), Vector2(104, 196), Vector2(376, 196)]:
				_draw_crystal(point, Color("#d15b6b"), 14.0)

func _draw_chamber_background() -> void:
	draw_rect(Rect2(ROOM_MARGIN, ROOM_MARGIN, 444, 236), Color("#5b382b"), true)
	draw_rect(Rect2(26, 62, 428, 164), Color("#80513a"), true)
	_draw_path(PackedVector2Array([Vector2(30, 144), Vector2(115, 144), Vector2(160, 112), Vector2(315, 112), Vector2(360, 144), Vector2(450, 144)]), Color("#a8734e"), 28.0)
	_draw_brick_border(Color("#3b251f"), Color("#9b6546"))

func _draw_chamber_details() -> void:
	for point in [Vector2(58, 86), Vector2(102, 197), Vector2(196, 77), Vector2(300, 194), Vector2(407, 84)]:
		_draw_rock(point, 8.0, Color("#69402f"))
	for point in [Vector2(78, 135), Vector2(402, 135)]:
		_draw_lantern(point, Color("#f6c85f"))
	draw_circle(Vector2(240, 112), 30.0, Color("#4c3027", 0.42))
	draw_arc(Vector2(240, 112), 30.0, 0.0, TAU, 24, Color("#b47750", 0.8), 3.0)

func _draw_fungus_background() -> void:
	draw_rect(Rect2(ROOM_MARGIN, ROOM_MARGIN, 444, 236), Color("#263d32"), true)
	draw_rect(Rect2(30, 62, 420, 164), Color("#304f3e"), true)
	_draw_path(PackedVector2Array([Vector2(30, 185), Vector2(115, 185), Vector2(155, 135), Vector2(250, 135), Vector2(300, 87), Vector2(450, 87)]), Color("#476b4d"), 31.0)
	_draw_brick_border(Color("#182a25"), Color("#567d5a"))

func _draw_fungus_details() -> void:
	for mushroom in [
		[Vector2(77, 92), Color("#d36eaa"), 8.0],
		[Vector2(126, 205), Color("#b667c1"), 11.0],
		[Vector2(235, 78), Color("#d58b5d"), 9.0],
		[Vector2(355, 197), Color("#9d75d1"), 12.0],
		[Vector2(413, 117), Color("#db6f8b"), 8.0]
	]:
		_draw_mushroom(mushroom[0], mushroom[1], mushroom[2])
	for point in [Vector2(170, 198), Vector2(275, 183), Vector2(382, 73)]:
		draw_circle(point, 12.0, Color("#8bd58a", 0.13))
		draw_circle(point, 4.0, Color("#a7f0a0", 0.55))

func _draw_crystal_background() -> void:
	draw_rect(Rect2(ROOM_MARGIN, ROOM_MARGIN, 444, 236), Color("#263553"), true)
	draw_rect(Rect2(30, 62, 420, 164), Color("#30486e"), true)
	_draw_path(PackedVector2Array([Vector2(30, 105), Vector2(120, 105), Vector2(165, 178), Vector2(325, 178), Vector2(365, 105), Vector2(450, 105)]), Color("#45658a"), 29.0)
	_draw_brick_border(Color("#1a253d"), Color("#4c729e"))

func _draw_crystal_details() -> void:
	for crystal in [
		[Vector2(72, 197), Color("#78d9e6"), 22.0],
		[Vector2(125, 76), Color("#9aa4ff"), 16.0],
		[Vector2(240, 203), Color("#63b8e8"), 27.0],
		[Vector2(355, 76), Color("#ad7ee8"), 19.0],
		[Vector2(414, 192), Color("#71d4d0"), 24.0]
	]:
		_draw_crystal(crystal[0], crystal[1], crystal[2])

func _draw_nest_background() -> void:
	draw_rect(Rect2(ROOM_MARGIN, ROOM_MARGIN, 444, 236), Color("#4a2638"), true)
	draw_rect(Rect2(30, 62, 420, 164), Color("#633047"), true)
	_draw_path(PackedVector2Array([Vector2(30, 144), Vector2(120, 144), Vector2(155, 100), Vector2(325, 100), Vector2(360, 144), Vector2(450, 144)]), Color("#7f4051"), 34.0)
	_draw_brick_border(Color("#2e1c2d"), Color("#8b4b5b"))

func _draw_nest_details() -> void:
	draw_circle(Vector2(242, 133), 57.0, Color("#411f32", 0.75))
	draw_circle(Vector2(242, 133), 47.0, Color("#713044", 0.9))
	draw_arc(Vector2(242, 133), 57.0, 0.0, TAU, 32, Color("#d15b6b", 0.8), 4.0)
	for egg in [
		[Vector2(92, 88), 8.0],
		[Vector2(126, 202), 10.0],
		[Vector2(370, 82), 9.0],
		[Vector2(410, 190), 11.0]
	]:
		_draw_ellipse(egg[0], Vector2(egg[1], egg[1] * 1.35), Color("#c96b76"))
		draw_arc(egg[0], egg[1], 0.0, TAU, 16, Color("#f3a07e", 0.6), 2.0)

func _draw_path(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points, Color("#241d29", 0.35), width + 6.0, true)
	draw_polyline(points, color, width, true)

func _draw_brick_border(dark: Color, light: Color) -> void:
	draw_rect(Rect2(ROOM_MARGIN, ROOM_MARGIN, 444, 236), dark, false, 5.0)
	for x in range(38, 450, 32):
		draw_line(Vector2(x, 22), Vector2(x + 14, 22), light, 3.0)
		draw_line(Vector2(x, 250), Vector2(x + 14, 250), light, 3.0)
	for y in range(38, 250, 28):
		draw_line(Vector2(22, y), Vector2(22, y + 12), light, 3.0)
		draw_line(Vector2(458, y), Vector2(458, y + 12), light, 3.0)

func _draw_rock(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(-radius, 2), center + Vector2(-radius * 0.5, -radius),
		center + Vector2(radius * 0.7, -radius * 0.8), center + Vector2(radius, 2),
		center + Vector2(radius * 0.4, radius), center + Vector2(-radius * 0.6, radius * 0.8)
	])
	draw_colored_polygon(points, color)
	draw_polyline(points, color.lightened(0.25), 1.5, true)

func _draw_lantern(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(0, -13), center + Vector2(0, -5), Color("#35222a"), 2.0)
	draw_circle(center, 8.0, Color(color, 0.18))
	draw_circle(center, 4.0, color)

func _draw_mushroom(center: Vector2, color: Color, size: float) -> void:
	draw_rect(Rect2(center + Vector2(-2, 0), Vector2(4, size)), Color("#d8c29a"), true)
	draw_circle(center + Vector2(0, -2), size, Color(color, 0.9))
	draw_circle(center + Vector2(-size * 0.35, -size * 0.15), size * 0.2, Color("#fff0c2", 0.75))

func _draw_crystal(center: Vector2, color: Color, size: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -size), center + Vector2(size * 0.42, size * 0.25),
		center + Vector2(size * 0.28, size), center + Vector2(-size * 0.35, size * 0.65),
		center + Vector2(-size * 0.5, size * 0.1)
	])
	draw_colored_polygon(points, Color(color, 0.8))
	draw_polyline(points, color.lightened(0.35), 2.0, true)
	draw_line(center + Vector2(0, -size * 0.8), center + Vector2(size * 0.2, size * 0.5), Color("#e6ffff", 0.55), 2.0)

func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 24:
		var angle := TAU * float(step) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _draw_exit() -> void:
	var color := Color("#4caf72") if enemy_health <= 0 else Color("#49394f")
	if level_index < LEVELS.size() - 1:
		draw_rect(Rect2(ROOM_SIZE.x - 18.0, 112.0, 18.0, 48.0), color, true)
	if level_index > 0:
		draw_rect(Rect2(0.0, 112.0, 18.0, 48.0), color, true)
	if enemy_health <= 0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(ROOM_SIZE.x - 36.0, ROOM_SIZE.y / 2.0 - 9.0),
			Vector2(ROOM_SIZE.x - 25.0, ROOM_SIZE.y / 2.0),
			Vector2(ROOM_SIZE.x - 36.0, ROOM_SIZE.y / 2.0 + 9.0)
		]), Color("#d9f5c5"))
		if level_index > 0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(36.0, ROOM_SIZE.y / 2.0 - 9.0),
				Vector2(25.0, ROOM_SIZE.y / 2.0),
				Vector2(36.0, ROOM_SIZE.y / 2.0 + 9.0)
			]), Color("#d9f5c5"))

func _draw_player() -> void:
	var ant_color: Dictionary = ANT_COLORS[selected_ant]
	var frame := int(player_anim_time * 8.0) % 3 if player_is_moving else 1
	var player_size := Vector2(21.6, 23.2)
	if game_over:
		var death_progress := clampf(death_animation_time / DEATH_ANIMATION_DURATION, 0.0, 1.0)
		var death_scale := 1.0 + sin(death_progress * PI) * 0.35
		death_scale *= 1.0 - death_progress * 0.72
		var death_rotation := death_progress * TAU * 1.5
		var death_alpha := 1.0 - death_progress * 0.85
		var death_size := player_size * death_scale
		var source := Rect2(Vector2(ant_color["column"] + frame, _direction_row(last_move_direction)) * SPRITE_CELL_SIZE, SPRITE_CELL_SIZE)
		draw_set_transform(player_position, death_rotation, Vector2.ONE)
		draw_texture_rect_region(ant_texture, Rect2(-death_size / 2.0, death_size), source, Color(1.0, 1.0, 1.0, death_alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_sprite(ant_texture, player_position, ant_color["column"] + frame, _direction_row(last_move_direction), player_size)
	if attack_flash > 0.0:
		draw_circle(player_position + last_move_direction * 18.0, 7.0, Color("#8bf08b", 0.65))

func _spawn_effect(texture: Texture2D, position: Vector2, tint: Color, scale: float) -> void:
	effects.append({"texture": texture, "position": position, "tint": tint, "scale": scale, "life": EFFECT_LIFETIME})

func _draw_effects() -> void:
	for effect in effects:
		var life: float = float(effect["life"])
		var alpha := clampf(life / EFFECT_LIFETIME, 0.0, 1.0)
		var size := Vector2(48.0, 48.0) * float(effect["scale"]) * (1.0 + (1.0 - alpha) * 0.35)
		var tint: Color = effect["tint"]
		var texture: Texture2D = effect["texture"]
		tint.a = alpha
		draw_texture_rect(texture, Rect2(effect["position"] - size / 2.0, size), false, tint)

func _draw_poison_projectiles() -> void:
	for projectile in poison_projectiles:
		var position: Vector2 = projectile["position"]
		draw_circle(position, 5.0, Color("#8bf08b", 0.85))
		draw_circle(position, 2.0, Color("#e1ffe1"))
		draw_line(position - projectile["velocity"].normalized() * 11.0, position, Color("#6fce7b", 0.7), 3.0)

func _play_sound(stream: AudioStream, volume_db := 0.0) -> void:
	if audio_player == null:
		return
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	audio_player.play()

func _draw_enemy() -> void:
	if enemy_health <= 0:
		return
	var enemy_frame := int(enemy_anim_time * 7.0) % 3
	var enemy_direction := enemy_position.direction_to(player_position)
	var is_boss: bool = level_index == LEVELS.size() - 1
	var size := Vector2(82.0, 86.0) if is_boss else Vector2(54.0, 58.0)
	_draw_sprite(bug_texture, enemy_position, 9 + enemy_frame, _direction_row(enemy_direction), size)
	_draw_meter(enemy_position + Vector2(-28.0, -size.y / 2.0 - 9.0), 56.0, 5.0, float(enemy_health) / float(LEVELS[level_index]["health"]), Color("#e85d75"))
	if enemy_poison_time > 0.0:
		draw_circle(enemy_position + Vector2(0, -size.y / 2.0 - 15.0), 3.0, Color("#8bf08b"))
	if enemy_flash > 0.0:
		draw_circle(enemy_position, 17.0, Color(1.0, 0.9, 0.7, 0.25))

func _direction_row(direction: Vector2) -> int:
	if absf(direction.y) > absf(direction.x):
		return 0 if direction.y > 0.0 else 3
	return 1 if direction.x < 0.0 else 2

func _draw_sprite(texture: Texture2D, center: Vector2, column: int, row: int, size: Vector2) -> void:
	var source := Rect2(Vector2(column, row) * SPRITE_CELL_SIZE, SPRITE_CELL_SIZE)
	draw_texture_rect_region(texture, Rect2(center - size / 2.0, size), source)

func _draw_hud() -> void:
	var level: Dictionary = LEVELS[level_index]
	draw_string(ThemeDB.fallback_font, Vector2(72, 18), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, 104, 8, Color("#d7ffc0"))
	draw_string(ThemeDB.fallback_font, Vector2(354, 18), "POISON", HORIZONTAL_ALIGNMENT_LEFT, 104, 8, Color("#c4e7ff"))
	_draw_meter(Vector2(72, 24), 104.0, 8.0, float(player_health) / float(player_max_health), Color("#8bf08b"))
	_draw_meter(Vector2(354, 24), 104.0, 8.0, 1.0 if attack_cooldown <= 0.0 else 0.0, Color("#8bd5ff"))
	for index in player_max_health:
		draw_circle(Vector2(75.0 + index * 12.0, 49.0), 4.0, Color("#8bf08b") if index < player_health else Color("#49394f"))
	draw_string(ThemeDB.fallback_font, Vector2(150, 19), level["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, 9, Color("#fff0a6"))
	draw_string(ThemeDB.fallback_font, Vector2(150, 30), level["enemy"] + " // " + level["quirk"], HORIZONTAL_ALIGNMENT_CENTER, 180, 7, Color("#d7ffc0", 0.8))
	if enemy_health <= 0 and not run_complete:
		draw_string(ThemeDB.fallback_font, Vector2(0, 249), "TUNNELS UNLOCKED  //  EXPLORE THE ANTHILL", HORIZONTAL_ALIGNMENT_CENTER, 480, 8, Color("#9ee7a5"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(0, 249), "DEFEAT THE GUARD  //  TUNNELS LOCKED", HORIZONTAL_ALIGNMENT_CENTER, 480, 8, Color("#e8b6a4"))

func _draw_meter(position: Vector2, width: float, height: float, ratio: float, fill: Color) -> void:
	draw_rect(Rect2(position, Vector2(width, height)), Color("#17131c", 0.85), true)
	draw_rect(Rect2(position + Vector2(1, 1), Vector2((width - 2.0) * clampf(ratio, 0.0, 1.0), height - 2.0)), fill, true)

func _draw_powerup_menu() -> void:
	draw_rect(Rect2(0, 0, ROOM_SIZE.x, ROOM_SIZE.y), Color("#17131c", 0.9), true)
	draw_rect(Rect2(42, 31, 396, 207), Color("#211a2a"), true)
	draw_rect(Rect2(42, 31, 396, 207), Color("#8bf08b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(0, 59), "ROOM CLEARED", HORIZONTAL_ALIGNMENT_CENTER, 480, 20, Color("#f4d9ad"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 78), "CHOOSE ONE UPGRADE", HORIZONTAL_ALIGNMENT_CENTER, 480, 9, Color("#b99bbd"))
	for index in powerup_choices.size():
		var choice: Dictionary = powerup_choices[index]
		var x := 58.0 + index * 122.0
		var card_colors: Array[Color] = [Color("#8bf08b"), Color("#8bd5ff"), Color("#f6c85f")]
		var card_color: Color = card_colors[index]
		draw_rect(Rect2(x, 96, 108, 91), Color("#30243b"), true)
		draw_rect(Rect2(x, 96, 108, 91), card_color, false, 2.0)
		draw_circle(Vector2(x + 54, 137), 20.0, Color(card_color, 0.2))
		draw_circle(Vector2(x + 54, 137), 9.0 + index * 4.0, card_color)
		draw_circle(Vector2(x + 54, 137), 4.0, Color("#fff0a6"))
		draw_string(ThemeDB.fallback_font, Vector2(x, 116), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, 108, 15, Color("#8bf08b"))
		draw_string(ThemeDB.fallback_font, Vector2(x + 4, 161), choice["name"], HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color("#f4d9ad"))
		draw_string(ThemeDB.fallback_font, Vector2(x + 4, 177), choice["description"], HORIZONTAL_ALIGNMENT_CENTER, 100, 7, Color("#b99bbd"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 219), "Press 1, 2, or 3 to select", HORIZONTAL_ALIGNMENT_CENTER, 480, 10, Color("#f4d9ad"))

func _draw_pause_menu() -> void:
	draw_rect(Rect2(0, 0, ROOM_SIZE.x, ROOM_SIZE.y), Color("#17131c", 0.78), true)
	draw_rect(Rect2(112, 44, 256, 184), Color("#211a2a"), true)
	draw_rect(Rect2(112, 44, 256, 184), Color("#f4d9ad"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(0, 76), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, 480, 22, Color("#fff0a6"))
	for index in PAUSE_ITEMS.size():
		var y := 116.0 + index * 29.0
		var selected := index == pause_index
		if selected:
			draw_rect(Rect2(145, y - 18, 190, 24), Color("#4d3650"), true)
			draw_string(ThemeDB.fallback_font, Vector2(0, y), "> " + PAUSE_ITEMS[index] + " <", HORIZONTAL_ALIGNMENT_CENTER, 480, 13, Color("#f4d9ad"))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(0, y), PAUSE_ITEMS[index], HORIZONTAL_ALIGNMENT_CENTER, 480, 12, Color("#b99bbd"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 211), "UP / DOWN select     ENTER confirm", HORIZONTAL_ALIGNMENT_CENTER, 480, 9, Color("#d7ffc0"))

func _draw_state_overlay(color: Color) -> void:
	draw_rect(Rect2(0, 0, ROOM_SIZE.x, ROOM_SIZE.y), Color("#17131c", 0.74), true)
	draw_rect(Rect2(76, 48, 328, 176), Color("#211a2a", 0.96), true)
	draw_rect(Rect2(76, 48, 328, 176), color, false, 2.0)

func _draw_game_over_menu() -> void:
	var progress := clampf(death_animation_time / DEATH_ANIMATION_DURATION, 0.0, 1.0)
	var ui_shift := Vector2(240.0 - camera.position.x, 0.0)
	draw_rect(Rect2(ui_shift, ROOM_SIZE), Color("#0d1018", 0.72), true)
	draw_rect(Rect2(Vector2(62, 38) + ui_shift, Vector2(356, 196)), Color("#211a2a", 0.98), true)
	draw_rect(Rect2(Vector2(62, 38) + ui_shift, Vector2(356, 196)), Color("#d85b7d", 0.9), false, 2.0)
	draw_line(Vector2(82, 77) + ui_shift, Vector2(398, 77) + ui_shift, Color("#6a3b55"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(0, 69) + ui_shift, "COLONY LOST", HORIZONTAL_ALIGNMENT_CENTER, 480, 22, Color("#ff9a9f"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 94) + ui_shift, "THE GUARD REACHED YOUR NEST", HORIZONTAL_ALIGNMENT_CENTER, 480, 9, Color("#f4d9ad"))
	var pulse := 1.0 + sin(player_anim_time * 5.0) * 0.08
	draw_circle(Vector2(240, 135) + ui_shift, 19.0 * pulse, Color("#d85b7d", 0.14))
	draw_circle(Vector2(240, 135) + ui_shift, 11.0 * pulse, Color("#d85b7d", 0.26))
	for shard_index in 7:
		var angle := float(shard_index) * TAU / 7.0 + player_anim_time * 0.35
		var distance := 22.0 + progress * 18.0
		var shard_start := Vector2(240, 135) + ui_shift + Vector2.RIGHT.rotated(angle) * distance
		var shard_end := shard_start + Vector2.RIGHT.rotated(angle) * (8.0 + progress * 7.0)
		draw_line(shard_start, shard_end, Color("#ff9a9f", 0.75 - progress * 0.3), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(0, 184) + ui_shift, "R  RESTART RUN", HORIZONTAL_ALIGNMENT_CENTER, 480, 11, Color("#d7ffc0"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 202) + ui_shift, "ESC  RETURN TO MAIN MENU", HORIZONTAL_ALIGNMENT_CENTER, 480, 9, Color("#b99bbd"))
