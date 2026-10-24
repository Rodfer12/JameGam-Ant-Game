extends Node2D

const ROOM_SIZE := Vector2(480.0, 270.0)
const SPRITE_CELL_SIZE := Vector2(90.0, 96.0)
const ANT_COLORS := [
	{"name": "BROWN", "column": 0},
	{"name": "RED", "column": 3},
	{"name": "GREEN", "column": 6},
	{"name": "GREY", "column": 9}
]

var ant_texture: Texture2D = preload("res://art/Ants.png")
var selected_ant := 0

func _ready() -> void:
	selected_ant = get_node("/root/GameState").selected_ant
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				selected_ant = 0
			KEY_2:
				selected_ant = 1
			KEY_3:
				selected_ant = 2
			KEY_4:
				selected_ant = 3
			KEY_ENTER, KEY_KP_ENTER:
				get_node("/root/GameState").selected_ant = selected_ant
				get_tree().change_scene_to_file("res://game.tscn")
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM_SIZE), Color("#17131c"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 48), "CHOOSE YOUR ANT", HORIZONTAL_ALIGNMENT_CENTER, 480, 22, Color("#f4d9ad"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 67), "Select a color for this run", HORIZONTAL_ALIGNMENT_CENTER, 480, 11, Color("#b99bbd"))
	for index in ANT_COLORS.size():
		var ant_color: Dictionary = ANT_COLORS[index]
		var center := Vector2(84.0 + index * 104.0, 125.0)
		if index == selected_ant:
			draw_rect(Rect2(center - Vector2(38, 36), Vector2(76, 78)), Color("#4d3650"), true)
			draw_rect(Rect2(center - Vector2(38, 36), Vector2(76, 78)), Color("#f4d9ad"), false, 2.0)
		_draw_sprite(center, ant_color["column"] + 1)
		draw_string(ThemeDB.fallback_font, center + Vector2(-9, 29), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f4d9ad"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-32, 47), ant_color["name"], HORIZONTAL_ALIGNMENT_CENTER, 64, 9, Color("#b99bbd"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 220), "Press 1-4 to choose", HORIZONTAL_ALIGNMENT_CENTER, 480, 12, Color("#f4d9ad"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 239), "Press ENTER to start", HORIZONTAL_ALIGNMENT_CENTER, 480, 10, Color("#b99bbd"))

func _draw_sprite(center: Vector2, column: int) -> void:
	var source := Rect2(Vector2(column, 0) * SPRITE_CELL_SIZE, SPRITE_CELL_SIZE)
	draw_texture_rect_region(ant_texture, Rect2(center - Vector2(32, 34), Vector2(64, 68)), source)
