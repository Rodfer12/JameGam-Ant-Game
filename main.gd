extends Node2D

## Game flow, player, enemies and combat.
## Six floors. Each floor is a chain of rooms ending in a boss: walk into a room
## to start its fight, the exits seal with thorns until every foe is dead, then
## pick an upgrade. Side rooms hold an upgrade altar or a healing spring. Beat the
## boss, step into the portal, and descend. Clear the Queen's Court to win.

const TILE_SIZE := 16
const SPRITE_CELL := Vector2i(90, 96)
const PLAYER_FRAME_SIZE := Vector2i(23, 24)
const ENEMY_FRAME_SIZE := Vector2i(44, 47)
const BOSS_FRAME_SIZE := Vector2i(66, 70)

const PLAYER_RADIUS := 9.0
const SPIT_SPEED := 270.0
const POISON_TICK := 0.5
const POISON_TICK_DAMAGE := 0.5
const PROJECTILE_LIFETIME := 1.0
const DEATH_ANIMATION_DURATION := 0.9
const PLAYER_INVULNERABLE_TIME := 0.9
const ROOM_TRIGGER_DEPTH := 2
const ENEMY_SPAWN_DELAY := 0.9
const ENEMY_SIGHT_RANGE := 200.0
const DASH_TIME := 0.18
const DASH_SPEED_MULT := 3.4
const COMBO_WINDOW := 3.0
const SLASH_RANGE := 56.0
const SLASH_ARC := 0.85
const STEER_ANGLES: Array[float] = [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]

const PAUSE_ITEMS: Array[String] = ["RESUME", "RESTART RUN", "MAIN MENU"]
const END_ITEMS: Array[String] = ["NEW RUN", "MAIN MENU"]

const WINDUPS := {
	"charge": 0.6, "slam": 0.85, "ring": 0.7, "fan": 0.65,
	"summon": 0.9, "blink": 0.45, "puddles": 0.7, "slash": 0.45
}

const PARTICLE_DIR := "res://sfx/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/kenney-particle-pack-7e801dc538996622a91327bb1dd5879cf977aa09/addons/kenney_particle_pack/"
const RPG_AUDIO_DIR := "res://audio/kenney_rpg-audio/Audio/"

# Must match the MODE_* constants in hud.gd.
enum State { PLAYING, UPGRADE, PAUSED, DYING, GAME_OVER, VICTORY, TRANSITION }
enum Action { CHASE, WINDUP, DASH, RECOVER }


class Enemy:
	var id := ""
	var def: Dictionary = {}
	var affix := ""
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var knockback := Vector2.ZERO
	var health := 1.0
	var max_health := 1.0
	var speed := 50.0
	var damage := 1
	var resist := 1.0
	var radius := 10.0
	var is_boss := false
	var phase := 0
	var alive := true
	var spawn_timer := 0.9
	var contact_cooldown := 0.0
	var poison_stacks := 0
	var poison_time := 0.0
	var poison_tick := 0.0
	var poison_accum := 0.0
	var stun := 0.0
	var flash := 0.0
	var anim_time := 0.0
	var target := Vector2.ZERO
	var target_timer := 0.0
	var orbit_direction := 1.0
	var orbit_flip_timer := 3.0
	var action := 0
	var action_timer := 0.0
	var action_cooldown := 1.5
	var attack := ""
	var windup_total := 0.5
	var aim := Vector2.DOWN
	var dashes_left := 0
	var last_attack := ""
	var stuck_time := 0.0
	var facing := Vector2.DOWN
	var tint := Color.WHITE
	var scale_factor := 1.0
	var node: Node2D
	var sprite: Sprite2D
	var shadow: Sprite2D


@onready var terrain: AnthillGenerator = $BackgroundTileMap
@onready var camera: Camera2D = $Camera2D

var state: int = State.PLAYING
var rooms: Array[AnthillGenerator.Room] = []
var room_rects: Array[Rect2i] = []
var cleared_rooms: Array[bool] = []
var visited_rooms: Array[bool] = []
var active_room_index := -1
var current_room_index := -1
var floor_number := 1
var floor_config: Dictionary = {}
var enemies: Array[Enemy] = []
var boss_enemy: Enemy = null
var spawn_queue: Array[Dictionary] = []
var spawn_cooldown := 0.0

var projectiles: Array[Dictionary] = []
var enemy_projectiles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var particles: Array = []
var rings: Array = []
var arcs: Array = []
var effects: Array = []
var floaters: Array = []
var toasts: Array = []

var player_position := Vector2.ZERO
var player_knockback := Vector2.ZERO
var player_health := 6
var player_max_health := 6
var player_armor := 0
var health_lag := 1.0
var boss_lag := 1.0
var player_invulnerable := 0.0
var player_is_moving := false
var last_move_direction := Vector2.DOWN
var player_anim_time := 0.0
var spit_cd := 0.0
var bite_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector2.DOWN
var dash_charges_cur := 1
var dash_recharge := 0.0
var dash_trail_timer := 0.0
var second_wind_used := false
var combo := 0
var combo_timer := 0.0
var combo_pop := 0.0
var step_timer := 0.0
var death_time := 0.0
var hurt_flash := 0.0
var menu_index := 0
var menu_delay := 0.0
var upgrade_choices: Array = []
var upgrade_title := "CHOOSE AN UPGRADE"
var upgrade_subtitle := ""
var upgrade_then_victory := false
var banner_time := 0.0
var banner_total := 3.2
var banner_title := ""
var banner_subtitle := ""
var banner_tag := ""
var banner_color := Color("#fff0a6")
var shake_strength := 0.0
var camera_position := Vector2.ZERO
var torch_time := 0.0
var run_time := 0.0
var hint_time := 0.0
var floor_card_time := 0.0
var fade := 0.0
var transition_phase := 0
var transition_time := 0.0
var portal_active := false
var portal_position := Vector2.ZERO
var run_banked := false
var run_victory := false
var end_summary: Array = []
var end_subtitle := "THE GUARD REACHED YOUR NEST"
var enemy_random := RandomNumberGenerator.new()

var ant_sheet: Dictionary = {}
var bug_sheet: Dictionary = {}
var boss_sheet: Dictionary = {}
var shadow_texture: Texture2D
var slash_texture: Texture2D
var spark_texture: Texture2D
var magic_texture: Texture2D
var ui_click: AudioStream
var attack_sound: AudioStream
var hit_sound: AudioStream
var hurt_sound: AudioStream
var footstep_sound: AudioStream
var door_sound: AudioStream
var coin_sound: AudioStream

var audio_players: Array[AudioStreamPlayer] = []
var audio_cursor := 0

var ambient: CanvasModulate
var entities_root: Node2D
var player_node: Node2D
var player_sprite: Sprite2D
var player_light: PointLight2D
var ground_overlay: Node2D
var world_overlay: Node2D
var fx_overlay: Node2D
var hud: Hud
var squash_tween: Tween


func _ready() -> void:
	enemy_random.randomize()
	_load_assets()
	_build_world()
	_build_actors()
	hud = Hud.new()
	add_child(hud)
	_start_run()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- Setup ------------------------------------------------------------------------------------

func _load_asset(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Missing asset: " + path)
	return null


func _load_assets() -> void:
	var ants := _load_asset("res://art/Ants.png") as Texture2D
	var bugs := _load_asset("res://art/Bugs.png") as Texture2D
	ant_sheet = SpriteSheetUtil.smooth_sheet(ants, SPRITE_CELL, PLAYER_FRAME_SIZE)
	bug_sheet = SpriteSheetUtil.smooth_sheet(bugs, SPRITE_CELL, ENEMY_FRAME_SIZE)
	boss_sheet = SpriteSheetUtil.smooth_sheet(bugs, SPRITE_CELL, BOSS_FRAME_SIZE)
	slash_texture = _load_asset(PARTICLE_DIR + "slash_01.png") as Texture2D
	spark_texture = _load_asset(PARTICLE_DIR + "spark_01.png") as Texture2D
	magic_texture = _load_asset(PARTICLE_DIR + "magic_01.png") as Texture2D
	ui_click = _load_asset("res://audio/kenney_ui-audio/Audio/click1.ogg") as AudioStream
	attack_sound = _load_asset(RPG_AUDIO_DIR + "knifeSlice.ogg") as AudioStream
	hit_sound = _load_asset(RPG_AUDIO_DIR + "chop.ogg") as AudioStream
	hurt_sound = _load_asset(RPG_AUDIO_DIR + "cloth1.ogg") as AudioStream
	footstep_sound = _load_asset(RPG_AUDIO_DIR + "footstep00.ogg") as AudioStream
	door_sound = _load_asset(RPG_AUDIO_DIR + "doorOpen_1.ogg") as AudioStream
	coin_sound = _load_asset(RPG_AUDIO_DIR + "handleCoins.ogg") as AudioStream
	shadow_texture = _make_shadow_texture()


func _make_shadow_texture() -> Texture2D:
	var image := Image.create_empty(24, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 24:
			var dx := (float(x) + 0.5 - 12.0) / 12.0
			var dy := (float(y) + 0.5 - 5.0) / 5.0
			var d := dx * dx + dy * dy
			if d <= 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0.45 * (1.0 - d * 0.6)))
	return ImageTexture.create_from_image(image)


func _build_world() -> void:
	ambient = CanvasModulate.new()
	ambient.color = Color("#706b85")
	add_child(ambient)

	ground_overlay = Node2D.new()
	ground_overlay.name = "GroundOverlay"
	ground_overlay.z_index = -8
	ground_overlay.draw.connect(_draw_ground_overlay)
	add_child(ground_overlay)

	entities_root = Node2D.new()
	entities_root.name = "Entities"
	entities_root.y_sort_enabled = true
	add_child(entities_root)

	world_overlay = Node2D.new()
	world_overlay.name = "WorldOverlay"
	world_overlay.z_index = 5
	world_overlay.draw.connect(_draw_world_overlay)
	add_child(world_overlay)

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fx_overlay = Node2D.new()
	fx_overlay.name = "EffectsOverlay"
	fx_overlay.z_index = 6
	fx_overlay.material = additive
	fx_overlay.draw.connect(_draw_fx_overlay)
	add_child(fx_overlay)

	camera.position_smoothing_enabled = false
	camera.enabled = true
	camera.make_current()

	for i in 8:
		var audio := AudioStreamPlayer.new()
		add_child(audio)
		audio_players.append(audio)


func _create_shadow_sprite(scale_factor: float) -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.texture = shadow_texture
	shadow.scale = Vector2.ONE * scale_factor
	return shadow


func _configure_sheet_sprite(sprite: Sprite2D, sheet: Dictionary) -> void:
	sprite.texture = sheet["texture"]
	sprite.hframes = int(sheet["columns"])
	sprite.vframes = int(sheet["rows"])


func _build_actors() -> void:
	player_node = Node2D.new()
	player_node.name = "Player"
	entities_root.add_child(player_node)
	var shadow := _create_shadow_sprite(1.0)
	shadow.position = Vector2(0, 9)
	player_node.add_child(shadow)
	player_sprite = Sprite2D.new()
	_configure_sheet_sprite(player_sprite, ant_sheet)
	player_node.add_child(player_sprite)
	player_light = PointLight2D.new()
	player_light.texture = CaveTileset.light_texture()
	player_light.color = Color(1.0, 0.74, 0.42)
	player_light.energy = 0.85
	player_light.texture_scale = 1.7
	player_light.shadow_enabled = false
	player_node.add_child(player_light)


# --- Run lifecycle -------------------------------------------------------------------------------

func _start_run() -> void:
	_clear_enemies()
	_clear_transients()
	GameState.reset_run()
	run_banked = false
	run_victory = false
	player_max_health = GameState.max_health
	player_health = player_max_health
	player_armor = GameState.armor_max
	health_lag = 1.0
	player_invulnerable = 0.0
	player_knockback = Vector2.ZERO
	spit_cd = 0.0
	bite_cd = 0.0
	dash_time = 0.0
	dash_charges_cur = GameState.dash_charges
	dash_recharge = 0.0
	second_wind_used = false
	combo = 0
	combo_timer = 0.0
	death_time = 0.0
	hurt_flash = 0.0
	run_time = 0.0
	banner_time = 0.0
	hint_time = 14.0
	toasts.clear()
	boss_enemy = null
	player_sprite.rotation = 0.0
	player_sprite.scale = Vector2.ONE
	player_sprite.modulate = Color.WHITE
	Engine.time_scale = 1.0
	_load_floor(1)


