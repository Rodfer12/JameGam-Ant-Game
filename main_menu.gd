extends Node2D

const ROOM_SIZE := Vector2(480.0, 272.0)
const SPRITE_CELL_SIZE := Vector2(90.0, 96.0)
const ANT_COLORS := [
	{"name": "BROWN", "column": 0},
	{"name": "RED", "column": 3},
	{"name": "GREEN", "column": 6},
	{"name": "GREY", "column": 9}
]
const MENU_ITEMS := ["START GAME", "CREDITS"]

var ant_texture: Texture2D = preload("res://art/Ants.png")
var ant_hill_background: Texture2D = preload("res://art/silly_ant_hill.png")
var ui_click: AudioStream = preload("res://audio/kenney_ui-audio/Audio/click1.ogg")
var ui_confirm: AudioStream = preload("res://audio/kenney_ui-audio/Audio/switch1.ogg")
var selected_ant := 0
var menu_index := 0
var screen := "main"
var audio_player: AudioStreamPlayer
var menu_font: Font

func _ready() -> void:
	selected_ant = get_node("/root/GameState").selected_ant
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	menu_font = SystemFont.new()
	menu_font.font_names = PackedStringArray(["Segoe UI", "Trebuchet MS", "Arial"])
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if screen == "credits":
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
				screen = "main"
				_play_sound(ui_click)
			queue_redraw()
			return
		if screen == "ants":
			_handle_ant_input(event.keycode)
			queue_redraw()
			return
		match event.keycode:
			KEY_UP, KEY_W:
				menu_index = posmod(menu_index - 1, MENU_ITEMS.size())
				_play_sound(ui_click)
			KEY_DOWN, KEY_S:
				menu_index = posmod(menu_index + 1, MENU_ITEMS.size())
				_play_sound(ui_click)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_open_menu_item()
			KEY_ESCAPE:
				get_tree().quit()
		queue_redraw()

func _handle_ant_input(keycode: Key) -> void:
	match keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			selected_ant = keycode - KEY_1
			_play_sound(ui_click)
		KEY_ENTER, KEY_KP_ENTER:
			get_node("/root/GameState").selected_ant = selected_ant
			get_node("/root/GameState").demo_mode = false
			get_node("/root/GameState").reset_run()
			_play_sound(ui_confirm)
			get_tree().change_scene_to_file("res://game.tscn")
		KEY_ESCAPE:
			screen = "main"
			_play_sound(ui_click)

func _open_menu_item() -> void:
	match menu_index:
		0:
			screen = "ants"
			_play_sound(ui_confirm)
		1:
			screen = "credits"
			_play_sound(ui_confirm)

func _draw() -> void:
	_draw_ui_background()
	if screen == "credits":
		_draw_credits()
	elif screen == "ants":
		_draw_ant_selection()
	else:
		_draw_main_menu()

func _draw_main_menu() -> void:
	draw_string(menu_font, Vector2(0, 43), "SILLY ANT GAME", HORIZONTAL_ALIGNMENT_CENTER, 480, 27, Color("#fff0a6"))
	draw_string(menu_font, Vector2(0, 62), "This is rlly bad but I wanna make it better", HORIZONTAL_ALIGNMENT_CENTER, 480, 10, Color("#d7ffc0"))
	for index in MENU_ITEMS.size():
		var y := 128.0 + index * 29.0
		var selected := index == menu_index
		if selected:
			draw_rect(Rect2(145, y - 17, 190, 24), Color("#4d3650"), true)
			draw_string(menu_font, Vector2(0, y), "> " + MENU_ITEMS[index] + " <", HORIZONTAL_ALIGNMENT_CENTER, 480, 13, Color("#f4d9ad"))
		else:
			draw_string(menu_font, Vector2(0, y), MENU_ITEMS[index], HORIZONTAL_ALIGNMENT_CENTER, 480, 12, Color("#b99bbd"))
	draw_string(menu_font, Vector2(0, 238), "UP / DOWN select     ENTER confirm", HORIZONTAL_ALIGNMENT_CENTER, 480, 10, Color("#f4d9ad"))
	draw_string(menu_font, Vector2(0, 253), "I have absolutely 0 experience in game making lmao", HORIZONTAL_ALIGNMENT_CENTER, 480, 9, Color("#d7ffc0"))

