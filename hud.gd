class_name Hud
extends CanvasLayer

## Screen-fixed HUD and menus on their own CanvasLayer (never jitters with the
## camera). main.gd pushes a fresh state dictionary every frame; everything here
## is drawn from that data, so the HUD holds no game logic of its own.

# Must match the State enum in main.gd.
const MODE_PLAYING := 0
const MODE_UPGRADE := 1
const MODE_PAUSED := 2
const MODE_DYING := 3
const MODE_GAME_OVER := 4
const MODE_VICTORY := 5
const MODE_TRANSITION := 6

const SPIT_COLOR := Color("#8bf08b")
const BITE_COLOR := Color("#ffb84d")
const DASH_COLOR := Color("#7cc8ff")
const AMBER_COLOR := Color("#ffc247")

var data: Dictionary = {}
var canvas: Control


func _ready() -> void:
	layer = 10
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_canvas)
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func update_state(new_data: Dictionary) -> void:
	data = new_data
	if canvas != null:
		canvas.queue_redraw()


func _t(s: String, at: Vector2, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	UiKit.text(canvas, s, at, size, color, align, width)


## Right-aligned text whose right edge sits at right_x.
func _tr(s: String, right_x: float, y: float, size: int, color: Color) -> void:
	UiKit.text(canvas, s, Vector2(right_x - UiKit.text_width(s, size), y), size, color)


func _num(key: String, fallback: float = 0.0) -> float:
	return float(data.get(key, fallback))


func _draw_canvas() -> void:
	if data.is_empty():
		return
	var view := canvas.size
	var mode := int(data.get("state", 0))
	_draw_low_health(view)
	_draw_hurt_flash(view)
	_draw_player_panel()
	_draw_upgrade_chips()
	_draw_top_center(view)
	_draw_minimap(view)
	_draw_progress(view)
	_draw_bottom(view)
	_draw_boss_bar(view)
	_draw_toasts(view)
	_draw_banner(view)
	_draw_hints(view)
	match mode:
		MODE_UPGRADE:
			_draw_upgrade_menu(view)
		MODE_PAUSED:
			_draw_pause(view)
		MODE_DYING:
			canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.4, 0.02, 0.08, 0.55 * _num("death_progress")))
		MODE_GAME_OVER:
			_draw_end(view, "COLONY LOST", str(data.get("end_subtitle", "THE GUARD REACHED YOUR NEST")), Color("#d85b7d"))
		MODE_VICTORY:
			_draw_end(view, "THE QUEEN FALLS", "THE COLONY IS SAVED", Color("#f6c85f"))
	_draw_floor_card(view)
	var fade := _num("fade")
	if fade > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.01, 0.04, clampf(fade, 0.0, 1.0)))


# --- Screen effects -------------------------------------------------------------------------

func _draw_hurt_flash(view: Vector2) -> void:
	var amount := _num("hurt_flash")
	if amount <= 0.0:
		return
	var color := Color(1.0, 0.1, 0.15, amount * 0.45)
	var thickness := 26.0
	canvas.draw_rect(Rect2(0, 0, view.x, thickness), color)
	canvas.draw_rect(Rect2(0, view.y - thickness, view.x, thickness), color)
	canvas.draw_rect(Rect2(0, 0, thickness, view.y), color)
	canvas.draw_rect(Rect2(view.x - thickness, 0, thickness, view.y), color)


func _draw_low_health(view: Vector2) -> void:
	if not bool(data.get("low_health", false)) or int(data.get("state", 0)) != MODE_PLAYING:
		return
	var pulse := 0.5 + 0.5 * sin(_num("time") * 5.0)
	var color := Color(0.9, 0.05, 0.12, 0.10 + 0.14 * pulse)
	var t := 14.0
	canvas.draw_rect(Rect2(0, 0, view.x, t), color)
	canvas.draw_rect(Rect2(0, view.y - t, view.x, t), color)
	canvas.draw_rect(Rect2(0, 0, t, view.y), color)
	canvas.draw_rect(Rect2(view.x - t, 0, t, view.y), color)