func _load_floor(number: int) -> void:
	_clear_enemies()
	_clear_transients()
	floor_number = number
	GameState.run_floor = number
	floor_config = GameData.FLOORS[number - 1]
	terrain.generate(randi(), {
		"rooms": floor_config["rooms"],
		"sides": floor_config["sides"],
		"themes": floor_config["themes"],
		"elites": floor_config["elites"]
	})
	rooms = terrain.get_rooms()
	room_rects.clear()
	cleared_rooms.clear()
	visited_rooms.clear()
	var boss_def: Dictionary = GameData.BOSSES[str(floor_config["boss"])]
	for room in rooms:
		room_rects.append(room.rect)
		cleared_rooms.append(false)
		visited_rooms.append(false)
		if room.type == GameData.ROOM_BOSS:
			room.title = str(boss_def["name"])
	cleared_rooms[0] = true
	visited_rooms[0] = true
	active_room_index = -1
	current_room_index = 0
	player_position = terrain.world_center(rooms[0])
	last_move_direction = Vector2.DOWN
	camera_position = player_position
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(terrain.world_size().x)
	camera.limit_bottom = int(terrain.world_size().y)
	camera.position = camera_position.round()
	camera.reset_smoothing()
	ambient.color = Color(str(floor_config["ambient"]))
	state = State.TRANSITION
	transition_phase = 2
	transition_time = 0.0
	fade = 1.0
	floor_card_time = 2.8
	banner_time = 0.0


func _clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e.node):
			e.node.queue_free()
	enemies.clear()
	boss_enemy = null


func _clear_transients() -> void:
	projectiles.clear()
	enemy_projectiles.clear()
	hazards.clear()
	pickups.clear()
	particles.clear()
	rings.clear()
	arcs.clear()
	effects.clear()
	floaters.clear()
	spawn_queue.clear()
	portal_active = false


func _bank_run() -> void:
	if run_banked:
		return
	run_banked = true
	GameState.run_time = run_time
	var result := GameState.bank_run(run_victory)
	end_summary = [
		["FLOOR REACHED", "%d / %d" % [floor_number, GameData.FLOORS.size()]],
		["ROOMS CLEARED", str(GameState.run_rooms)],
		["ENEMIES SLAIN", str(GameState.run_kills)],
		["BEST COMBO", "x%d" % GameState.run_best_combo],
		["TIME", _format_time(run_time)],
		["SCORE", str(GameState.run_score) + ("   NEW BEST!" if bool(result["new_best"]) else ""), Color("#ffd35c") if bool(result["new_best"]) else Color("#fff0c2")],
		["AMBER BANKED", "+%d" % int(result["gained"]), Color("#ffc247")]
	]


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds / 60.0), int(seconds) % 60]


func _return_to_menu() -> void:
	_bank_run()
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://main_menu.tscn")


# --- Frame loop --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	torch_time += delta
	menu_delay = maxf(menu_delay - delta, 0.0)
	hurt_flash = maxf(hurt_flash - delta * 2.5, 0.0)
	floor_card_time = maxf(floor_card_time - delta, 0.0)
	var ratio := float(player_health) / float(maxi(player_max_health, 1))
	if health_lag > ratio:
		health_lag = maxf(ratio, health_lag - delta * 0.5)
	else:
		health_lag = ratio
	match state:
		State.PLAYING:
			_update_playing(delta)
		State.DYING:
			_update_dying(delta)
		State.TRANSITION:
			_update_transition(delta)
	_update_effects(delta)
	_update_player_visual()
	for e in enemies:
		_update_enemy_visual(e)
	_update_torch()
	_update_camera(delta)
	_refresh_hud()
	ground_overlay.queue_redraw()
	world_overlay.queue_redraw()
	fx_overlay.queue_redraw()


func _update_playing(delta: float) -> void:
	run_time += delta
	GameState.run_time = run_time
	player_invulnerable = maxf(player_invulnerable - delta, 0.0)
	step_timer = maxf(step_timer - delta, 0.0)
	banner_time = maxf(banner_time - delta, 0.0)
	hint_time = maxf(hint_time - delta, 0.0)
	player_anim_time += delta
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	_update_player(delta)
	_update_room_trigger()
	_update_interactables()
	_update_spawning(delta)
	var snapshot := enemies.duplicate()
	for e in snapshot:
		if state != State.PLAYING:
			break
		if e.alive:
			_update_enemy(e, delta)
	_separate_enemies()
	_update_projectiles(delta)
	_update_enemy_projectiles(delta)
	_update_hazards(delta)
	_update_pickups(delta)
	_check_room_cleared()


func _update_dying(delta: float) -> void:
	death_time += delta
	player_anim_time += delta
	if death_time >= DEATH_ANIMATION_DURATION:
		state = State.GAME_OVER
		menu_index = 0
		menu_delay = 0.5
		run_victory = false
		_bank_run()


func _update_transition(delta: float) -> void:
	transition_time += delta
	if transition_phase == 1:
		fade = clampf(transition_time / 0.55, 0.0, 1.0)
		if transition_time >= 0.6:
			_load_floor(floor_number + 1)
	elif transition_phase == 2:
		fade = clampf(1.0 - transition_time / 0.7, 0.0, 1.0)
		if transition_time >= 0.7:
			fade = 0.0
			transition_phase = 0
			state = State.PLAYING
			_update_room_trigger()


func _update_torch() -> void:
	var slow_wave := sin(torch_time * 7.3) * 0.055
	var fast_wave := sin(torch_time * 19.0 + 1.7) * 0.025
	var pulse := sin(torch_time * 2.1 + sin(torch_time * 0.8)) * 0.035
	var flicker := clampf(0.82 + slow_wave + fast_wave + pulse, 0.68, 0.98)
	player_light.energy = flicker
	player_light.texture_scale = 1.7 + (flicker - 0.82) * 0.3


func _update_camera(delta: float) -> void:
	camera_position = camera_position.lerp(player_position, 1.0 - exp(-10.0 * delta))
	shake_strength = maxf(shake_strength - 30.0 * delta, 0.0)
	var shake := Vector2.ZERO
	if shake_strength > 0.05:
		shake = Vector2(enemy_random.randf_range(-1.0, 1.0), enemy_random.randf_range(-1.0, 1.0)) * shake_strength
	camera.position = (camera_position + shake).round()


func _add_shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


# --- Input --------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.keycode
	match state:
		State.PLAYING:
			if key == KEY_ESCAPE or key == KEY_P:
				state = State.PAUSED
				menu_index = 0
				_play_sound(ui_click)
			elif key == KEY_SHIFT or key == KEY_L:
				_try_dash()
		State.PAUSED:
			_handle_pause_key(key)
		State.UPGRADE:
			_handle_upgrade_key(key)
		State.GAME_OVER, State.VICTORY:
			_handle_end_key(key)


func _menu_navigation(key: Key, item_count: int) -> void:
	match key:
		KEY_UP, KEY_W:
			menu_index = posmod(menu_index - 1, item_count)
			_play_sound(ui_click)
		KEY_DOWN, KEY_S:
			menu_index = posmod(menu_index + 1, item_count)
			_play_sound(ui_click)


func _is_confirm(key: Key) -> bool:
	return key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE


func _handle_pause_key(key: Key) -> void:
	_menu_navigation(key, PAUSE_ITEMS.size())
	if key == KEY_ESCAPE or key == KEY_P:
		state = State.PLAYING
		_play_sound(ui_click)
	elif _is_confirm(key):
		match menu_index:
			0:
				state = State.PLAYING
				_play_sound(ui_click)
			1:
				_bank_run()
				_start_run()
			2:
				_return_to_menu()


