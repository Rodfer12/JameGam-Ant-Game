extends Node2D

const ROOM_SIZE := Vector2(480.0, 272.0)
const SPRITE_CELL_SIZE := Vector2i(90, 96)
const MENU_ANT_SIZE := Vector2i(45, 48)
const MENU_ITEMS: Array[String] = ["START GAME", "COLONY HALL", "CREDITS"]

var ant_sheet: Dictionary = {}
var ant_hill_background: Texture2D
var ui_click: AudioStream
var ui_confirm: AudioStream
var selected_ant := 0
var menu_index := 0
var hall_index := 0
var screen := "main"
var message := ""
var message_time := 0.0
var message_color := Color("#ff8a8a")
var audio_player: AudioStreamPlayer
var time := 0.0


func _load_asset(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	selected_ant = GameState.selected_ant
	ant_sheet = SpriteSheetUtil.smooth_sheet(_load_asset("res://art/Ants.png") as Texture2D, SPRITE_CELL_SIZE, MENU_ANT_SIZE)
	ant_hill_background = _load_asset("res://art/silly_ant_hill.png") as Texture2D
	ui_click = _load_asset("res://audio/kenney_ui-audio/Audio/click1.ogg") as AudioStream
	ui_confirm = _load_asset("res://audio/kenney_ui-audio/Audio/switch1.ogg") as AudioStream
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)


