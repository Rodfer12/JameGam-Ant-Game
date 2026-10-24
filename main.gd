@tool
extends Node2D

const ROOM_SIZE := Vector2(480.0, 270.0)
const ROOM_MARGIN := 18.0
const SPRITE_CELL_SIZE := Vector2(90.0, 96.0)
const PLAYER_SPEED := 125.0
const ENEMY_SPEED := 42.0
const ATTACK_RANGE := 34.0
const ATTACK_COOLDOWN := 0.35

const ANT_COLORS := [
	{"name": "BROWN", "column": 0},
	{"name": "RED", "column": 3},
	{"name": "GREEN", "column": 6},
	{"name": "GREY", "column": 9}
]

var ant_texture: Texture2D = preload("res://art/Ants.png")
var bug_texture: Texture2D = preload("res://art/Bugs.png")
var furniture_texture: Texture2D = preload("res://art/Top-Down_Retro_Interior/TopDownHouse_FurnitureState2.png")
var small_items_texture: Texture2D = preload("res://art/Top-Down_Retro_Interior/TopDownHouse_SmallItems.png")
var doors_texture: Texture2D = preload("res://art/Top-Down_Retro_Interior/TopDownHouse_DoorsAndWindows.png")
var player_position := Vector2(120.0, 135.0)
var enemy_position := Vector2(330.0, 135.0)
var player_health := 3
var enemy_health := 3
var selected_ant := 0
var attack_cooldown := 0.0
var attack_flash := 0.0
var enemy_flash := 0.0
var run_complete := false
var game_over := false
var choosing_ant := false
var last_move_direction := Vector2.RIGHT
var player_anim_time := 0.0
var enemy_anim_time := 0.0
var player_is_moving := false

func _ready() -> void:
	if not Engine.is_editor_hint():
		selected_ant = get_node("/root/GameState").selected_ant
	_populate_background_tile_map()
	queue_redraw()

func _populate_background_tile_map() -> void:
	var tile_map: TileMapLayer = $BackgroundTileMap
	var used_cells: Array[Vector2i] = tile_map.get_used_cells()
	if not used_cells.is_empty():
		var old_floor_pattern := true
		for cell in used_cells:
			if tile_map.get_cell_atlas_coords(cell) != Vector2i(0, 0):
				old_floor_pattern = false
				break
		if old_floor_pattern:
			tile_map.clear()
		else:
			return
	if not tile_map.get_used_cells().is_empty():
		return
	tile_map.position = Vector2.ZERO
	for x in range(30):
		for y in range(17):
			tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if choosing_ant:
		queue_redraw()
		return
	if game_over or run_complete:
		if Input.is_key_pressed(KEY_R):
			_restart()
		queue_redraw()
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	attack_flash = maxf(attack_flash - delta, 0.0)
	enemy_flash = maxf(enemy_flash - delta, 0.0)
	player_anim_time += delta
	enemy_anim_time += delta

	_move_player(delta)
	_move_enemy(delta)
	_check_exit()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_attack()
		elif event.keycode == KEY_R and (game_over or run_complete):
			_restart()

func _choose_ant(keycode: Key) -> void:
	var color_index := -1
	match keycode:
		KEY_1:
			color_index = 0
		KEY_2:
			color_index = 1
		KEY_3:
			color_index = 2
		KEY_4:
			color_index = 3
		KEY_ENTER, KEY_KP_ENTER:
			choosing_ant = false
	if color_index >= 0:
		selected_ant = color_index

func _move_player(delta: float) -> void:
	var movement := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	movement += Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	movement = movement.normalized()
	player_is_moving = movement != Vector2.ZERO
	if movement != Vector2.ZERO:
		last_move_direction = movement
		player_position += movement * PLAYER_SPEED * delta
	player_position.x = clampf(player_position.x, ROOM_MARGIN + 12.0, ROOM_SIZE.x - ROOM_MARGIN - 12.0)
	player_position.y = clampf(player_position.y, ROOM_MARGIN + 12.0, ROOM_SIZE.y - ROOM_MARGIN - 12.0)