func _handle_upgrade_key(key: Key) -> void:
	if menu_delay > 0.0 or upgrade_choices.is_empty():
		return
	match key:
		KEY_LEFT, KEY_A:
			menu_index = posmod(menu_index - 1, upgrade_choices.size())
			_play_sound(ui_click)
		KEY_RIGHT, KEY_D:
			menu_index = posmod(menu_index + 1, upgrade_choices.size())
			_play_sound(ui_click)
		KEY_1, KEY_2, KEY_3:
			_apply_upgrade(key - KEY_1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_apply_upgrade(menu_index)


func _handle_end_key(key: Key) -> void:
	if menu_delay > 0.0:
		return
	_menu_navigation(key, END_ITEMS.size())
	if key == KEY_R:
		_start_run()
	elif key == KEY_ESCAPE:
		_return_to_menu()
	elif _is_confirm(key):
		if menu_index == 0:
			_start_run()
		else:
			_return_to_menu()


func _spit_held() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _bite_held() -> bool:
	return Input.is_key_pressed(KEY_K) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _read_move_input() -> Vector2:
	var move := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	move += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	return move.limit_length(1.0)


# --- Player ---------------------------------------------------------------------------------------------

func _player_speed_now() -> float:
	var mult := 1.0
	if GameState.berserk and player_health * 2 <= player_max_health:
		mult = 1.25
	return GameState.player_speed * mult


func _update_player(delta: float) -> void:
	var move := _read_move_input()
	player_is_moving = move.length_squared() > 0.01
	var velocity := Vector2.ZERO
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_dir * GameState.player_speed * DASH_SPEED_MULT
		player_is_moving = true
		_dash_effects(delta)
	elif player_is_moving:
		last_move_direction = move.normalized()
		velocity = move * _player_speed_now()
		if step_timer <= 0.0:
			step_timer = 0.22
			_play_sound(footstep_sound, -14.0)
	player_knockback = player_knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	player_position = _move_with_walls(player_position, (velocity + player_knockback) * delta, PLAYER_RADIUS)

	spit_cd = maxf(spit_cd - delta, 0.0)
	bite_cd = maxf(bite_cd - delta, 0.0)
	dash_charges_cur = mini(dash_charges_cur, GameState.dash_charges)
	if dash_charges_cur < GameState.dash_charges:
		dash_recharge += delta
		if dash_recharge >= GameState.dash_cooldown:
			dash_recharge = 0.0
			dash_charges_cur += 1
	else:
		dash_recharge = 0.0

	if dash_time <= 0.0:
		if _bite_held() and bite_cd <= 0.0:
			_attack_bite()
		elif _spit_held() and spit_cd <= 0.0:
			_attack_spit()


func _move_with_walls(origin: Vector2, movement: Vector2, radius: float) -> Vector2:
	var steps := maxi(1, ceili(movement.length() / 6.0))
	var step := movement / float(steps)
	var result := origin
	for i in steps:
		var horizontal := Vector2(step.x, 0.0)
		if horizontal.x != 0.0 and not terrain.is_wall_at_world(result + horizontal, radius):
			result += horizontal
		var vertical := Vector2(0.0, step.y)
		if vertical.y != 0.0 and not terrain.is_wall_at_world(result + vertical, radius):
			result += vertical
	return result


func _try_dash() -> void:
	if state != State.PLAYING or dash_time > 0.0 or dash_charges_cur < 1:
		return
	var move := _read_move_input()
	dash_dir = move.normalized() if move.length_squared() > 0.01 else last_move_direction
	dash_time = DASH_TIME
	dash_charges_cur -= 1
	last_move_direction = dash_dir
	_play_sound(attack_sound, -8.0, 1.5)
	_burst(player_position, Color("#9fd8ff"), 8, 70.0, 0.3, 2.0)


func _dash_effects(delta: float) -> void:
	_spawn_particle(player_position + Vector2(0, 4), -dash_dir * 20.0, Color("#9fd8ff", 0.8), 0.25, 3.0, 4.0)
	if GameState.trail_level > 0:
		dash_trail_timer -= delta
		if dash_trail_timer <= 0.0:
			dash_trail_timer = 0.05
			_spawn_hazard("venom", player_position, 14.0, 2.5, 0.0)


func _damage_multiplier() -> float:
	var m := 1.0 + GameState.combo_bonus * float(mini(combo, 15))
	if GameState.berserk and player_health * 2 <= player_max_health:
		m += 0.4
	return m


func _roll_crit() -> bool:
	return enemy_random.randf() < GameState.crit_chance


## Aim: mouse while a mouse button is held, otherwise facing + gentle assist.
func _aim_direction(assist_angle: float, assist_range: float) -> Vector2:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var to_mouse := get_global_mouse_position() - player_position
		if to_mouse.length() > 6.0:
			return to_mouse.normalized()
	var direction := last_move_direction
	var best_distance := assist_range
	for e in enemies:
		var offset: Vector2 = e.position - player_position
		var distance := offset.length()
		if distance < best_distance and e.spawn_timer <= 0.0 and absf(direction.angle_to(offset)) < assist_angle:
			best_distance = distance
			direction = offset / distance
	return direction


func _attack_spit() -> void:
	spit_cd = GameState.spit_cooldown
	var direction := _aim_direction(0.9, 220.0)
	last_move_direction = direction
	var count := GameState.spit_count
	for i in count:
		var spread := 0.0
		if count > 1:
			spread = (float(i) - float(count - 1) * 0.5) * 0.17
		var dir := direction.rotated(spread)
		var crit := _roll_crit()
		var damage := GameState.spit_damage * _damage_multiplier() * (GameState.crit_mult if crit else 1.0)
		projectiles.append({
			"position": player_position + dir * 14.0,
			"velocity": dir * SPIT_SPEED,
			"life": PROJECTILE_LIFETIME,
			"damage": damage,
			"crit": crit,
			"pierce": GameState.spit_pierce,
			"bounce": GameState.spit_bounce,
			"hit": []
		})
	_spawn_effect(slash_texture, player_position + direction * 16.0, Color("#8bf08b"), 0.6)
	_play_sound(attack_sound, -6.0, 1.25)
	if squash_tween == null or not squash_tween.is_running():
		squash_tween = JuiceManager.squash_and_stretch(player_sprite, Vector2(1.18, 0.86), 0.14)


func _attack_bite() -> void:
	bite_cd = GameState.bite_cooldown
	var direction := _aim_direction(1.3, 70.0)
	last_move_direction = direction
	player_knockback += direction * 110.0
	var reach := GameState.bite_range
	arcs.append({"position": player_position, "angle": direction.angle(), "radius": reach - 4.0, "half": GameState.bite_arc, "life": 0.18, "max_life": 0.18, "color": Color("#ffb84d")})
	_play_sound(attack_sound, -3.0, 0.8)
	var landed := false
	for e in enemies.duplicate():
		if not e.alive or e.spawn_timer > 0.0:
			continue
		var offset: Vector2 = e.position - player_position
		var distance := offset.length()
		if distance > reach + e.radius:
			continue
		if distance > 6.0 and absf(direction.angle_to(offset)) > GameState.bite_arc:
			continue
		landed = true
		var crit := _roll_crit()
		var damage := GameState.bite_damage * _damage_multiplier() * (GameState.crit_mult if crit else 1.0)
		var normal := offset.normalized() if distance > 0.01 else direction
		if GameState.execute_fraction > 0.0 and not e.is_boss and e.health <= e.max_health * GameState.execute_fraction:
			damage = e.health + 1.0
			_float_text("EXECUTE", e.position + Vector2(0, -e.radius - 14.0), Color("#ff6b4a"), 8)
		e.knockback = normal * (140.0 if e.is_boss else 260.0)
		e.stun = maxf(e.stun, 0.12 if e.is_boss else 0.4)
		_spawn_effect(spark_texture, e.position, Color("#ffb84d"), 1.0)
		_burst(e.position, Color("#ffd27a"), 6, 110.0, 0.3, 2.0)
		_damage_enemy(e, damage, "bite", crit)
	# Bite swats (or reflects) enemy projectiles in the arc.
	for p in enemy_projectiles:
		var offset: Vector2 = Vector2(p["position"]) - player_position
		if offset.length() > reach + 10.0 or absf(direction.angle_to(offset)) > GameState.bite_arc + 0.2:
			continue
		if GameState.bite_reflect:
			p["velocity"] = direction * Vector2(p["velocity"]).length() * 1.3
			p["reflected"] = true
			p["life"] = 1.4
		else:
			p["life"] = 0.0
		landed = true
		_burst(Vector2(p["position"]), Color("#ffe9a0"), 5, 90.0, 0.25, 2.0)
	if landed:
		_add_shake(2.5)
		JuiceManager.freeze_frame(0.035)
	if squash_tween == null or not squash_tween.is_running():
		squash_tween = JuiceManager.squash_and_stretch(player_sprite, Vector2(1.25, 0.8), 0.16)


func _hurt_player(amount: int, from_pos: Vector2, source: Enemy = null) -> void:
	if state != State.PLAYING or player_invulnerable > 0.0 or dash_time > 0.0:
		return
	var remaining := amount
	if player_armor > 0:
		var absorbed := mini(player_armor, remaining)
		player_armor -= absorbed
		remaining -= absorbed
		_burst(player_position, Color("#7cc8ff"), 8, 100.0, 0.3, 2.0)
	player_health -= remaining
	combo = 0
	player_invulnerable = PLAYER_INVULNERABLE_TIME
	hurt_flash = 1.0 if remaining > 0 else 0.4
	_add_shake(5.0 if remaining > 0 else 2.5)
	var push := (player_position - from_pos).normalized()
	if push == Vector2.ZERO:
		push = Vector2.RIGHT
	player_knockback = push * 190.0
	if source != null:
		source.contact_cooldown = 0.8
		source.knockback = -push * 90.0
		if GameState.thorns > 0 and source.alive:
			source.stun = maxf(source.stun, 0.4 + 0.15 * float(GameState.thorns))
			_damage_enemy(source, 2.0 * float(GameState.thorns), "thorns")
	_float_text("-%d" % amount, player_position + Vector2(0, -18), Color("#ff6b6b"), 10)
	_spawn_effect(spark_texture, player_position, Color("#ff6b6b"), 0.9)
	_play_sound(hurt_sound)
	if player_health <= 0:
		if GameState.second_wind and not second_wind_used:
			second_wind_used = true
			player_health = maxi(1, player_max_health / 2)
			player_invulnerable = 2.0
			_explode(player_position, 90.0, 0, false, true, Color("#ffe27a"))
			_toast("SECOND WIND!", Color("#ffe27a"))
			return
		player_health = 0
		state = State.DYING
		death_time = 0.0
		_spawn_effect(magic_texture, player_position, Color("#ff6b8a"), 1.6)
		_play_sound(door_sound, -8.0)


func _heal_player(amount: int) -> void:
	var before := player_health
	player_health = mini(player_health + amount, player_max_health)
	if player_health > before:
		_float_text("+%d" % (player_health - before), player_position + Vector2(0, -18), Color("#8bf08b"), 9)
		_burst(player_position, Color("#ff9ab0"), 6, 50.0, 0.5, 2.0)


func _direction_row(direction: Vector2) -> int:
	if absf(direction.y) > absf(direction.x):
		return 0 if direction.y > 0.0 else 3
	return 1 if direction.x < 0.0 else 2


func _sheet_frame(sheet: Dictionary, column: int, row: int) -> Vector2i:
	return Vector2i(clampi(column, 0, int(sheet["columns"]) - 1), clampi(row, 0, int(sheet["rows"]) - 1))


func _ant_column() -> int:
	return int(GameState.ant_data().get("column", 0))


func _update_player_visual() -> void:
	player_node.position = player_position
	var frame := int(player_anim_time * 9.0) % 3 if player_is_moving else 1
	player_sprite.frame_coords = _sheet_frame(ant_sheet, _ant_column() + frame, _direction_row(last_move_direction))
	if state == State.DYING or state == State.GAME_OVER:
		var progress := clampf(death_time / DEATH_ANIMATION_DURATION, 0.0, 1.0)
		var death_scale := (1.0 + sin(progress * PI) * 0.35) * (1.0 - progress * 0.72)
		player_sprite.rotation = progress * TAU * 1.5
		player_sprite.scale = Vector2.ONE * death_scale
		player_sprite.modulate = Color(1, 1, 1, 1.0 - progress * 0.85)
		player_sprite.position = Vector2.ZERO
		return
	player_sprite.rotation = 0.0
	player_sprite.position = Vector2(0, -absf(sin(player_anim_time * 10.0)) * 1.5) if player_is_moving else Vector2.ZERO
	var alpha := 1.0
	if player_invulnerable > 0.0 and int(player_invulnerable * 16.0) % 2 == 0:
		alpha = 0.35
	if dash_time > 0.0:
		alpha = 0.55
	player_sprite.modulate = Color(1, 1, 1, alpha)


# --- Rooms and flow ----------------------------------------------------------------------------------------

func _update_room_trigger() -> void:
	current_room_index = terrain.room_index_at_world(player_position)
	if current_room_index >= 0:
		visited_rooms[current_room_index] = true
	if active_room_index != -1:
		return
	var deep := terrain.room_index_deep_at_world(player_position, ROOM_TRIGGER_DEPTH)
	if deep >= 0 and not cleared_rooms[deep]:
		var type := rooms[deep].type
		if type == GameData.ROOM_COMBAT or type == GameData.ROOM_ELITE or type == GameData.ROOM_BOSS:
			_begin_encounter(deep)


func _update_interactables() -> void:
	for i in rooms.size():
		if cleared_rooms[i]:
			continue
		var type := rooms[i].type
		if type != GameData.ROOM_TREASURE and type != GameData.ROOM_REST:
			continue
		if player_position.distance_to(terrain.world_center(rooms[i])) > 20.0:
			continue
		cleared_rooms[i] = true
		GameState.run_rooms += 1
		if type == GameData.ROOM_TREASURE:
			_play_sound(door_sound, -4.0)
			_spawn_effect(magic_texture, player_position, Color("#ffd35c"), 1.8)
			_open_upgrades("THE ALTAR GRANTS A GIFT", "Choose wisely", true)
		else:
			_heal_player(maxi(2, int(ceil(float(player_max_health) * 0.6))))
			player_armor = GameState.armor_max
			_spawn_effect(magic_texture, player_position, Color("#6fe0ff"), 1.8)
			_toast("THE SPRING RESTORES YOU", Color("#6fe0ff"))
			_play_sound(coin_sound)
	if portal_active and player_position.distance_to(portal_position) < 20.0:
		_start_descent()


func _start_descent() -> void:
	portal_active = false
	player_health = mini(player_max_health, player_health + 2)
	player_armor = GameState.armor_max
	state = State.TRANSITION
	transition_phase = 1
	transition_time = 0.0
	_play_sound(door_sound)
	_spawn_effect(magic_texture, player_position, Color("#c58cff"), 2.2)


func _begin_encounter(index: int) -> void:
	active_room_index = index
	var room := rooms[index]
	terrain.set_room_sealed(index, true)
	_build_spawn_queue(room, index)
	spawn_cooldown = 0.7
	banner_color = Color("#fff0a6")
	banner_tag = ""
	banner_total = 3.2
	if room.type == GameData.ROOM_BOSS:
		var boss_def: Dictionary = GameData.BOSSES[str(floor_config["boss"])]
		banner_title = str(boss_def["name"])
		banner_subtitle = str(boss_def["title"])
		banner_tag = "BOSS"
		banner_color = Color("#ff8a8a")
		banner_total = 3.8
		_play_sound(door_sound, 0.0, 0.7)
		_add_shake(4.0)
	else:
		banner_title = room.title
		var foes := spawn_queue.size()
		banner_subtitle = "%d FOES AWAIT" % foes
		if room.type == GameData.ROOM_ELITE:
			banner_tag = "ELITE ENCOUNTER"
			banner_color = Color("#ffb84d")
		_play_sound(door_sound)
		_add_shake(2.5)
	banner_time = banner_total
	_spawn_effect(magic_texture, player_position, Color("#a98cff"), 1.4)


func _weighted_pick(ids: Array[String], weights: Array[float], max_cost: float) -> String:
	var total := 0.0
	var allowed: Array[int] = []
	for i in ids.size():
		var def: Dictionary = GameData.ENEMIES[ids[i]]
		if float(def["cost"]) <= max_cost:
			allowed.append(i)
			total += weights[i]
	if allowed.is_empty():
		return ""
	var roll := enemy_random.randf() * total
	for i in allowed:
		roll -= weights[i]
		if roll <= 0.0:
			return ids[i]
	return ids[allowed[allowed.size() - 1]]


func _build_spawn_queue(room: AnthillGenerator.Room, index: int) -> void:
	spawn_queue.clear()
	if room.type == GameData.ROOM_BOSS:
		spawn_queue.append({"id": str(floor_config["boss"]), "affix": "", "boss": true})
		return
	var ids: Array[String] = []
	var weights: Array[float] = []
	for id in GameData.ENEMIES:
		var def: Dictionary = GameData.ENEMIES[id]
		if int(def["min_floor"]) <= floor_number:
			ids.append(str(id))
			weights.append(float(def["weight"]))
	var budget := 5.0 + float(floor_number) * 2.2 + float(index) * 0.4
	if room.type == GameData.ROOM_ELITE:
		budget *= 0.7
		var elite_id := _weighted_pick(ids, weights, 6.0)
		if elite_id == "" or float(GameData.ENEMIES[elite_id]["cost"]) < 3.0:
			elite_id = "beetle"
		var affix: String = GameData.AFFIXES[enemy_random.randi_range(0, GameData.AFFIXES.size() - 1)]
		spawn_queue.append({"id": elite_id, "affix": affix, "boss": false})
	for guard in 30:
		var pick := _weighted_pick(ids, weights, budget)
		if pick == "":
			break
		budget -= float(GameData.ENEMIES[pick]["cost"])
		spawn_queue.append({"id": pick, "affix": "", "boss": false})
	var first: Dictionary = {}
	if room.type == GameData.ROOM_ELITE and not spawn_queue.is_empty():
		first = spawn_queue.pop_front()
	spawn_queue.shuffle()
	if not first.is_empty():
		spawn_queue.push_front(first)


func _max_concurrent() -> int:
	return 3 + floori(float(floor_number) / 2.0)


func _update_spawning(delta: float) -> void:
	if active_room_index < 0 or spawn_queue.is_empty():
		return
	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0 and enemies.size() < _max_concurrent():
		spawn_cooldown = 0.9
		var entry: Dictionary = spawn_queue.pop_front()
		_spawn_enemy(str(entry["id"]), str(entry["affix"]), bool(entry["boss"]), _find_spawn_position(), false)


func _check_room_cleared() -> void:
	if active_room_index >= 0 and enemies.is_empty() and spawn_queue.is_empty():
		_finish_room()


func _finish_room() -> void:
	var index := active_room_index
	var room := rooms[index]
	cleared_rooms[index] = true
	terrain.set_room_sealed(index, false)
	active_room_index = -1
	GameState.run_rooms += 1
	_play_sound(door_sound)
	_spawn_effect(magic_texture, player_position, Color("#8bf08b"), 2.0)
	var bonus := 4 + floor_number * 2
	_gain_amber(bonus, player_position)
	player_armor = GameState.armor_max
	_heal_player(1)
	if room.type == GameData.ROOM_BOSS:
		GameState.run_score += 500 * floor_number
		if floor_number >= GameData.FLOORS.size():
			state = State.VICTORY
			run_victory = true
			menu_index = 0
			menu_delay = 0.8
			_bank_run()
			return
		portal_active = true
		portal_position = terrain.world_center(room)
		_toast("A PORTAL OPENS", Color("#c58cff"))
		_open_upgrades("BOSS DEFEATED", "A reward worthy of a champion", true)
		return
	var elite := room.type == GameData.ROOM_ELITE
	_open_upgrades("ELITE SLAIN" if elite else "ROOM CLEARED", "Choose one upgrade", elite)


func _rarity_weight(rarity: int, boosted: bool) -> float:
	var w := 100.0
	if rarity == 1:
		w = 45.0 * (1.0 + GameState.luck * 3.0)
		if boosted:
			w *= 1.4
	elif rarity == 2:
		w = 14.0 * (1.0 + GameState.luck * 5.0) * (1.0 + 0.15 * float(floor_number - 1))
		if boosted:
			w *= 2.2
	elif boosted:
		w *= 0.25
	return w


func _roll_upgrades(count: int, boosted: bool) -> Array:
	var pool: Array[Dictionary] = []
	for u in GameData.UPGRADES:
		var id := str(u["id"])
		var instant := bool(u.get("instant", false))
		if not instant and GameState.upgrade_level(id) >= int(u["max"]):
			continue
		if instant and player_health >= player_max_health:
			continue
		pool.append(u)
	var picks: Array = []
	for n in count:
		if pool.is_empty():
			break
		var weights: Array[float] = []
		var total := 0.0
		for u in pool:
			var w := _rarity_weight(int(u["rarity"]), boosted)
			weights.append(w)
			total += w
		var roll := enemy_random.randf() * total
		var chosen := pool.size() - 1
		for i in pool.size():
			roll -= weights[i]
			if roll <= 0.0:
				chosen = i
				break
		var entry: Dictionary = pool[chosen].duplicate()
		entry["current"] = GameState.upgrade_level(str(entry["id"]))
		picks.append(entry)
		pool.remove_at(chosen)
	return picks


func _open_upgrades(title: String, subtitle: String, boosted: bool) -> void:
	upgrade_choices = _roll_upgrades(3, boosted)
	if upgrade_choices.is_empty():
		_heal_player(2)
		return
	upgrade_title = title
	upgrade_subtitle = subtitle
	state = State.UPGRADE
	menu_index = 0
	menu_delay = 0.5


func _apply_upgrade(index: int) -> void:
	if index < 0 or index >= upgrade_choices.size():
		return
	var choice: Dictionary = upgrade_choices[index]
	var id := str(choice["id"])
	var old_max := player_max_health
	var old_armor_max := GameState.armor_max
	if bool(choice.get("instant", false)):
		player_health = player_max_health
		_toast("HEALTH RESTORED", Color("#ff9ab0"))
	else:
		GameState.add_upgrade(id)
		var lv := GameState.upgrade_level(id)
		_toast("%s  LV %d" % [str(choice["name"]), lv], UiKit.rarity_color(int(choice["rarity"])))
	GameState.recompute_stats()
	player_max_health = GameState.max_health
	player_health = clampi(player_health + (player_max_health - old_max), 1, player_max_health)
	player_armor = clampi(player_armor + (GameState.armor_max - old_armor_max), 0, GameState.armor_max)
	_play_sound(ui_click)
	_spawn_effect(magic_texture, player_position, Color("#f6c85f"), 1.6)
	_burst(player_position, Color("#ffe27a"), 14, 120.0, 0.6, 2.5)
	state = State.PLAYING


# --- Enemies ----------------------------------------------------------------------------------------------------

func _random_room_point() -> Vector2:
	var cells := terrain.get_room_floor_cells(active_room_index)
	if cells.is_empty():
		return player_position
	var cell: Vector2i = cells[enemy_random.randi_range(0, cells.size() - 1)]
	return terrain.cell_to_world(cell)


func _find_spawn_position() -> Vector2:
	for attempt in 30:
		var candidate := _random_room_point()
		if terrain.is_wall_at_world(candidate, 12.0):
			continue
		var min_distance := 110.0 if attempt < 18 else 60.0
		if candidate.distance_to(player_position) < min_distance:
			continue
		var crowded := false
		for other in enemies:
			if other.position.distance_to(candidate) < 36.0:
				crowded = true
		if not crowded:
			return candidate
	return terrain.world_center(rooms[maxi(active_room_index, 0)])


func _spawn_enemy(id: String, affix: String, boss: bool, at: Vector2, quick: bool) -> Enemy:
	var e := Enemy.new()
	var def: Dictionary = GameData.BOSSES[id] if boss else GameData.ENEMIES[id]
	e.id = id
	e.def = def
	e.is_boss = boss
	e.affix = affix
	var hp_scale := 1.0 if boss else 1.0 + 0.22 * float(floor_number - 1)
	var hp := float(def["hp"]) * hp_scale * (2.0 if affix != "" else 1.0)
	e.max_health = hp
	e.health = hp
	e.speed = float(def["speed"]) * (1.35 if affix == "SWIFT" else 1.0)
	e.radius = float(def["radius"]) * (1.15 if affix != "" else 1.0)
	e.damage = int(def["damage"]) + (1 if floor_number >= 5 and not boss else 0)
	e.resist = 0.6 if affix == "ARMORED" else 1.0
	e.tint = Color(str(def["tint"]))
	match affix:
		"SWIFT":
			e.tint = Color("#fff08a")
		"ARMORED":
			e.tint = Color("#a8b8d8")
		"EXPLOSIVE":
			e.tint = Color("#ffa060")
		"SPLITTING":
			e.tint = Color("#9dffb0")
	e.scale_factor = float(def["scale"]) * (1.2 if affix != "" else 1.0)
	e.position = at
	e.target = at
	e.spawn_timer = 0.45 if quick else ENEMY_SPAWN_DELAY
	e.orbit_direction = 1.0 if enemy_random.randf() < 0.5 else -1.0
	e.action_cooldown = _roll_cooldown(e) * 0.7
	var sheet := boss_sheet if boss else bug_sheet
	e.node = Node2D.new()
	var shadow_scale := (1.8 if boss else 1.3) * e.scale_factor
	e.shadow = _create_shadow_sprite(shadow_scale)
	e.shadow.position = Vector2(0, (16 if boss else 12) * e.scale_factor)
	e.node.add_child(e.shadow)
	e.sprite = Sprite2D.new()
	_configure_sheet_sprite(e.sprite, sheet)
	e.node.add_child(e.sprite)
	e.node.position = e.position
	entities_root.add_child(e.node)
	enemies.append(e)
	if boss:
		boss_enemy = e
		boss_lag = 1.0
	_spawn_effect(magic_texture, e.position, Color("#c58cff"), 1.1)
	return e


func _roll_cooldown(e: Enemy) -> float:
	if e.is_boss:
		return [1.5, 1.1, 0.8][clampi(e.phase, 0, 2)]
	var range_value: Array = e.def.get("cooldown", [1.5, 2.5])
	return enemy_random.randf_range(float(range_value[0]), float(range_value[1]))


func _minion_count() -> int:
	var n := 0
	for e in enemies:
		if not e.is_boss:
			n += 1
	return n


func _steer(e: Enemy, target: Vector2) -> Vector2:
	var to_target := target - e.position
	if to_target.length_squared() < 1.0:
		return Vector2.ZERO
	var direct := to_target.normalized()
	for angle in STEER_ANGLES:
		var candidate := direct.rotated(angle)
		if not _path_blocked(e.position, e.position + candidate * 26.0, e.radius - 2.0):
			return candidate
	return Vector2.ZERO


func _path_blocked(from_point: Vector2, to_point: Vector2, radius: float) -> bool:
	var steps := maxi(1, ceili(from_point.distance_to(to_point) / 6.0))
	for i in range(1, steps + 1):
		if terrain.is_wall_at_world(from_point.lerp(to_point, float(i) / float(steps)), radius):
			return true
	return false


func _has_line(from_point: Vector2, to_point: Vector2) -> bool:
	return not _path_blocked(from_point, to_point, 3.0)


func _chase_direction(e: Enemy, direction: Vector2, distance: float, delta: float) -> Vector2:
	if distance > ENEMY_SIGHT_RANGE:
		e.target_timer -= delta
		if e.target_timer <= 0.0 or e.position.distance_to(e.target) < 14.0:
			e.target = _random_room_point()
			e.target_timer = enemy_random.randf_range(0.9, 2.2)
		return _steer(e, e.target)
	return _steer(e, player_position)


func _dash_mult(e: Enemy) -> float:
	return DASH_SPEED_MULT + (0.4 if e.is_boss else 0.0)


func _dash_duration(e: Enemy) -> float:
	return 0.36 if e.is_boss else 0.3


func _slam_radius(e: Enemy) -> float:
	return float(e.def.get("slam_radius", 72.0 if e.is_boss else 52.0))


func _update_enemy_poison(e: Enemy, delta: float) -> void:
	if e.poison_time <= 0.0:
		e.poison_stacks = 0
		return
	e.poison_time -= delta
	e.poison_tick -= delta
	if e.poison_tick <= 0.0:
		e.poison_tick = POISON_TICK
		var amount := POISON_TICK_DAMAGE * float(e.poison_stacks) * GameState.poison_power
		_damage_enemy(e, amount, "poison")


func _update_enemy(e: Enemy, delta: float) -> void:
	e.anim_time += delta
	e.flash = maxf(e.flash - delta, 0.0)
	e.contact_cooldown = maxf(e.contact_cooldown - delta, 0.0)
	if e.spawn_timer > 0.0:
		e.spawn_timer -= delta
		return
	_update_enemy_poison(e, delta)
	if not e.alive:
		return
	var to_player := player_position - e.position
	var distance := to_player.length()
	var direction := to_player / distance if distance > 0.001 else Vector2.DOWN
	if e.is_boss:
		_boss_phase_check(e)
	if e.stun > 0.0:
		e.stun -= delta
		e.velocity = e.velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		_move_enemy(e, delta)
		return
	e.facing = direction
	var speed := e.speed
	if e.is_boss:
		speed *= 1.0 + 0.12 * float(e.phase)

	e.orbit_flip_timer -= delta
	if e.orbit_flip_timer <= 0.0:
		e.orbit_flip_timer = enemy_random.randf_range(2.5, 4.0)
		e.orbit_direction = -e.orbit_direction

	var desired := Vector2.ZERO
	e.action_timer -= delta
	e.action_cooldown -= delta
	match e.action:
		Action.WINDUP:
			if e.action_timer > 0.2 and (e.attack == "dash" or e.attack == "shot" or e.attack == "fan" or e.attack == "slash"):
				e.aim = direction
			e.facing = e.aim
			if e.action_timer <= 0.0:
				_execute_attack(e)
		Action.DASH:
			desired = e.aim * speed * _dash_mult(e)
			e.facing = e.aim
			if e.action_timer <= 0.0:
				if e.dashes_left > 0:
					e.dashes_left -= 1
					_begin_attack(e, "dash", 0.28)
				else:
					_end_attack(e, 0.35)
		Action.RECOVER:
			if e.action_timer <= 0.0:
				e.action = Action.CHASE
		_:
			desired = _ai_movement(e, direction, distance, delta) * speed
			if e.action_cooldown <= 0.0:
				_ai_choose_attack(e, direction, distance)

	e.velocity = e.velocity.move_toward(desired, 300.0 * delta)
	_move_enemy(e, delta)
	_enemy_contact(e, distance)


func _move_enemy(e: Enemy, delta: float) -> void:
	e.knockback = e.knockback.move_toward(Vector2.ZERO, 420.0 * delta)
	var before := e.position
	e.position = _move_with_walls(e.position, (e.velocity + e.knockback) * delta, e.radius)
	var expected := (e.velocity + e.knockback).length() * delta
	if expected > 0.3 and before.distance_to(e.position) < expected * 0.2:
		e.stuck_time += delta
		if e.stuck_time > 0.35:
			e.stuck_time = 0.0
			e.target = _random_room_point()
			e.target_timer = 1.5
			e.velocity = e.velocity.rotated(enemy_random.randf_range(-1.2, 1.2)) * 0.4
			if e.action == Action.DASH:
				_end_attack(e, 0.3)
	else:
		e.stuck_time = 0.0


func _enemy_contact(e: Enemy, distance: float) -> void:
	if not bool(e.def.get("contact", true)):
		return
	if e.action == Action.WINDUP and e.attack == "bomb":
		return
	if distance < e.radius + PLAYER_RADIUS + 2.0 and e.contact_cooldown <= 0.0:
		_hurt_player(e.damage, e.position, e)


func _ai_movement(e: Enemy, direction: Vector2, distance: float, delta: float) -> Vector2:
	match str(e.def.get("ai", "boss" if e.is_boss else "chase")):
		"ranged":
			if distance < 95.0:
				return _steer(e, e.position - direction * 80.0)
			if distance > 165.0:
				return _chase_direction(e, direction, distance, delta)
			return _steer(e, e.position + direction.rotated(PI / 2.0 * e.orbit_direction) * 40.0) * 0.6
		"summoner":
			if distance < 120.0:
				return _steer(e, e.position - direction * 80.0)
			if distance > 210.0:
				return _chase_direction(e, direction, distance, delta)
			return Vector2.ZERO
		"orbit":
			if distance < 150.0:
				var tangent := direction.rotated(PI / 2.0 * e.orbit_direction)
				return _steer(e, e.position + (direction * 0.35 + tangent).normalized() * 40.0)
			return _chase_direction(e, direction, distance, delta)
		"boss":
			if distance > 70.0:
				return _chase_direction(e, direction, distance, delta) * 0.8
			return Vector2.ZERO
		_:
			return _chase_direction(e, direction, distance, delta)


func _ai_choose_attack(e: Enemy, direction: Vector2, distance: float) -> void:
	match str(e.def.get("ai", "boss" if e.is_boss else "chase")):
		"charger":
			if distance < 180.0 and distance > 40.0:
				_begin_attack(e, "dash", 0.45)
		"orbit":
			if distance < 190.0 and distance > 40.0:
				_begin_attack(e, "dash", 0.3)
		"ranged":
			if distance < 240.0 and _has_line(e.position, player_position):
				_begin_attack(e, "shot", 0.55)
		"bomber":
			if distance < 40.0:
				_begin_attack(e, "bomb", 0.6)
		"tank":
			if distance < 72.0:
				_begin_attack(e, "slam", 0.8)
		"summoner":
			if _minion_count() < 5:
				_begin_attack(e, "summon", 0.8)
		"boss":
			_boss_choose_attack(e, distance)
	if e.action == Action.CHASE:
		e.action_cooldown = 0.25


func _begin_attack(e: Enemy, kind: String, windup: float) -> void:
	e.action = Action.WINDUP
	e.attack = kind
	e.action_timer = windup
	e.windup_total = windup
	e.aim = (player_position - e.position).normalized()
	if e.aim == Vector2.ZERO:
		e.aim = Vector2.DOWN
	e.velocity = e.velocity * 0.3


func _end_attack(e: Enemy, recover: float) -> void:
	e.action = Action.RECOVER
	e.action_timer = recover
	e.action_cooldown = _roll_cooldown(e)
	e.attack = ""


func _execute_attack(e: Enemy) -> void:
	match e.attack:
		"dash":
			e.action = Action.DASH
			e.action_timer = _dash_duration(e)
		"slam":
			var radius := _slam_radius(e)
			_spawn_ring(e.position, radius, Color("#ff8a5a"))
			_burst(e.position, Color("#ffb080"), 14, 140.0, 0.4, 3.0)
			_add_shake(4.0 if e.is_boss else 2.5)
			if player_position.distance_to(e.position) < radius + PLAYER_RADIUS * 0.5:
				_hurt_player(e.damage + (1 if e.is_boss else 0), e.position)
			_end_attack(e, 0.5)
		"shot":
			var count := 3 if (floor_number >= 4 and not e.is_boss) else 1
			for i in count:
				var spread := (float(i) - float(count - 1) * 0.5) * 0.3
				_fire_enemy_projectile(e.position, e.aim.rotated(spread), 130.0, e.damage, Color("#9dff6a"))
			_play_sound(attack_sound, -10.0, 0.6)
			_end_attack(e, 0.4)
		"fan":
			var n := 5 + e.phase * 2
			for i in n:
				var spread := (float(i) - float(n - 1) * 0.5) * (1.4 / float(n - 1))
				_fire_enemy_projectile(e.position, e.aim.rotated(spread), 120.0, 1, Color("#ff7a9a"))
			_play_sound(attack_sound, -8.0, 0.6)
			_end_attack(e, 0.5)
		"ring":
			var n := 12 + e.phase * 4
			var offset: float = enemy_random.randf() * TAU
			for i in n:
				_fire_enemy_projectile(e.position, Vector2.from_angle(offset + TAU * float(i) / float(n)), 105.0, 1, Color("#c58cff"))
			_spawn_ring(e.position, 30.0, Color("#c58cff"))
			_end_attack(e, 0.5)
		"summon":
			var minion := str(e.def.get("minion", "grub"))
			if not e.is_boss:
				minion = "grub"
			var n := 2 + e.phase
			for i in n:
				if _minion_count() >= 7:
					break
				var at := _point_near(e.position, 30.0, 60.0)
				_spawn_enemy(minion, "", false, at, true)
			_spawn_ring(e.position, 40.0, Color("#d9a8ff"))
			_end_attack(e, 0.5)
		"blink":
			_spawn_ring(e.position, 24.0, Color("#7cc8ff"))
			e.position = _point_near(player_position, 70.0, 110.0)
			e.velocity = Vector2.ZERO
			_spawn_ring(e.position, 24.0, Color("#7cc8ff"))
			_burst(e.position, Color("#9fd8ff"), 12, 120.0, 0.4, 2.5)
			var follow := "slash" if enemy_random.randf() < 0.6 else "fan"
			_begin_attack(e, follow, 0.35)
		"puddles":
			var n := 3 + e.phase
			for i in n:
				var at := player_position + Vector2.from_angle(enemy_random.randf() * TAU) * enemy_random.randf_range(0.0, 60.0)
				if terrain.is_wall_at_world(at, 8.0):
					at = player_position
				_spawn_hazard("acid", at, 26.0, 5.0, 0.9)
			_end_attack(e, 0.5)
		"slash":
			_spawn_arc_enemy(e)
			var offset: Vector2 = player_position - e.position
			if offset.length() < SLASH_RANGE + PLAYER_RADIUS and absf(e.aim.angle_to(offset)) < SLASH_ARC + 0.2:
				_hurt_player(e.damage, e.position)
			_add_shake(3.0)
			_end_attack(e, 0.45)
		"bomb":
			_explode(e.position, 46.0, e.damage, true, false, Color("#ff9a4a"))
			_kill_enemy(e, "self")
		_:
			_end_attack(e, 0.3)


func _spawn_arc_enemy(e: Enemy) -> void:
	arcs.append({"position": e.position, "angle": e.aim.angle(), "radius": SLASH_RANGE - 6.0, "half": SLASH_ARC, "life": 0.2, "max_life": 0.2, "color": Color("#ff6b6b")})


func _point_near(center: Vector2, min_d: float, max_d: float) -> Vector2:
	for attempt in 20:
		var candidate := center + Vector2.from_angle(enemy_random.randf() * TAU) * enemy_random.randf_range(min_d, max_d)
		if not terrain.is_wall_at_world(candidate, 12.0) and terrain.room_index_at_world(candidate) == active_room_index:
			return candidate
	return center


func _boss_phase_check(e: Enemy) -> void:
	var ratio := e.health / e.max_health
	var new_phase := 0
	if ratio <= 0.33:
		new_phase = 2
	elif ratio <= 0.66:
		new_phase = 1
	if new_phase > e.phase:
		e.phase = new_phase
		_spawn_ring(e.position, 80.0, Color("#ff6b6b"))
		_add_shake(5.0)
		_toast("%s ENRAGES!" % str(e.def["name"]), Color("#ff8a8a"))
		_play_sound(door_sound, 0.0, 0.6)
		_burst(e.position, Color("#ff6b6b"), 20, 160.0, 0.5, 3.0)


func _boss_choose_attack(e: Enemy, distance: float) -> void:
	var phases: Array = e.def["phases"]
	var options: Array = phases[clampi(e.phase, 0, phases.size() - 1)]
	var choice := str(options[enemy_random.randi_range(0, options.size() - 1)])
	if choice == e.last_attack and options.size() > 1:
		choice = str(options[enemy_random.randi_range(0, options.size() - 1)])
	if (choice == "slam" or choice == "slash") and distance > 110.0:
		choice = "charge"
	e.last_attack = choice
	if choice == "charge":
		e.dashes_left = int(e.def.get("charges", 0)) + (e.phase if e.id == "hornet" else 0)
		_begin_attack(e, "dash", float(WINDUPS["charge"]))
	else:
		_begin_attack(e, choice, float(WINDUPS.get(choice, 0.6)))


func _fire_enemy_projectile(from_pos: Vector2, direction: Vector2, speed: float, damage: int, color: Color) -> void:
	enemy_projectiles.append({"position": from_pos + direction * 10.0, "velocity": direction * speed, "life": 3.0, "damage": damage, "radius": 5.0, "color": color, "reflected": false})


func _separate_enemies() -> void:
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			var offset: Vector2 = enemies[j].position - enemies[i].position
			var min_distance := enemies[i].radius + enemies[j].radius
			var distance := offset.length()
			if distance < min_distance and distance > 0.01:
				var push := offset / distance * (min_distance - distance) * 0.5
				enemies[i].position = _move_with_walls(enemies[i].position, -push, enemies[i].radius)
				enemies[j].position = _move_with_walls(enemies[j].position, push, enemies[j].radius)


# --- Damage, death, loot ---------------------------------------------------------------------------------------------------

func _register_hit() -> void:
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_pop = 1.0
	if combo > GameState.run_best_combo:
		GameState.run_best_combo = combo
	if combo > 0 and combo % 10 == 0:
		_toast("COMBO x%d!" % combo, Color("#ffb84d"))
		_gain_amber(3, player_position)


func _damage_enemy(e: Enemy, amount: float, source: String, crit: bool = false) -> void:
	if not e.alive:
		return
	var dmg := amount * e.resist
	e.health -= dmg
	if source == "poison":
		e.poison_accum += dmg
		if e.poison_accum >= 1.0:
			var whole := floorf(e.poison_accum)
			e.poison_accum -= whole
			_float_text(str(int(whole)), e.position + Vector2(enemy_random.randf_range(-6, 6), -e.radius - 8), Color("#8bf08b"), 8)
	else:
		var shown := maxi(1, roundi(dmg))
		if crit:
			_float_text("%d!" % shown, e.position + Vector2(enemy_random.randf_range(-6, 6), -e.radius - 10), Color("#ffb040"), 12)
			_add_shake(2.0)
			JuiceManager.freeze_frame(0.045)
		else:
			_float_text(str(shown), e.position + Vector2(enemy_random.randf_range(-6, 6), -e.radius - 8), Color("#fff0a6"), 9)
		_register_hit()
	if e.flash <= 0.0 and is_instance_valid(e.sprite):
		JuiceManager.flash_white(e.sprite, 0.12)
	e.flash = 0.12
	if e.health <= 0.0:
		_kill_enemy(e, source)


func _kill_enemy(e: Enemy, source: String) -> void:
	if not e.alive:
		return
	e.alive = false
	enemies.erase(e)
	var counts := source != "self"
	var color := Color("#8bf08b")
	_spawn_effect(magic_texture, e.position, color, 1.5 if e.is_boss else 1.0)
	_spawn_effect(spark_texture, e.position, Color("#fff0a6"), 1.2)
	_burst(e.position, color, 16 if e.is_boss else 9, 130.0, 0.5, 3.0)
	_play_sound(hit_sound, -2.0, 0.8)
	_add_shake(4.0 if e.is_boss else 2.0)
	if counts:
		JuiceManager.freeze_frame(0.05)
		var points := int(e.def.get("points", 10))
		GameState.run_score += int(float(points) * (1.0 + 0.1 * float(mini(combo, 20))))
		GameState.run_kills += 1
		_drop_loot(e)
		if e.poison_stacks > 0 and GameState.poison_spread > 0:
			_spread_poison(e)
		if source == "poison" and GameState.caustic > 0:
			_explode(e.position, 44.0, 0, false, true, Color("#9dff6a"), 3.0 * float(GameState.caustic) + GameState.spit_damage)
		if source == "bite" and GameState.bite_leech > 0.0 and enemy_random.randf() < GameState.bite_leech:
			_heal_player(1)
	match e.affix:
		"EXPLOSIVE":
			_explode(e.position, 48.0, 2, true, false, Color("#ff9a4a"))
		"SPLITTING":
			if counts:
				for i in 2:
					_spawn_enemy("grub", "", false, _point_near(e.position, 10.0, 24.0), true)
	if e.is_boss:
		_on_boss_killed(e)
	if is_instance_valid(e.node):
		var tween := e.node.create_tween()
		tween.set_parallel(true)
		tween.tween_property(e.node, "scale", Vector2(1.4, 0.4), 0.22)
		tween.tween_property(e.node, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(e.node.queue_free)


func _on_boss_killed(e: Enemy) -> void:
	boss_enemy = null
	spawn_queue.clear()
	for other in enemies.duplicate():
		_kill_enemy(other, "self")
	_spawn_ring(e.position, 120.0, Color("#fff0a6"))
	_burst(e.position, Color("#ffe27a"), 40, 200.0, 0.9, 3.5)
	_add_shake(8.0)
	_gain_amber(int(e.def.get("amber", 20)), e.position)
	JuiceManager.freeze_frame(0.18)
	_toast("%s DEFEATED" % str(e.def["name"]), Color("#ffe27a"))


func _spread_poison(e: Enemy) -> void:
	for other in enemies:
		if other == e or not other.alive:
			continue
		if other.position.distance_to(e.position) < 80.0:
			other.poison_stacks = mini(other.poison_stacks + GameState.poison_spread, GameState.poison_stack_cap)
			other.poison_time = maxf(other.poison_time, GameState.poison_duration)
			_burst(other.position, Color("#8bf08b"), 4, 50.0, 0.4, 2.0)


func _explode(pos: Vector2, radius: float, damage: int, hurt_player: bool, hurt_enemies: bool, color: Color, enemy_damage: float = 6.0) -> void:
	_spawn_ring(pos, radius, color)
	_spawn_effect(magic_texture, pos, color, radius / 30.0)
	_burst(pos, color, 18, 170.0, 0.5, 3.0)
	_add_shake(4.0)
	_play_sound(hit_sound, 0.0, 0.6)
	if hurt_player and player_position.distance_to(pos) < radius + PLAYER_RADIUS * 0.5:
		_hurt_player(damage, pos)
	if hurt_enemies:
		for e in enemies.duplicate():
			if e.alive and e.position.distance_to(pos) < radius + e.radius:
				e.knockback = (e.position - pos).normalized() * 200.0
				_damage_enemy(e, enemy_damage, "explosion")


@warning_ignore("integer_division")
func _gain_amber(amount: int, at: Vector2) -> void:
	var n := maxi(1, roundi(float(amount) * GameState.amber_mult))
	var orbs := mini(n, 10)
	var per := n / orbs
	var rest := n - per * orbs
	for i in orbs:
		var value := per + (1 if i < rest else 0)
		pickups.append({"position": at, "velocity": Vector2.from_angle(enemy_random.randf() * TAU) * enemy_random.randf_range(40.0, 110.0), "kind": "amber", "age": 0.0, "value": value})


func _drop_loot(e: Enemy) -> void:
	_gain_amber(int(e.def.get("amber", 1)), e.position)
	var heal_chance := 0.10 + GameState.luck * 0.3
	if player_health < player_max_health and enemy_random.randf() < heal_chance:
		pickups.append({"position": e.position, "velocity": Vector2.from_angle(enemy_random.randf() * TAU) * 60.0, "kind": "jelly", "age": 0.0, "value": 1})


# --- Projectiles, hazards, pickups ---------------------------------------------------------------------------------------------

func _update_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for p in projectiles:
		var previous: Vector2 = p["position"]
		var velocity: Vector2 = p["velocity"]
		var next_position := previous + velocity * delta
		p["life"] = float(p["life"]) - delta
		if _projectile_hits_wall(previous, next_position):
			if int(p["bounce"]) > 0:
				p["bounce"] = int(p["bounce"]) - 1
				if _projectile_hits_wall(previous, Vector2(next_position.x, previous.y)):
					velocity.x = -velocity.x
				if _projectile_hits_wall(previous, Vector2(previous.x, next_position.y)):
					velocity.y = -velocity.y
				p["velocity"] = velocity
				_burst(previous, Color("#b6ffb6"), 3, 60.0, 0.2, 2.0)
				if float(p["life"]) > 0.0:
					remaining.append(p)
				continue
			_spawn_effect(spark_texture, next_position, Color("#8ba4b8"), 0.4)
			continue
		p["position"] = next_position
		var hit_list: Array = p["hit"]
		var hit: Enemy = null
		for e in enemies:
			if e.alive and e.spawn_timer <= 0.0 and not hit_list.has(e) and next_position.distance_to(e.position) < e.radius + 7.0:
				hit = e
				break
		if hit != null:
			_hit_enemy(hit, velocity.normalized(), float(p["damage"]), bool(p["crit"]))
			hit_list.append(hit)
			if int(p["pierce"]) > 0:
				p["pierce"] = int(p["pierce"]) - 1
			else:
				continue
		if float(p["life"]) > 0.0:
			remaining.append(p)
	projectiles = remaining


func _projectile_hits_wall(start: Vector2, end: Vector2) -> bool:
	var steps := maxi(1, ceili(start.distance_to(end) / 4.0))
	for step in range(1, steps + 1):
		if terrain.is_wall_at_world(start.lerp(end, float(step) / float(steps)), 2.0):
			return true
	return false


func _hit_enemy(e: Enemy, direction: Vector2, damage: float, crit: bool) -> void:
	e.poison_stacks = mini(e.poison_stacks + 1, GameState.poison_stack_cap)
	if e.poison_time <= 0.0:
		e.poison_tick = POISON_TICK
	e.poison_time = GameState.poison_duration
	e.knockback = direction * (50.0 if e.is_boss else 100.0)
	_spawn_effect(spark_texture, e.position, Color("#8bf08b"), 0.9)
	_burst(e.position, Color("#8bf08b"), 4, 90.0, 0.25, 2.0)
	_play_sound(hit_sound, -4.0)
	_damage_enemy(e, damage, "spit", crit)


func _update_enemy_projectiles(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for p in enemy_projectiles:
		var previous: Vector2 = p["position"]
		var velocity: Vector2 = p["velocity"]
		var next_position := previous + velocity * delta
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			continue
		if _projectile_hits_wall(previous, next_position):
			_burst(next_position, Color(p["color"]), 4, 60.0, 0.25, 2.0)
			continue
		p["position"] = next_position
		if bool(p["reflected"]):
			var hit_enemy := false
			for e in enemies.duplicate():
				if e.alive and e.spawn_timer <= 0.0 and next_position.distance_to(e.position) < e.radius + 5.0:
					_damage_enemy(e, GameState.spit_damage * 2.0, "reflect")
					hit_enemy = true
					break
			if hit_enemy:
				continue
		elif next_position.distance_to(player_position) < float(p["radius"]) + PLAYER_RADIUS - 2.0:
			if player_invulnerable <= 0.0 and dash_time <= 0.0:
				_hurt_player(int(p["damage"]), previous)
				continue
		remaining.append(p)
	enemy_projectiles = remaining


func _spawn_hazard(kind: String, at: Vector2, radius: float, life: float, delay: float) -> void:
	hazards.append({"kind": kind, "position": at, "radius": radius, "life": life, "max_life": life, "delay": delay, "tick": 0.0})


func _update_hazards(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for h in hazards:
		if float(h["delay"]) > 0.0:
			h["delay"] = float(h["delay"]) - delta
			remaining.append(h)
			continue
		h["life"] = float(h["life"]) - delta
		h["tick"] = float(h["tick"]) - delta
		if float(h["tick"]) <= 0.0:
			h["tick"] = 0.5
			var at: Vector2 = h["position"]
			var radius := float(h["radius"])
			if str(h["kind"]) == "acid":
				if player_position.distance_to(at) < radius + PLAYER_RADIUS * 0.5:
					_hurt_player(1, at)
			else:
				for e in enemies.duplicate():
					if e.alive and e.spawn_timer <= 0.0 and e.position.distance_to(at) < radius + e.radius:
						e.poison_stacks = mini(e.poison_stacks + 1, GameState.poison_stack_cap)
						e.poison_time = maxf(e.poison_time, GameState.poison_duration)
						_damage_enemy(e, 1.0 + 0.5 * float(GameState.trail_level), "hazard")
		if float(h["life"]) > 0.0:
			remaining.append(h)
	hazards = remaining


func _update_pickups(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for p in pickups:
		p["age"] = float(p["age"]) + delta
		var position_value: Vector2 = p["position"]
		var velocity: Vector2 = p["velocity"]
		velocity = velocity.move_toward(Vector2.ZERO, 220.0 * delta)
		var to_player := player_position - position_value
		var distance := to_player.length()
		if float(p["age"]) > 0.35 and distance < GameState.magnet_range:
			velocity = to_player.normalized() * (150.0 + (GameState.magnet_range - distance) * 3.0)
		position_value += velocity * delta
		p["position"] = position_value
		p["velocity"] = velocity
		if distance < 12.0 and float(p["age"]) > 0.2:
			if str(p["kind"]) == "amber":
				GameState.run_amber += int(p["value"])
				_play_sound(coin_sound, -12.0, 1.0 + enemy_random.randf() * 0.3)
				_spawn_particle(position_value, Vector2(0, -30), Color("#ffc247"), 0.3, 3.0, 0.0)
			else:
				_heal_player(int(p["value"]))
				_play_sound(coin_sound, -8.0, 0.7)
			continue
		if float(p["age"]) < 25.0:
			remaining.append(p)
	pickups = remaining


# --- Effects ----------------------------------------------------------------------------------------------------------------------------

func _spawn_effect(texture: Texture2D, at: Vector2, tint: Color, scale_value: float) -> void:
	if texture == null:
		return
	effects.append({"texture": texture, "position": at, "tint": tint, "scale": scale_value, "life": 0.3, "max_life": 0.3})


func _spawn_ring(at: Vector2, radius: float, color: Color) -> void:
	rings.append({"position": at, "radius": radius, "color": color, "life": 0.4, "max_life": 0.4})


func _spawn_particle(at: Vector2, velocity: Vector2, color: Color, life: float, size: float, drag: float) -> void:
	if particles.size() >= 450:
		return
	particles.append({"position": at, "velocity": velocity, "color": color, "life": life, "max_life": life, "size": size, "drag": drag})


func _burst(at: Vector2, color: Color, count: int, speed: float, life: float, size: float) -> void:
	for i in count:
		var angle := enemy_random.randf() * TAU
		var v := Vector2.from_angle(angle) * speed * enemy_random.randf_range(0.3, 1.0)
		_spawn_particle(at, v, color, life * enemy_random.randf_range(0.6, 1.0), size * enemy_random.randf_range(0.6, 1.0), 4.0)


func _float_text(s: String, at: Vector2, color: Color, size: int) -> void:
	floaters.append({"text": s, "position": at, "life": 0.8, "color": color, "size": size})


func _toast(s: String, color: Color) -> void:
	toasts.append({"text": s, "color": color, "life": 3.0})
	if toasts.size() > 5:
		toasts.pop_front()


func _update_effects(delta: float) -> void:
	for effect in effects:
		effect["life"] = float(effect["life"]) - delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return float(effect["life"]) > 0.0)
	for floater in floaters:
		floater["life"] = float(floater["life"]) - delta
		floater["position"] = floater["position"] + Vector2(0, -22.0 * delta)
	floaters = floaters.filter(func(floater: Dictionary) -> bool: return float(floater["life"]) > 0.0)
	for r in rings:
		r["life"] = float(r["life"]) - delta
	rings = rings.filter(func(r: Dictionary) -> bool: return float(r["life"]) > 0.0)
	for a in arcs:
		a["life"] = float(a["life"]) - delta
	arcs = arcs.filter(func(a: Dictionary) -> bool: return float(a["life"]) > 0.0)
	for p in particles:
		p["life"] = float(p["life"]) - delta
		var v: Vector2 = p["velocity"]
		v *= maxf(0.0, 1.0 - float(p["drag"]) * delta)
		p["velocity"] = v
		p["position"] = Vector2(p["position"]) + v * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)
	for t in toasts:
		t["life"] = float(t["life"]) - delta
	toasts = toasts.filter(func(t: Dictionary) -> bool: return float(t["life"]) > 0.0)
	combo_pop = maxf(combo_pop - delta * 5.0, 0.0)
	if boss_enemy != null:
		var ratio := boss_enemy.health / boss_enemy.max_health
		boss_lag = maxf(ratio, boss_lag - delta * 0.35) if boss_lag > ratio else ratio


func _update_enemy_visual(e: Enemy) -> void:
	if not is_instance_valid(e.node):
		return
	e.node.position = e.position
	var sheet := boss_sheet if e.is_boss else bug_sheet
	var frame := int(e.anim_time * 7.0) % 3
	var column := int(e.def.get("col", 9))
	e.sprite.frame_coords = _sheet_frame(sheet, column + frame, _direction_row(e.facing))
	var tint := e.tint
	if e.poison_time > 0.0:
		tint = tint.lerp(Color(0.6, 1.0, 0.6), 0.45)
	if e.action == Action.WINDUP:
		var pulse := 0.5 + 0.5 * sin(torch_time * 40.0)
		tint = Color(1.0, 0.45 + pulse * 0.3, 0.4)
	elif e.stun > 0.0:
		tint = Color(0.7, 0.7, 1.0)
	if e.spawn_timer > 0.0:
		var progress := 1.0 - e.spawn_timer / ENEMY_SPAWN_DELAY
		tint.a = 0.25 + clampf(progress, 0.0, 1.0) * 0.4
		e.sprite.scale = Vector2.ONE * e.scale_factor * (0.6 + clampf(progress, 0.0, 1.0) * 0.4)
	else:
		e.sprite.scale = Vector2.ONE * e.scale_factor
	e.sprite.modulate = tint


# --- Drawing ---------------------------------------------------------------------------------------------------------------------------

func _draw_ground_overlay() -> void:
	var t := torch_time
	for i in rooms.size():
		if cleared_rooms[i]:
			continue
		var type := rooms[i].type
		var center := terrain.world_center(rooms[i])
		if type == GameData.ROOM_TREASURE:
			var glow := 0.5 + 0.5 * sin(t * 3.0)
			ground_overlay.draw_circle(center, 16.0 + glow * 3.0, Color("#ffd35c", 0.18))
			ground_overlay.draw_circle(center, 9.0, Color("#6b4a35"))
			ground_overlay.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8.0 - glow), center + Vector2(6, 0), center + Vector2(0, 8), center + Vector2(-6, 0)]), Color("#ffd35c"))
		elif type == GameData.ROOM_REST:
			var glow2 := 0.5 + 0.5 * sin(t * 2.5)
			ground_overlay.draw_circle(center, 18.0 + glow2 * 2.0, Color("#6fe0ff", 0.16))
			ground_overlay.draw_circle(center, 11.0, Color("#2a5f7a"))
			ground_overlay.draw_arc(center, 11.0 + glow2 * 3.0, 0.0, TAU, 24, Color("#9ff0ff", 0.8), 1.5)
	if portal_active:
		for k in 4:
			var radius := 10.0 + float(k) * 5.0 + sin(t * 4.0 + float(k)) * 2.0
			ground_overlay.draw_arc(portal_position, radius, t * (1.0 + float(k) * 0.4), t * (1.0 + float(k) * 0.4) + TAU * 0.75, 20, Color("#c58cff", 0.9 - float(k) * 0.18), 2.0)
		ground_overlay.draw_circle(portal_position, 8.0, Color("#2a1040"))
	for h in hazards:
		var at: Vector2 = h["position"]
		var radius := float(h["radius"])
		var acid := str(h["kind"]) == "acid"
		var base := Color("#ff4a6a") if acid else Color("#6dff6d")
		if float(h["delay"]) > 0.0:
			ground_overlay.draw_arc(at, radius, 0.0, TAU, 24, Color(base, 0.6), 1.0)
			ground_overlay.draw_circle(at, radius, Color(base, 0.08))
		else:
			var fade_alpha := clampf(float(h["life"]) / 0.6, 0.0, 1.0)
			ground_overlay.draw_circle(at, radius, Color(base, 0.28 * fade_alpha))
			ground_overlay.draw_arc(at, radius, 0.0, TAU, 24, Color(base, 0.7 * fade_alpha), 1.5)
	for e in enemies:
		if e.action == Action.WINDUP and e.spawn_timer <= 0.0:
			_draw_telegraph(e)
	for p in pickups:
		var at2: Vector2 = p["position"]
		var bob := sin(t * 6.0 + at2.x) * 1.2
		if str(p["kind"]) == "amber":
			ground_overlay.draw_colored_polygon(PackedVector2Array([at2 + Vector2(0, -4 + bob), at2 + Vector2(3, bob), at2 + Vector2(0, 4 + bob), at2 + Vector2(-3, bob)]), Color("#ffc247"))
		else:
			UiKit.heart(ground_overlay, at2 + Vector2(0, bob), 7.0, Color("#ff5d73"))