func _process(delta: float) -> void:
	time += delta
	message_time = maxf(message_time - delta, 0.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var key := key_event.keycode
	match screen:
		"credits":
			if key == KEY_ESCAPE or key == KEY_BACKSPACE:
				screen = "main"
				_play_sound(ui_click)
		"ants":
			_handle_ant_input(key)
		"hall":
			_handle_hall_input(key)
		_:
			_handle_main_input(key)


func _handle_main_input(key: Key) -> void:
	match key:
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


func _handle_ant_input(key: Key) -> void:
	match key:
		KEY_1, KEY_2, KEY_3, KEY_4:
			selected_ant = key - KEY_1
			_play_sound(ui_click)
		KEY_LEFT, KEY_A:
			selected_ant = posmod(selected_ant - 1, GameData.ANTS.size())
			_play_sound(ui_click)
		KEY_RIGHT, KEY_D:
			selected_ant = posmod(selected_ant + 1, GameData.ANTS.size())
			_play_sound(ui_click)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			GameState.selected_ant = selected_ant
			GameState.demo_mode = false
			GameState.save_game()
			GameState.reset_run()
			_play_sound(ui_confirm)
			get_tree().change_scene_to_file("res://game.tscn")
		KEY_ESCAPE:
			screen = "main"
			_play_sound(ui_click)


func _handle_hall_input(key: Key) -> void:
	var count := GameData.META.size()
	match key:
		KEY_UP, KEY_W:
			hall_index = posmod(hall_index - 1, count)
			_play_sound(ui_click)
		KEY_DOWN, KEY_S:
			hall_index = posmod(hall_index + 1, count)
			_play_sound(ui_click)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var entry: Dictionary = GameData.META[hall_index]
			var level := GameState.meta_level(str(entry["id"]))
			if level >= int(entry["max"]):
				_set_message("ALREADY MAXED", Color("#ffd35c"))
			elif GameState.buy_meta(str(entry["id"])):
				_set_message("UPGRADED!", Color("#8bf08b"))
				_play_sound(ui_confirm)
			else:
				_set_message("NOT ENOUGH AMBER", Color("#ff8a8a"))
		KEY_ESCAPE, KEY_BACKSPACE:
			screen = "main"
			_play_sound(ui_click)


func _set_message(text: String, color: Color) -> void:
	message = text
	message_color = color
	message_time = 1.6


func _open_menu_item() -> void:
	match menu_index:
		0:
			screen = "ants"
			_play_sound(ui_confirm)
		1:
			screen = "hall"
			_play_sound(ui_confirm)
		2:
			screen = "credits"
			_play_sound(ui_confirm)


func _text(s: String, at: Vector2, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, width: float = 480.0) -> void:
	UiKit.text(self, s, at, size, color, align, width)


func _draw() -> void:
	_draw_ui_background()
	match screen:
		"credits":
			_draw_credits()
		"ants":
			_draw_ant_selection()
		"hall":
			_draw_hall()
		_:
			_draw_main_menu()


# --- Main menu --------------------------------------------------------------------------------------

func _draw_main_menu() -> void:
	_draw_title_emblem(Vector2(240, 32 + sin(time * 2.0) * 2.0))
	_text("SILLY ANT GAME", Vector2(0, 68), 25, Color("#fff0a6"))
	_text("A tiny adventure beneath the garden", Vector2(0, 84), 10, Color("#d7ffc0"))
	draw_line(Vector2(130, 94), Vector2(350, 94), Color("#f4d9ad", 0.45), 1.0)
	for index in MENU_ITEMS.size():
		var y := 124.0 + float(index) * 28.0
		if index == menu_index:
			UiKit.panel(self, Rect2(142, y - 17, 196, 24), Color("#4d3650", 0.95), Color("#f4d9ad", 0.8))
			_text(">  " + MENU_ITEMS[index] + "  <", Vector2(0, y), 12, Color("#fff0c2"))
		else:
			_text(MENU_ITEMS[index], Vector2(0, y), 11, Color("#c7accb"))
	var stats := Rect2(92, 208, 296, 24)
	UiKit.panel(self, stats, Color(0.08, 0.06, 0.11, 0.8))
	var line := "AMBER %d     BEST FLOOR %d/%d     RUNS %d     WINS %d" % [GameState.amber, GameState.best_floor, GameData.FLOORS.size(), GameState.total_runs, GameState.total_wins]
	_text(line, Vector2(stats.position.x, stats.position.y + 15.0), 8, Color("#ffc247"), HORIZONTAL_ALIGNMENT_CENTER, stats.size.x)
	_text("UP / DOWN  select       ENTER  confirm", Vector2(0, 250), 9, Color("#f4d9ad"))
	_text("Clear six floors of the anthill. Survive the Queen.", Vector2(0, 262), 8, Color("#d7ffc0"))


# --- Ant selection --------------------------------------------------------------------------------------

func _draw_ant_selection() -> void:
	_text("CHOOSE YOUR ANT", Vector2(0, 40), 19, Color("#fff0a6"))
	_text("Each ant plays differently. Pick one and dive in.", Vector2(0, 55), 9, Color("#d7ffc0"))
	var count := GameData.ANTS.size()
	var card_w := 98.0
	var gap := 8.0
	var total := card_w * float(count) + gap * float(count - 1)
	for index in count:
		var ant: Dictionary = GameData.ANTS[index]
		var card := Rect2(Vector2(240.0 - total * 0.5 + float(index) * (card_w + gap), 66.0), Vector2(card_w, 86.0))
		var chosen := index == selected_ant
		if chosen:
			UiKit.panel(self, card, Color("#4d3650", 0.97), Color("#f4d9ad"), Color("#f4d9ad"))
		else:
			UiKit.panel(self, card, Color("#241c2d", 0.9), UiKit.BORDER)
		var center := card.position + Vector2(card_w * 0.5, 40.0)
		var bob := sin(time * 5.0) * 2.0 if chosen else 0.0
		var frame := int(time * 6.0) % 3 if chosen else 1
		_draw_ant(center + Vector2(0, bob), int(ant["column"]) + frame)
		_text(str(index + 1), card.position + Vector2(6, 14), 10, Color("#f4d9ad"), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		_text(str(ant["name"]), card.position + Vector2(0, 72), 9, Color("#fff0c2") if chosen else Color("#b99bbd"), HORIZONTAL_ALIGNMENT_CENTER, card_w)
		_text(str(ant["title"]), card.position + Vector2(0, 82), 7, Color("#d7ffc0", 0.9 if chosen else 0.55), HORIZONTAL_ALIGNMENT_CENTER, card_w)
	var info := Rect2(36, 160, 408, 62)
	var current: Dictionary = GameData.ANTS[selected_ant]
	UiKit.panel(self, info, Color(0.1, 0.07, 0.14, 0.92), UiKit.BORDER, Color("#f4d9ad", 0.8))
	_text("%s  -  %s" % [str(current["name"]), str(current["title"])], info.position + Vector2(10, 16), 10, Color("#fff0a6"), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	UiKit.paragraph(self, str(current["desc"]), info.position + Vector2(10, 28), 8, Color("#d7c8b2"), info.size.x - 20.0, 10.0)
	var perks: Array = current["perks"]
	var x := info.position.x + 10.0
	for perk in perks:
		var s := str(perk)
		var good := s.begins_with("+")
		var width := UiKit.text_width(s, 7) + 10.0
		var chip := Rect2(x, info.position.y + 42.0, width, 13.0)
		draw_rect(chip, Color("#2d5a3a", 0.9) if good else Color("#5a2d3a", 0.9))
		draw_rect(chip, Color("#8bf08b", 0.7) if good else Color("#ff8a8a", 0.7), false, 1.0)
		_text(s, chip.position + Vector2(5, 9.5), 7, Color("#e9ffe9") if good else Color("#ffe9e9"), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		x += width + 6.0
	_text("1-4 / LEFT RIGHT  choose        ENTER  unleash", Vector2(0, 240), 10, Color("#fff0a6"))
	_text("ESC  return to menu", Vector2(0, 256), 9, Color("#d7ffc0"))


# --- Colony Hall -----------------------------------------------------------------------------------------

func _draw_hall() -> void:
	_text("COLONY HALL", Vector2(0, 34), 20, Color("#fff0a6"))
	_text("Spend amber to strengthen every future run.", Vector2(0, 48), 9, Color("#d7ffc0"))
	var amber_box := Rect2(360, 18, 100, 22)
	UiKit.panel(self, amber_box, Color(0.08, 0.06, 0.11, 0.9))
	UiKit.icon(self, "amber", amber_box.position + Vector2(12, 11), 5.0, Color("#ffc247"))
	_text(str(GameState.amber), amber_box.position + Vector2(22, 15), 10, Color("#ffc247"), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
	for index in GameData.META.size():
		var entry: Dictionary = GameData.META[index]
		var level := GameState.meta_level(str(entry["id"]))
		var max_level := int(entry["max"])
		var row := Rect2(40, 58.0 + float(index) * 24.0, 400, 22)
		var chosen := index == hall_index
		UiKit.panel(self, row, Color("#4d3650", 0.95) if chosen else Color("#241c2d", 0.88), Color("#f4d9ad", 0.85) if chosen else UiKit.BORDER)
		UiKit.icon(self, str(entry["glyph"]), row.position + Vector2(14, 11), 6.0, Color("#fff0a6") if chosen else Color("#b99bbd"))
		_text(str(entry["name"]), row.position + Vector2(30, 10), 8, Color("#fff0c2") if chosen else Color("#c7accb"), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		_text(str(entry["desc"]), row.position + Vector2(30, 19), 6, Color("#a99bb0"), HORIZONTAL_ALIGNMENT_LEFT, -1.0)
		for pip in max_level:
			var pip_rect := Rect2(row.position + Vector2(250.0 + float(pip) * 8.0, 8.0), Vector2(6, 6))
			draw_rect(pip_rect, Color("#ffd35c") if pip < level else Color("#3a2f45"))
		var cost_text := "MAX"
		var cost_color := Color("#8bf08b")
		if level < max_level:
			var cost := GameState.meta_cost(entry)
			cost_text = str(cost)
			cost_color = Color("#ffc247") if GameState.amber >= cost else Color("#a06070")
		_text(cost_text, row.position + Vector2(row.size.x - 70.0, 14.0), 9, cost_color, HORIZONTAL_ALIGNMENT_RIGHT, 62.0)
	if message_time > 0.0:
		_text(message, Vector2(0, 236), 10, Color(message_color, clampf(message_time / 0.4, 0.0, 1.0)))
	_text("UP / DOWN  select       ENTER  buy       ESC  back", Vector2(0, 256), 9, Color("#f4d9ad"))


# --- Credits ------------------------------------------------------------------------------------------------

func _draw_credits() -> void:
	_text("CREDITS", Vector2(0, 35), 22, Color("#f4d9ad"))
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
		_text(lines[index], Vector2(0, 59 + index * 11), 9, color)


func _draw_ui_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#263c2c"))
	if ant_hill_background != null:
		draw_texture_rect(ant_hill_background, Rect2(0, 22, ROOM_SIZE.x, 240), false, Color(1.0, 1.0, 1.0, 0.62))
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#17131c", 0.5))
	draw_rect(Rect2(10, 10, 460, 252), Color("#f4d9ad", 0.16), false, 2.0)
	for i in 14:
		var seed_x := fmod(float(i) * 97.0 + time * (4.0 + float(i % 3)), ROOM_SIZE.x)
		var seed_y := fmod(float(i) * 53.0 - time * (6.0 + float(i % 4)) + 272.0 * 4.0, ROOM_SIZE.y)
		draw_circle(Vector2(seed_x, seed_y), 1.0 + float(i % 2), Color("#fff0a6", 0.35))


func _draw_title_emblem(center: Vector2) -> void:
	draw_circle(center, 16.0, Color("#4d3650", 0.9))
	draw_arc(center, 16.0, 0.0, TAU, 24, Color("#f4d9ad", 0.75), 1.0)
	draw_circle(center + Vector2(-5, -2), 3.0, Color("#8bf08b"))
	draw_circle(center + Vector2(5, -2), 3.0, Color("#8bf08b"))
	draw_line(center + Vector2(-8, 8), center + Vector2(8, 8), Color("#fff0c2"), 2.0)


func _draw_ant(center: Vector2, column: int) -> void:
	var texture: Texture2D = ant_sheet.get("texture")
	if texture == null:
		return
	var cell: Vector2i = ant_sheet["cell"]
	var safe_column := clampi(column, 0, int(ant_sheet["columns"]) - 1)
	var source := Rect2(Vector2(safe_column * cell.x, 0), Vector2(cell))
	draw_texture_rect_region(texture, Rect2((center - Vector2(cell) / 2.0).round(), Vector2(cell)), source)


func _play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	audio_player.stream = stream
	audio_player.play()