func _move_enemy(delta: float) -> void:
	if enemy_health <= 0:
		return
	var direction := enemy_position.direction_to(player_position)
	enemy_position += direction * ENEMY_SPEED * delta
	if enemy_position.distance_to(player_position) < 19.0:
		player_health -= 1
		enemy_position = player_position + player_position.direction_to(enemy_position) * 24.0
		if player_health <= 0:
			game_over = true

func _attack() -> void:
	if attack_cooldown > 0.0 or enemy_health <= 0:
		return
	attack_cooldown = ATTACK_COOLDOWN
	attack_flash = 0.12
	if player_position.distance_to(enemy_position) <= ATTACK_RANGE:
		enemy_health -= 1
		enemy_flash = 0.12

func _check_exit() -> void:
	var exit_rect := Rect2(ROOM_SIZE.x - 42.0, ROOM_SIZE.y / 2.0 - 24.0, 24.0, 48.0)
	if enemy_health <= 0 and exit_rect.has_point(player_position):
		run_complete = true

func _restart() -> void:
	player_position = Vector2(120.0, 135.0)
	enemy_position = Vector2(330.0, 135.0)
	player_health = 3
	enemy_health = 3
	attack_cooldown = 0.0
	attack_flash = 0.0
	enemy_flash = 0.0
	run_complete = false
	game_over = false
	player_anim_time = 0.0
	enemy_anim_time = 0.0

func _draw() -> void:
	if choosing_ant:
		draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#17131c"))
		_draw_ant_selection()
		return
	_draw_room_background()
	_draw_floor_details()
	_draw_exit()
	_draw_enemy()
	_draw_player()
	_draw_hud()

func _draw_floor_details() -> void:
	for point in [Vector2(72, 62), Vector2(205, 210), Vector2(390, 75), Vector2(415, 210)]:
		draw_circle(point, 2.0, Color("#6d4534"))
		draw_line(point + Vector2(-6, 4), point + Vector2(6, -4), Color("#6d4534"), 1.0)

func _draw_room_background() -> void:
	draw_rect(Rect2(0.0, 0.0, ROOM_SIZE.x, ROOM_MARGIN), Color("#4d2d24"), true)
	draw_rect(Rect2(0.0, ROOM_SIZE.y - ROOM_MARGIN, ROOM_SIZE.x, ROOM_MARGIN), Color("#4d2d24"), true)
	draw_rect(Rect2(0.0, 0.0, ROOM_MARGIN, ROOM_SIZE.y), Color("#4d2d24"), true)
	draw_rect(Rect2(ROOM_SIZE.x - ROOM_MARGIN, 0.0, ROOM_MARGIN, ROOM_SIZE.y), Color("#4d2d24"), true)
	_draw_room_sprite(furniture_texture, Rect2(34.0, 34.0, 48.0, 48.0), Rect2(0.0, 0.0, 32.0, 32.0))
	_draw_room_sprite(furniture_texture, Rect2(398.0, 34.0, 48.0, 48.0), Rect2(64.0, 0.0, 32.0, 32.0))
	_draw_room_sprite(small_items_texture, Rect2(42.0, 199.0, 32.0, 32.0), Rect2(0.0, 0.0, 32.0, 32.0))
	_draw_room_sprite(doors_texture, Rect2(220.0, 18.0, 40.0, 24.0), Rect2(0.0, 0.0, 32.0, 48.0))

func _draw_room_sprite(texture: Texture2D, destination: Rect2, source: Rect2) -> void:
	draw_texture_rect_region(texture, destination, source)