func _draw_telegraph(e: Enemy) -> void:
	var progress := 1.0 - clampf(e.action_timer / maxf(e.windup_total, 0.01), 0.0, 1.0)
	var red := Color(1.0, 0.25, 0.25)
	match e.attack:
		"dash":
			var length := e.speed * _dash_mult(e) * _dash_duration(e)
			ground_overlay.draw_line(e.position, e.position + e.aim * length, Color(red, 0.2 + 0.35 * progress), 2.0 + 6.0 * progress)
		"slam":
			var radius := _slam_radius(e)
			ground_overlay.draw_circle(e.position, radius * progress, Color(red, 0.2))
			ground_overlay.draw_arc(e.position, radius, 0.0, TAU, 32, Color(red, 0.6), 1.5)
		"shot":
			ground_overlay.draw_line(e.position, e.position + e.aim * 110.0, Color(0.6, 1.0, 0.4, 0.2 + 0.4 * progress), 1.5)
		"fan":
			var n := 5 + e.phase * 2
			for i in n:
				var spread := (float(i) - float(n - 1) * 0.5) * (1.4 / float(n - 1))
				ground_overlay.draw_line(e.position, e.position + e.aim.rotated(spread) * 90.0, Color(1.0, 0.4, 0.5, 0.15 + 0.3 * progress), 1.0)
		"slash":
			var pts := PackedVector2Array([e.position])
			var base_angle := e.aim.angle()
			for k in 9:
				var a := base_angle - SLASH_ARC + SLASH_ARC * 2.0 * float(k) / 8.0
				pts.append(e.position + Vector2(cos(a), sin(a)) * SLASH_RANGE)
			ground_overlay.draw_colored_polygon(pts, Color(red, 0.12 + 0.25 * progress))
		"bomb":
			var flash := 0.5 + 0.5 * sin(torch_time * 40.0)
			ground_overlay.draw_circle(e.position, 46.0 * progress, Color(1.0, 0.6, 0.2, 0.15 + 0.2 * flash))
			ground_overlay.draw_arc(e.position, 46.0, 0.0, TAU, 28, Color(1.0, 0.6, 0.2, 0.6), 1.5)
		"ring", "summon", "puddles":
			ground_overlay.draw_arc(e.position, 18.0 + progress * 50.0, 0.0, TAU, 24, Color(0.78, 0.55, 1.0, 0.8 - progress * 0.4), 1.5)
		"blink":
			ground_overlay.draw_arc(e.position, 20.0 * (1.0 - progress) + 6.0, 0.0, TAU, 20, Color(0.5, 0.8, 1.0, 0.9), 1.5)