# --- Player panel ------------------------------------------------------------------------------

func _draw_player_panel() -> void:
	var panel := Rect2(6, 6, 160, 58)
	UiKit.panel(canvas, panel, UiKit.PANEL, UiKit.BORDER, Color("#ff5d73", 0.8))
	var portrait := Rect2(10, 10, 28, 28)
	UiKit.panel(canvas, portrait, UiKit.PANEL_LIGHT, UiKit.BORDER)
	var tex: Texture2D = data.get("ant_texture")
	if tex != null:
		var region: Rect2 = data.get("ant_region", Rect2())
		if region.size.x > 0.0:
			var at := (portrait.get_center() - region.size * 0.5).round()
			var blink := _num("invuln") > 0.0 and int(_num("time") * 14.0) % 2 == 0
			canvas.draw_texture_rect_region(tex, Rect2(at, region.size), region, Color(1, 1, 1, 0.45 if blink else 1.0))

	var hp := int(data.get("health", 1))
	var max_hp := maxi(1, int(data.get("max_health", 1)))
	var ratio := float(hp) / float(max_hp)
	var bar_rect := Rect2(44, 12, 116, 11)
	var low := ratio <= 0.34
	UiKit.bar(canvas, bar_rect, ratio, Color("#ff3b52") if low else UiKit.RED, Color(0.07, 0.05, 0.1, 0.92), max_hp if max_hp <= 24 else 0, _num("health_lag", ratio))
	_t("%d / %d" % [hp, max_hp], Vector2(bar_rect.position.x, 21.0), 8, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, bar_rect.size.x)

	var armor_max := int(data.get("armor_max", 0))
	if armor_max > 0:
		var armor := int(data.get("armor", 0))
		UiKit.bar(canvas, Rect2(44, 26, 116, 5), float(armor) / float(armor_max), UiKit.BLUE, Color(0.07, 0.05, 0.1, 0.92), armor_max if armor_max <= 16 else 0)
		_tr(str(armor), 41.0, 31.0, 6, UiKit.BLUE)

	UiKit.ability_slot(canvas, Rect2(10, 41, 18, 18), "drop", _num("spit_ratio", 1.0), "SPC", SPIT_COLOR)
	UiKit.ability_slot(canvas, Rect2(32, 41, 18, 18), "bite", _num("bite_ratio", 1.0), "K", BITE_COLOR)
	var dash_max := int(data.get("dash_max", 1))
	UiKit.ability_slot(canvas, Rect2(54, 41, 18, 18), "dash", _num("dash_ratio", 1.0), "SHF", DASH_COLOR, int(data.get("dash_charges", 1)) if dash_max > 1 else -1)
	_t("SPIT %d   BITE %d" % [int(data.get("spit_damage", 0)), int(data.get("bite_damage", 0))], Vector2(82, 49), 7, UiKit.MUTED)
	_t("CRIT %d%%   SPD %d" % [int(data.get("crit_percent", 0)), int(data.get("speed", 0))], Vector2(82, 58), 7, UiKit.MUTED)


func _draw_upgrade_chips() -> void:
	var owned: Array = data.get("owned", [])
	if owned.is_empty():
		return
	var origin := Vector2(6, 69)
	var per_row := 13
	for i in mini(owned.size(), per_row * 2):
		var entry: Dictionary = owned[i]
		var rect := Rect2(origin + Vector2(float(i % per_row) * 12.0, floorf(float(i) / float(per_row)) * 12.0), Vector2(11, 11))
		var accent := UiKit.rarity_color(int(entry.get("rarity", 0)))
		canvas.draw_rect(rect, Color(0.08, 0.06, 0.11, 0.92))
		canvas.draw_rect(rect, accent.darkened(0.2), false, 1.0)
		UiKit.icon(canvas, str(entry.get("glyph", "")), rect.get_center(), 3.3, accent)
		var level := int(entry.get("level", 1))
		if level > 1:
			_t(str(level), rect.position + Vector2(8.5, 11.0), 6, UiKit.YELLOW)