func _draw_ant_selection() -> void:
	draw_string(menu_font, Vector2(0, 42), " PICK YOUR ANT", HORIZONTAL_ALIGNMENT_CENTER, 480, 19, Color("#fff0a6"))
	draw_string(menu_font, Vector2(0, 61), "in a later version they'll have attributes. Idrk how to do that rn. I'm new to this.", HORIZONTAL_ALIGNMENT_CENTER, 480, 10, Color("#d7ffc0"))
	for index in ANT_COLORS.size():
		var ant_color: Dictionary = ANT_COLORS[index]
		var center := Vector2(84.0 + index * 104.0, 124.0)
		if index == selected_ant:
			draw_rect(Rect2(center - Vector2(38, 36), Vector2(76, 78)), Color("#4d3650"), true)
			draw_rect(Rect2(center - Vector2(38, 36), Vector2(76, 78)), Color("#f4d9ad"), false, 2.0)
		_draw_sprite(center, ant_color["column"] + 1)
		draw_string(menu_font, center + Vector2(-9, 29), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f4d9ad"))
		draw_string(menu_font, center + Vector2(-32, 53), ant_color["name"], HORIZONTAL_ALIGNMENT_CENTER, 64, 9, Color("#b99bbd"))
	draw_string(menu_font, Vector2(0, 222), "1-4 choose     ENTER unleash the ant", HORIZONTAL_ALIGNMENT_CENTER, 480, 10, Color("#fff0a6"))
	draw_string(menu_font, Vector2(0, 241), "ESC = chicken out and go back", HORIZONTAL_ALIGNMENT_CENTER, 480, 9, Color("#d7ffc0"))

func _draw_credits() -> void:
	draw_string(menu_font, Vector2(0, 35), "CREDITS", HORIZONTAL_ALIGNMENT_CENTER, 480, 22, Color("#f4d9ad"))
	var lines := [
		"SILLY ANT GAME // CREDITS FOR THE TINY LEGENDS",
		"",
		"ART",
		"Ants and bug Pixelart: shandsparil (itch.io)",
		"Ant hill background: user-provided image",
		"Cave tiles: GrafxKid (CC0)",
		"Roguelike dungeon art: Kenney (CC0)",
		"",
		"AUDIO",
		"RPG Audio and UI Audio: Kenney (CC0)",
		"",
		"VFX",
		"Particle Pack: Kenney (CC0)",
		"",
		"Development note: I had no prior Godot",
		"or game-coding experience. Tutorials and",
		"generative AI helped me learn and develop.",
		"",
		"ESC / BACKSPACE  return to menu"
	]
	for index in lines.size():
		var color := Color("#f4d9ad") if index == 0 or lines[index] in ["ART", "AUDIO", "VFX"] else Color("#b99bbd")
		draw_string(menu_font, Vector2(0, 59 + index * 11), lines[index], HORIZONTAL_ALIGNMENT_CENTER, 480, 9, color)

func _draw_ui_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#263c2c"))
	draw_texture_rect(ant_hill_background, Rect2(0, 22, ROOM_SIZE.x, 240), false, Color(1.0, 1.0, 1.0, 0.62))
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#17131c", 0.48))

func _draw_sprite(center: Vector2, column: int) -> void:
	var source := Rect2(Vector2(column, 0) * SPRITE_CELL_SIZE, SPRITE_CELL_SIZE)
	var ant_size := Vector2(25.6, 27.2)
	draw_texture_rect_region(ant_texture, Rect2(center - ant_size / 2.0, ant_size), source)

func _play_sound(stream: AudioStream) -> void:
	audio_player.stream = stream
	audio_player.play()