func _draw_world_overlay() -> void:
	for e in enemies:
		if e.spawn_timer > 0.0:
			var progress := e.spawn_timer / ENEMY_SPAWN_DELAY
			world_overlay.draw_arc(e.position, 10.0 + progress * 16.0, 0.0, TAU, 24, Color(0.78, 0.55, 1.0, 0.8), 1.5)
		elif not e.is_boss and (e.health < e.max_health or e.affix != ""):
			var width := 26.0 if e.affix != "" else 22.0
			var top := e.position + Vector2(-width * 0.5, -e.radius - 18.0)
			world_overlay.draw_rect(Rect2(top - Vector2.ONE, Vector2(width + 2.0, 5.0)), Color(0.07, 0.05, 0.1, 0.9))
			world_overlay.draw_rect(Rect2(top, Vector2(width * clampf(e.health / e.max_health, 0.0, 1.0), 3.0)), Color("#e85d75") if e.affix == "" else Color("#ffb84d"))
			if e.poison_stacks > 0:
				for k in e.poison_stacks:
					world_overlay.draw_circle(top + Vector2(2.0 + float(k) * 4.0, -3.0), 1.4, Color("#8bf08b"))
			if e.affix != "":
				var font := UiKit.font()
				world_overlay.draw_string_outline(font, top + Vector2(-8, -6), e.affix, HORIZONTAL_ALIGNMENT_CENTER, width + 16.0, 6, 2, Color(0, 0, 0, 0.9))
				world_overlay.draw_string(font, top + Vector2(-8, -6), e.affix, HORIZONTAL_ALIGNMENT_CENTER, width + 16.0, 6, Color("#ffd9a0"))
	if player_armor > 0 and state != State.DYING:
		world_overlay.draw_arc(player_position, 13.0, 0.0, TAU, 24, Color(0.5, 0.8, 1.0, 0.35 + 0.15 * sin(torch_time * 5.0)), 1.5)
	for p in projectiles:
		var position_value: Vector2 = p["position"]
		var velocity: Vector2 = p["velocity"]
		var crit := bool(p["crit"])
		world_overlay.draw_line(position_value - velocity.normalized() * 11.0, position_value, Color(0.43, 0.81, 0.48, 0.7), 3.0)
		world_overlay.draw_circle(position_value, 5.5 if crit else 5.0, Color(1.0, 0.85, 0.4, 0.9) if crit else Color(0.55, 0.94, 0.55, 0.85))
		world_overlay.draw_circle(position_value, 2.0, Color("#e1ffe1"))
	for p in enemy_projectiles:
		var at: Vector2 = p["position"]
		var color: Color = p["color"]
		if bool(p["reflected"]):
			color = Color("#8bf08b")
		world_overlay.draw_circle(at, float(p["radius"]) + 2.0, Color(color, 0.3))
		world_overlay.draw_circle(at, float(p["radius"]), color)
		world_overlay.draw_circle(at, 2.0, Color.WHITE)
	var font2 := UiKit.font()
	for floater in floaters:
		var color2: Color = floater["color"]
		color2.a = clampf(float(floater["life"]) / 0.35, 0.0, 1.0)
		var size := int(floater["size"])
		var at2: Vector2 = floater["position"]
		world_overlay.draw_string_outline(font2, at2 - Vector2(20, 0), str(floater["text"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, size, 3, Color(0, 0, 0, color2.a))
		world_overlay.draw_string(font2, at2 - Vector2(20, 0), str(floater["text"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, size, color2)


func _draw_fx_overlay() -> void:
	for effect in effects:
		var alpha := clampf(float(effect["life"]) / float(effect["max_life"]), 0.0, 1.0)
		var size := Vector2(48.0, 48.0) * float(effect["scale"]) * (1.0 + (1.0 - alpha) * 0.35)
		var tint: Color = effect["tint"]
		tint.a = alpha
		var texture: Texture2D = effect["texture"]
		var at: Vector2 = effect["position"]
		fx_overlay.draw_texture_rect(texture, Rect2(at - size / 2.0, size), false, tint)
	for r in rings:
		var life_ratio := float(r["life"]) / float(r["max_life"])
		var radius := float(r["radius"]) * (1.0 - life_ratio * 0.6)
		var color: Color = r["color"]
		fx_overlay.draw_arc(Vector2(r["position"]), radius, 0.0, TAU, 40, Color(color, life_ratio * 0.9), 2.5)
	for a in arcs:
		var life_ratio := float(a["life"]) / float(a["max_life"])
		var color: Color = a["color"]
		var angle := float(a["angle"])
		var half := float(a["half"])
		fx_overlay.draw_arc(Vector2(a["position"]), float(a["radius"]) + (1.0 - life_ratio) * 8.0, angle - half, angle + half, 16, Color(color, life_ratio), 3.0 + life_ratio * 3.0)
	for p in particles:
		var life_ratio := float(p["life"]) / float(p["max_life"])
		var size := float(p["size"]) * (0.4 + 0.6 * life_ratio)
		var color: Color = p["color"]
		color.a *= life_ratio
		fx_overlay.draw_rect(Rect2(Vector2(p["position"]) - Vector2(size, size) * 0.5, Vector2(size, size)), color)


# --- Audio and HUD -----------------------------------------------------------------------------------------------------------------------

func _play_sound(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null or audio_players.is_empty():
		return
	var player := audio_players[audio_cursor]
	audio_cursor = (audio_cursor + 1) % audio_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * enemy_random.randf_range(0.94, 1.06)
	player.play()


func _stat_lines() -> Array:
	var shots_per_second := 1.0 / maxf(GameState.spit_cooldown, 0.01)
	return [
		["SPIT DAMAGE", "%d x%d" % [int(GameState.spit_damage), GameState.spit_count]],
		["SPIT RATE", "%.1f / s" % shots_per_second],
		["POISON", "%d stacks, %.1fs" % [GameState.poison_stack_cap, GameState.poison_duration]],
		["BITE DAMAGE", str(int(GameState.bite_damage))],
		["CRIT CHANCE", "%d%%" % int(GameState.crit_chance * 100.0)],
		["MOVE SPEED", str(int(GameState.player_speed))],
		["DASH", "%d charge(s), %.1fs" % [GameState.dash_charges, GameState.dash_cooldown]],
		["SHIELD", str(GameState.armor_max)],
		["MAX HEALTH", str(GameState.max_health)],
		["AMBER BONUS", "+%d%%" % int((GameState.amber_mult - 1.0) * 100.0)]
	]


func _owned_upgrades() -> Array:
	var owned: Array = []
	for u in GameData.UPGRADES:
		var level := GameState.upgrade_level(str(u["id"]))
		if level > 0:
			owned.append({"name": u["name"], "level": level, "rarity": u["rarity"], "glyph": u["glyph"]})
	return owned


func _refresh_hud() -> void:
	if hud == null or rooms.is_empty():
		return
	var status := PackedInt32Array()
	var types := PackedInt32Array()
	var cleared_count := 0
	for i in rooms.size():
		if cleared_rooms[i]:
			cleared_count += 1
		var code := 0
		if i == active_room_index:
			code = 2
		elif cleared_rooms[i]:
			code = 1
		elif visited_rooms[i]:
			code = 3
		status.append(code)
		types.append(rooms[i].type)
	var banner_alpha := 0.0
	if banner_time > 0.0:
		banner_alpha = minf(minf((banner_total - banner_time) / 0.3, banner_time / 0.8), 1.0)
	var room_name := "THE TUNNELS"
	var status_text := "The tunnels hum with distant chittering..."
	if current_room_index >= 0:
		room_name = rooms[current_room_index].title
		status_text = "ROOM CLEARED" if cleared_rooms[current_room_index] else rooms[current_room_index].description
		var rtype := rooms[current_room_index].type
		if rtype == GameData.ROOM_TREASURE and not cleared_rooms[current_room_index]:
			status_text = "Step onto the altar to claim a gift"
		elif rtype == GameData.ROOM_REST and not cleared_rooms[current_room_index]:
			status_text = "Step into the spring to recover"
	if portal_active:
		status_text = "The portal is open - descend when ready"
	var boss_data: Dictionary = {}
	if boss_enemy != null and boss_enemy.alive:
		boss_data = {"name": str(boss_enemy.def["name"]), "ratio": boss_enemy.health / boss_enemy.max_health, "phase": boss_enemy.phase, "lag": boss_lag}
	var toast_data: Array = []
	for t in toasts:
		toast_data.append({"text": t["text"], "color": t["color"], "alpha": minf(float(t["life"]) / 0.6, 1.0)})
	var ant_cell: Vector2i = ant_sheet.get("cell", PLAYER_FRAME_SIZE)
	var ant_region := Rect2(Vector2(float((_ant_column() + 1) * ant_cell.x), 0.0), Vector2(ant_cell))
	var card_alpha := 0.0
	if floor_card_time > 0.0:
		card_alpha = minf(minf((2.8 - floor_card_time) / 0.4, floor_card_time / 0.6), 1.0)
	var dash_ratio := 1.0
	if dash_charges_cur < 1:
		dash_ratio = dash_recharge / maxf(GameState.dash_cooldown, 0.01)
	var portal_cell := Vector2(-1, -1)
	if portal_active:
		portal_cell = portal_position / float(TILE_SIZE)
	hud.update_state({
		"state": state,
		"time": torch_time,
		"health": player_health,
		"max_health": player_max_health,
		"health_lag": health_lag,
		"armor": player_armor,
		"armor_max": GameState.armor_max,
		"invuln": player_invulnerable,
		"low_health": player_health * 3 <= player_max_health and player_health > 0,
		"spit_ratio": 1.0 - clampf(spit_cd / maxf(GameState.spit_cooldown, 0.01), 0.0, 1.0),
		"bite_ratio": 1.0 - clampf(bite_cd / maxf(GameState.bite_cooldown, 0.01), 0.0, 1.0),
		"dash_ratio": dash_ratio,
		"dash_charges": dash_charges_cur,
		"dash_max": GameState.dash_charges,
		"spit_damage": GameState.spit_damage,
		"bite_damage": GameState.bite_damage,
		"crit_percent": int(GameState.crit_chance * 100.0),
		"speed": GameState.player_speed,
		"ant_texture": ant_sheet.get("texture"),
		"ant_region": ant_region,
		"floor_number": floor_number,
		"floor_name": str(floor_config.get("name", "")),
		"score": GameState.run_score,
		"combo": combo,
		"combo_ratio": clampf(combo_timer / COMBO_WINDOW, 0.0, 1.0),
		"combo_pop": combo_pop,
		"amber": GameState.run_amber,
		"kills": GameState.run_kills,
		"hurt_flash": hurt_flash,
		"death_progress": clampf(death_time / DEATH_ANIMATION_DURATION, 0.0, 1.0),
		"banner_title": banner_title,
		"banner_subtitle": banner_subtitle,
		"banner_tag": banner_tag,
		"banner_color": banner_color,
		"banner_alpha": banner_alpha,
		"room_name": room_name,
		"room_status_text": status_text,
		"room_active": active_room_index >= 0,
		"foes": enemies.size() + spawn_queue.size(),
		"rooms_cleared": cleared_count,
		"rooms_total": rooms.size(),
		"minimap": terrain.minimap_texture,
		"grid_size": AnthillGenerator.GRID_SIZE,
		"room_rects": room_rects,
		"room_status": status,
		"room_types": types,
		"player_cell": player_position / float(TILE_SIZE),
		"portal_cell": portal_cell,
		"boss": boss_data,
		"toasts": toast_data,
		"owned": _owned_upgrades(),
		"stats": _stat_lines(),
		"menu_index": menu_index,
		"pause_items": PAUSE_ITEMS,
		"end_items": END_ITEMS,
		"end_subtitle": end_subtitle,
		"summary": end_summary,
		"upgrades": upgrade_choices,
		"upgrade_title": upgrade_title,
		"upgrade_subtitle": upgrade_subtitle,
		"hint_alpha": 1.0 if hint_time > 0.0 else 0.0,
		"fade": fade,
		"floor_card_alpha": card_alpha,
		"floor_card_title": "FLOOR %d" % floor_number,
		"floor_card_name": str(floor_config.get("name", "")),
		"floor_card_sub": str(floor_config.get("subtitle", ""))
	})