# --- Top center -------------------------------------------------------------------------------------

func _draw_top_center(view: Vector2) -> void:
	var panel := Rect2(view.x * 0.5 - 80.0, 6, 160, 34)
	UiKit.panel(canvas, panel)
	var floor_text := "FLOOR %d  -  %s" % [int(data.get("floor_number", 1)), str(data.get("floor_name", ""))]
	_t(floor_text, Vector2(panel.position.x, 17), 7, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_t("SCORE  %s" % _group(int(data.get("score", 0))), Vector2(panel.position.x, 31), 9, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	var combo := int(data.get("combo", 0))
	if combo >= 2:
		var tier := Color("#fff0a6")
		if combo >= 25:
			tier = Color("#ff6b4a")
		elif combo >= 10:
			tier = Color("#ffb84d")
		var pop := 1.0 + 0.25 * _num("combo_pop")
		_t("x%d" % combo, Vector2(panel.position.x, 58), int(15.0 * pop), tier, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_t("COMBO", Vector2(panel.position.x, 67), 6, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		UiKit.bar(canvas, Rect2(view.x * 0.5 - 35.0, 70, 70, 3), _num("combo_ratio"), tier)


func _group(value: int) -> String:
	var s := str(value)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


# --- Minimap + resources ----------------------------------------------------------------------------

func _draw_minimap(view: Vector2) -> void:
	var texture: Texture2D = data.get("minimap")
	var grid: Vector2i = data.get("grid_size", Vector2i(96, 64))
	var panel := Rect2(view.x - float(grid.x) - 14.0, 6.0, float(grid.x) + 8.0, float(grid.y) + 8.0)
	UiKit.panel(canvas, panel)
	var origin := panel.position + Vector2(4, 4)
	if texture != null:
		canvas.draw_texture(texture, origin, Color(1, 1, 1, 0.38))
	var rects: Array = data.get("room_rects", [])
	var status: PackedInt32Array = data.get("room_status", PackedInt32Array())
	var types: PackedInt32Array = data.get("room_types", PackedInt32Array())
	for i in rects.size():
		var rect: Rect2i = rects[i]
		var code := status[i] if i < status.size() else 0
		var color := Color("#7d7488", 0.35)
		var fill := Color(0, 0, 0, 0)
		match code:
			1:
				color = Color("#6fdc84", 0.95)
				fill = Color("#6fdc84", 0.22)
			2:
				color = Color("#ffd35c", 1.0)
				fill = Color("#ffd35c", 0.25)
			3:
				color = Color("#b9a3d9", 0.8)
		var r := Rect2(origin + Vector2(rect.position), Vector2(rect.size))
		if fill.a > 0.0:
			canvas.draw_rect(r, fill)
		canvas.draw_rect(r, color, false, 1.0)
		var type := types[i] if i < types.size() else 1
		var seen := code != 0 or type == GameData.ROOM_BOSS
		if seen and code != 1:
			var mark := Color(0, 0, 0, 0)
			if type == GameData.ROOM_BOSS:
				mark = Color("#ff5d73")
			elif type == GameData.ROOM_TREASURE:
				mark = Color("#ffc247")
			elif type == GameData.ROOM_REST:
				mark = Color("#6fe0ff")
			elif type == GameData.ROOM_ELITE:
				mark = Color("#ff9a4a")
			if mark.a > 0.0:
				canvas.draw_rect(Rect2(r.get_center() - Vector2(2, 2), Vector2(4, 4)), mark)
	var portal: Vector2 = data.get("portal_cell", Vector2(-1, -1))
	if portal.x >= 0.0:
		var pulse := 2.0 + sin(_num("time") * 6.0)
		canvas.draw_circle(origin + portal, pulse + 1.0, Color("#c58cff"))
	var player_cell: Vector2 = data.get("player_cell", Vector2.ZERO)
	var blink := 0.6 + 0.4 * sin(_num("time") * 8.0)
	canvas.draw_circle(origin + player_cell, 2.4, Color(1.0, 1.0, 1.0, blink))
	canvas.draw_circle(origin + player_cell, 1.3, Color("#ff5d73"))

	var y := panel.end.y + 11.0
	var amber_text := "%d" % int(data.get("amber", 0))
	_tr(amber_text, panel.end.x - 12.0, y, 8, AMBER_COLOR)
	UiKit.icon(canvas, "amber", Vector2(panel.end.x - 6.0, y - 3.0), 4.0, AMBER_COLOR)
	_t("KILLS  %d" % int(data.get("kills", 0)), Vector2(panel.position.x, y), 7, UiKit.MUTED)


func _draw_progress(view: Vector2) -> void:
	var status: PackedInt32Array = data.get("room_status", PackedInt32Array())
	var count := status.size()
	if count == 0:
		return
	var origin := Vector2(8, view.y - 12)
	_t("ROOMS  %d / %d" % [int(data.get("rooms_cleared", 0)), int(data.get("rooms_total", count))], origin + Vector2(0, -4), 7, UiKit.MUTED)
	for i in count:
		var color := Color("#3a2f45")
		match status[i]:
			1:
				color = Color("#6fdc84")
			2:
				color = Color("#ffd35c")
			3:
				color = Color("#8d78b0")
		canvas.draw_rect(Rect2(origin + Vector2(float(i) * 7.0, 0), Vector2(5, 5)), color)


# --- Bottom -----------------------------------------------------------------------------------------

func _draw_bottom(view: Vector2) -> void:
	var y := view.y - 8.0
	if bool(data.get("room_active", false)):
		var foes := int(data.get("foes", 0))
		_t("FOES LEFT  %d" % foes, Vector2(0, y), 9, Color("#ffb4a0"), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	else:
		_t(str(data.get("room_status_text", "")), Vector2(0, y), 8, Color("#9ee7a5"), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_t(str(data.get("room_name", "")), Vector2(0, y - 12.0), 8, Color("#fff0a6", 0.9), HORIZONTAL_ALIGNMENT_CENTER, view.x)


func _draw_boss_bar(view: Vector2) -> void:
	var boss: Dictionary = data.get("boss", {})
	if boss.is_empty():
		return
	var width := 240.0
	var rect := Rect2(view.x * 0.5 - width * 0.5, view.y - 50.0, width, 9.0)
	var ratio := float(boss.get("ratio", 1.0))
	var phase := int(boss.get("phase", 0))
	var pulse := 0.5 + 0.5 * sin(_num("time") * 6.0)
	var fill := Color("#ff4d6a").lerp(Color("#ff9a4a"), 0.0 if phase == 0 else 0.5 + 0.5 * pulse * float(phase) / 2.0)
	UiKit.panel(canvas, rect.grow(4.0), Color(0.06, 0.04, 0.09, 0.88), UiKit.BORDER)
	UiKit.bar(canvas, rect, ratio, fill, Color(0.1, 0.05, 0.08, 0.95), 3, float(boss.get("lag", ratio)))
	_t(str(boss.get("name", "")), Vector2(rect.position.x, rect.position.y - 7.0), 9, Color("#ffd9d9"), HORIZONTAL_ALIGNMENT_CENTER, width)
	for i in 3:
		var lit := i <= phase
		canvas.draw_rect(Rect2(rect.end.x + 8.0 + float(i) * 6.0, rect.position.y + 2.0, 4, 5), Color("#ff9a4a") if lit else Color("#3a2f45"))


func _draw_toasts(view: Vector2) -> void:
	var toasts: Array = data.get("toasts", [])
	var y := 104.0
	for toast in toasts:
		var entry: Dictionary = toast
		var color: Color = entry.get("color", UiKit.CREAM)
		color.a = clampf(float(entry.get("alpha", 1.0)), 0.0, 1.0)
		_t(str(entry.get("text", "")), Vector2(view.x - 214.0, y), 8, color, HORIZONTAL_ALIGNMENT_RIGHT, 206.0)
		y += 11.0


func _draw_banner(view: Vector2) -> void:
	var alpha := clampf(_num("banner_alpha"), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var accent: Color = data.get("banner_color", Color("#fff0a6"))
	var cx := view.x * 0.5
	var tag := str(data.get("banner_tag", ""))
	if tag != "":
		_t(tag, Vector2(0, 92), 7, Color("#ff8a8a", alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_t(str(data.get("banner_title", "")), Vector2(0, 110), 18, Color(accent, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_t(str(data.get("banner_subtitle", "")), Vector2(0, 124), 8, Color("#d7ffc0", alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var spread := 80.0 + 40.0 * alpha
	canvas.draw_line(Vector2(cx - spread, 130), Vector2(cx + spread, 130), Color(accent, alpha * 0.55), 1.0)


func _draw_hints(view: Vector2) -> void:
	if _num("hint_alpha") <= 0.05:
		return
	var entries: Array = [["WASD", "MOVE"], ["SPACE / LMB", "SPIT"], ["K / RMB", "BITE"], ["SHIFT", "DASH"], ["ESC", "PAUSE"]]
	var total := 0.0
	for e in entries:
		total += UiKit.text_width(str(e[0]), 7) + 6.0 + 4.0 + UiKit.text_width(str(e[1]), 7) + 12.0
	var x := view.x * 0.5 - total * 0.5
	var y := view.y - 40.0
	for e in entries:
		x += UiKit.key_cap(canvas, str(e[0]), Vector2(x, y)) + 4.0
		_t(str(e[1]), Vector2(x, y + 8.5), 7, UiKit.MUTED)
		x += UiKit.text_width(str(e[1]), 7) + 12.0


# --- Upgrade menu ---------------------------------------------------------------------------------------

func _draw_upgrade_menu(view: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.05, 0.03, 0.08, 0.86))
	var t := _num("time")
	var cy := view.y * 0.5
	_t(str(data.get("upgrade_title", "CHOOSE AN UPGRADE")), Vector2(0, cy - 84.0), 18, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_t(str(data.get("upgrade_subtitle", "")), Vector2(0, cy - 70.0), 8, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, view.x)
	var choices: Array = data.get("upgrades", [])
	var selected := int(data.get("menu_index", 0))
	var card_size := Vector2(132, 124)
	var gap := 10.0
	var total := card_size.x * float(choices.size()) + gap * float(maxi(choices.size() - 1, 0))
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var rarity := int(choice.get("rarity", 0))
		var accent := UiKit.rarity_color(rarity)
		var chosen := i == selected
		var card := Rect2(Vector2(view.x * 0.5 - total * 0.5 + float(i) * (card_size.x + gap), cy - 60.0), card_size)
		if chosen:
			card.position.y -= 5.0 + sin(t * 6.0)
			canvas.draw_rect(card.grow(3.0), Color(accent, 0.2 + 0.08 * sin(t * 6.0)))
		UiKit.panel(canvas, card, Color("#33263f") if chosen else UiKit.PANEL, accent if chosen else UiKit.BORDER, accent)
		_t(GameData.RARITY_NAMES[clampi(rarity, 0, 2)], Vector2(card.position.x, card.position.y + 14.0), 6, accent, HORIZONTAL_ALIGNMENT_CENTER, card_size.x)
		_t(str(i + 1), card.position + Vector2(7, 15), 10, accent)
		var ic := Vector2(card.position.x + card_size.x * 0.5, card.position.y + 38.0)
		canvas.draw_circle(ic, 17.0, Color(accent, 0.16))
		canvas.draw_arc(ic, 17.0, 0.0, TAU, 28, Color(accent, 0.6), 1.0)
		UiKit.icon(canvas, str(choice.get("glyph", "")), ic, 10.0, accent)
		var y := card.position.y + 69.0
		for line in UiKit.wrap_text(str(choice.get("name", "")), 8, card_size.x - 12.0):
			_t(line, Vector2(card.position.x, y), 8, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, card_size.x)
			y += 10.0
		var current := int(choice.get("current", 0))
		var level_text := "NEW" if current == 0 else "LV %d  >  %d" % [current, current + 1]
		if bool(choice.get("instant", false)):
			level_text = "INSTANT"
		_t(level_text, Vector2(card.position.x, y + 1.0), 7, accent, HORIZONTAL_ALIGNMENT_CENTER, card_size.x)
		UiKit.paragraph(canvas, str(choice.get("desc", "")), Vector2(card.position.x + 6.0, y + 12.0), 7, UiKit.MUTED, card_size.x - 12.0, 9.0, HORIZONTAL_ALIGNMENT_CENTER)
	var hint_y := cy + 82.0
	_t("1 2 3  or  LEFT / RIGHT  +  ENTER", Vector2(0, hint_y), 8, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, view.x)


# --- Pause ------------------------------------------------------------------------------------------------

func _draw_menu_items(origin: Vector2, width: float, items: Array, selected: int, spacing: float) -> void:
	for i in items.size():
		var y := origin.y + float(i) * spacing
		if i == selected:
			canvas.draw_rect(Rect2(origin.x, y - 11.0, width, spacing - 3.0), Color("#4d3650"))
			canvas.draw_rect(Rect2(origin.x, y - 11.0, width, spacing - 3.0), Color(UiKit.GOLD, 0.7), false, 1.0)
			_t("> %s" % str(items[i]), Vector2(origin.x + 8.0, y), 9, UiKit.CREAM)
		else:
			_t(str(items[i]), Vector2(origin.x + 8.0, y), 8, UiKit.MUTED)


func _draw_pause(view: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.05, 0.04, 0.08, 0.78))
	var panel := Rect2(view.x * 0.5 - 210.0, 16.0, 420.0, 240.0)
	UiKit.panel(canvas, panel, UiKit.PANEL, UiKit.BORDER, UiKit.GOLD)
	_t("PAUSED", Vector2(panel.position.x, panel.position.y + 26.0), 18, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)

	var menu := Rect2(panel.position + Vector2(12, 38), Vector2(120, 78))
	UiKit.panel(canvas, menu, UiKit.PANEL_LIGHT)
	_draw_menu_items(menu.position + Vector2(6, 22), menu.size.x - 12.0, data.get("pause_items", []), int(data.get("menu_index", 0)), 22.0)

	var stats_panel := Rect2(panel.position + Vector2(140, 38), Vector2(268, 78))
	UiKit.panel(canvas, stats_panel, UiKit.PANEL_LIGHT)
	var stats: Array = data.get("stats", [])
	for i in stats.size():
		var pair: Array = stats[i]
		var pos := stats_panel.position + Vector2(8.0 + float(i % 2) * 130.0, 14.0 + floorf(float(i) / 2.0) * 14.0)
		_t(str(pair[0]), pos, 7, UiKit.MUTED)
		_t(str(pair[1]), pos + Vector2(0, 0), 7, UiKit.CREAM, HORIZONTAL_ALIGNMENT_RIGHT, 120.0)

	var owned_panel := Rect2(panel.position + Vector2(12, 124), Vector2(396, 104))
	UiKit.panel(canvas, owned_panel, UiKit.PANEL_LIGHT)
	var owned: Array = data.get("owned", [])
	_t("UPGRADES  (%d)" % owned.size(), owned_panel.position + Vector2(8, 12), 7, UiKit.GOLD)
	if owned.is_empty():
		_t("None yet - clear a room to earn one.", owned_panel.position + Vector2(8, 28), 7, UiKit.MUTED)
	var shown := mini(owned.size(), 21)
	for i in shown:
		var entry: Dictionary = owned[i]
		var accent := UiKit.rarity_color(int(entry.get("rarity", 0)))
		var pos := owned_panel.position + Vector2(8.0 + float(i % 3) * 130.0, 26.0 + floorf(float(i) / 3.0) * 11.0)
		UiKit.icon(canvas, str(entry.get("glyph", "")), pos + Vector2(4, -3), 3.6, accent)
		var label := str(entry.get("name", ""))
		var level := int(entry.get("level", 1))
		if level > 1:
			label += "  x%d" % level
		_t(label, pos + Vector2(12, 0), 6, UiKit.CREAM)
	if owned.size() > shown:
		_tr("+%d more" % (owned.size() - shown), owned_panel.end.x - 10.0, owned_panel.end.y - 5.0, 6, UiKit.MUTED)
	_t("UP / DOWN  select      ENTER  confirm      ESC  resume", Vector2(panel.position.x, panel.end.y - 5.0), 7, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)


# --- End of run ------------------------------------------------------------------------------------------

func _draw_end(view: Vector2, title: String, subtitle: String, accent: Color) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view), Color(0.05, 0.04, 0.08, 0.78))
	var panel := Rect2(view.x * 0.5 - 135.0, view.y * 0.5 - 112.0, 270.0, 224.0)
	UiKit.panel(canvas, panel, UiKit.PANEL, accent, accent)
	_t(title, Vector2(panel.position.x, panel.position.y + 32.0), 20, accent.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	_t(subtitle, Vector2(panel.position.x, panel.position.y + 46.0), 8, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	var summary: Array = data.get("summary", [])
	var inner := Rect2(panel.position + Vector2(14, 56), Vector2(panel.size.x - 28.0, float(summary.size()) * 12.0 + 8.0))
	UiKit.panel(canvas, inner, UiKit.PANEL_LIGHT)
	for i in summary.size():
		var pair: Array = summary[i]
		var y := inner.position.y + 14.0 + float(i) * 12.0
		_t(str(pair[0]), Vector2(inner.position.x + 8.0, y), 7, UiKit.MUTED)
		var value_color := UiKit.CREAM
		if pair.size() > 2:
			value_color = pair[2]
		_t(str(pair[1]), Vector2(inner.position.x, y), 8, value_color, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x - 8.0)
	var items_y := inner.end.y + 22.0
	_draw_menu_items(Vector2(panel.position.x + 40.0, items_y), panel.size.x - 80.0, data.get("end_items", []), int(data.get("menu_index", 0)), 20.0)


# --- Floor intro card ------------------------------------------------------------------------------------------

func _draw_floor_card(view: Vector2) -> void:
	var alpha := clampf(_num("floor_card_alpha"), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var cy := view.y * 0.5
	_t(str(data.get("floor_card_title", "")), Vector2(0, cy - 22.0), 9, Color(UiKit.GOLD, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_t(str(data.get("floor_card_name", "")), Vector2(0, cy + 2.0), 22, Color(UiKit.CREAM, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	_t(str(data.get("floor_card_sub", "")), Vector2(0, cy + 18.0), 9, Color(UiKit.MUTED, alpha), HORIZONTAL_ALIGNMENT_CENTER, view.x)
	canvas.draw_line(Vector2(view.x * 0.5 - 120.0, cy + 26.0), Vector2(view.x * 0.5 + 120.0, cy + 26.0), Color(UiKit.GOLD, alpha * 0.5), 1.0)