func _draw_exit() -> void:
	var exit_rect := Rect2(ROOM_SIZE.x - 42.0, ROOM_SIZE.y / 2.0 - 24.0, 24.0, 48.0)
	var color := Color("#4caf72") if enemy_health <= 0 else Color("#62465e")
	draw_rect(exit_rect, color, true)
	draw_string(ThemeDB.fallback_font, Vector2(ROOM_SIZE.x - 39.0, ROOM_SIZE.y / 2.0 + 4.0), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d9f5c5"))

func _draw_player() -> void:
	var ant_color: Dictionary = ANT_COLORS[selected_ant]
	var frame := int(player_anim_time * 8.0) % 3 if player_is_moving else 1
	_draw_sprite(ant_texture, player_position, ant_color["column"] + frame, _direction_row(last_move_direction), Vector2(54.0, 58.0))
	if attack_flash > 0.0:
		draw_arc(player_position + last_move_direction * 16.0, ATTACK_RANGE, -1.0, 1.0, 16, Color("#f6c85f"), 3.0)

func _draw_enemy() -> void:
	if enemy_health <= 0:
		return
	var enemy_frame := int(enemy_anim_time * 7.0) % 3
	var enemy_direction := enemy_position.direction_to(player_position)
	_draw_sprite(bug_texture, enemy_position, 9 + enemy_frame, _direction_row(enemy_direction), Vector2(54.0, 58.0))
	if enemy_flash > 0.0:
		draw_circle(enemy_position, 17.0, Color(1.0, 0.9, 0.7, 0.25))

func _direction_row(direction: Vector2) -> int:
	if absf(direction.y) > absf(direction.x):
		return 0 if direction.y > 0.0 else 3
	return 1 if direction.x < 0.0 else 2

func _draw_sprite(texture: Texture2D, center: Vector2, column: int, row: int, size: Vector2) -> void:
	var source := Rect2(Vector2(column, row) * SPRITE_CELL_SIZE, SPRITE_CELL_SIZE)
	var destination := Rect2(center - size / 2.0, size)
	draw_texture_rect_region(texture, destination, source)

func _draw_hud() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(24, 38), "ANT HILL - FIRST CHAMBER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f4d9ad"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 58), "Move: arrows / WASD    Attack: SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#b99bbd"))
	draw_string(ThemeDB.fallback_font, Vector2(24, 248), "HEALTH " + str(player_health) + "/3    ENEMY " + str(maxi(enemy_health, 0)) + "/3", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f4d9ad"))
	if game_over:
		_draw_message("THE HILL CLAIMED YOU", "Press R to try again")
	elif run_complete:
		_draw_message("THE EXIT IS YOURS", "Press R to replay")
	elif enemy_health <= 0:
		draw_string(ThemeDB.fallback_font, Vector2(327, 246), "Reach the green exit", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#9ee7a5"))

func _draw_message(title: String, subtitle: String) -> void:
	draw_rect(Rect2(105, 96, 270, 78), Color("#17131c", 0.94), true)
	draw_rect(Rect2(105, 96, 270, 78), Color("#f4d9ad"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(0, 125), title, HORIZONTAL_ALIGNMENT_CENTER, 480, 17, Color("#f4d9ad"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 151), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 480, 11, Color("#b99bbd"))

func _draw_ant_selection() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#17131c"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 48), "CHOOSE YOUR ANT", HORIZONTAL_ALIGNMENT_CENTER, 480, 22, Color("#f4d9ad"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 67), "Select a color for this run", HORIZONTAL_ALIGNMENT_CENTER, 480, 11, Color("#b99bbd"))
	for index in ANT_COLORS.size():
		var ant_color: Dictionary = ANT_COLORS[index]
		var center := Vector2(84.0 + index * 104.0, 125.0)
		var selected := index == selected_ant
		if selected:
			draw_rect(Rect2(center - Vector2(38, 36), Vector2(76, 78)), Color("#4d3650"), true)
			draw_rect(Rect2(center - Vector2(38, 36), Vector2(76, 78)), Color("#f4d9ad"), false, 2.0)
		_draw_sprite(ant_texture, center, ant_color["column"] + 1, 0, Vector2(64.0, 68.0))
		draw_string(ThemeDB.fallback_font, center + Vector2(-9, 29), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f4d9ad"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-32, 47), ant_color["name"], HORIZONTAL_ALIGNMENT_CENTER, 64, 9, Color("#b99bbd"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 220), "Press 1-4 to choose", HORIZONTAL_ALIGNMENT_CENTER, 480, 12, Color("#f4d9ad"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 239), "Press ENTER to confirm", HORIZONTAL_ALIGNMENT_CENTER, 480, 10, Color("#b99bbd"))
