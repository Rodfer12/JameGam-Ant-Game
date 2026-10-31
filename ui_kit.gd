class_name UiKit
extends RefCounted

## Stateless drawing helpers shared by the HUD and the menus. Every function
## takes the CanvasItem to draw on, so it works from any _draw callback.

const OUTLINE := Color(0.05, 0.03, 0.08, 0.92)
const PANEL := Color("#1d1726", 0.94)
const PANEL_LIGHT := Color("#2d2238", 0.96)
const BORDER := Color("#6b5478", 0.95)
const GOLD := Color("#f4d9ad")
const CREAM := Color("#fff0c2")
const MUTED := Color("#b99bbd")
const GREEN := Color("#8bf08b")
const RED := Color("#ff5d73")
const BLUE := Color("#7cc8ff")
const YELLOW := Color("#fff0a6")

static var _font: Font


static func font() -> Font:
	if _font == null:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Segoe UI", "Trebuchet MS", "Verdana", "Arial"])
		system_font.font_weight = 600
		_font = system_font
	return _font


static func rarity_color(rarity: int) -> Color:
	return Color(GameData.RARITY_COLORS[clampi(rarity, 0, GameData.RARITY_COLORS.size() - 1)])


static func text(ci: CanvasItem, s: String, at: Vector2, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f := font()
	var outline := Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, OUTLINE.a * color.a)
	ci.draw_string_outline(f, at, s, align, width, size, 2 if size <= 9 else 3, outline)
	ci.draw_string(f, at, s, align, width, size, color)


static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


static func wrap_text(s: String, size: int, width: float) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in s.split(" "):
		var candidate := word if current == "" else current + " " + word
		if current != "" and text_width(candidate, size) > width:
			lines.append(current)
			current = word
		else:
			current = candidate
	if current != "":
		lines.append(current)
	return lines


## Draws wrapped text, returns the y just below the last line.
static func paragraph(ci: CanvasItem, s: String, at: Vector2, size: int, color: Color, width: float, line_height: float, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var y := at.y
	for line in wrap_text(s, size, width):
		text(ci, line, Vector2(at.x, y), size, color, align, width)
		y += line_height
	return y


static func panel(ci: CanvasItem, rect: Rect2, fill: Color = PANEL, border: Color = BORDER, accent: Color = Color(0, 0, 0, 0)) -> void:
	ci.draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.5))
	ci.draw_rect(rect, fill)
	ci.draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2(1, 1)), border, false, 1.0)
	ci.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4.0, 1.0)), Color(1, 1, 1, 0.07))
	if accent.a > 0.0:
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), accent)


static func bar(ci: CanvasItem, rect: Rect2, ratio: float, fill: Color, back: Color = Color(0.07, 0.05, 0.1, 0.92), segments: int = 0, lag_ratio: float = -1.0) -> void:
	ci.draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.6))
	ci.draw_rect(rect, back)
	if lag_ratio > ratio:
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(lag_ratio, 0.0, 1.0), rect.size.y)), Color(1.0, 0.85, 0.85, 0.55))
	var w := rect.size.x * clampf(ratio, 0.0, 1.0)
	if w > 0.0:
		ci.draw_rect(Rect2(rect.position, Vector2(w, rect.size.y)), fill)
		ci.draw_rect(Rect2(rect.position, Vector2(w, maxf(1.0, rect.size.y * 0.35))), Color(1, 1, 1, 0.22))
	if segments > 1:
		for i in range(1, segments):
			var x := rect.position.x + rect.size.x * float(i) / float(segments)
			ci.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0, 0, 0, 0.45), 1.0)


static func heart(ci: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var s := size / 6.0
	ci.draw_circle(center + Vector2(-2.6, -1.5) * s, 3.2 * s, color)
	ci.draw_circle(center + Vector2(2.6, -1.5) * s, 3.2 * s, color)
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-5.6, -0.3) * s, center + Vector2(5.6, -0.3) * s, center + Vector2(0, 6.4) * s]), color)


## Small pictograms so upgrades and abilities read at a glance. s = half-size.
static func icon(ci: CanvasItem, glyph: String, c: Vector2, s: float, color: Color) -> void:
	var dark := color.darkened(0.45)
	match glyph:
		"drop":
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.65, color)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(-s * 0.6, s * 0.1), c + Vector2(s * 0.6, s * 0.1)]), color)
			ci.draw_circle(c + Vector2(-s * 0.2, s * 0.2), s * 0.18, Color(1, 1, 1, 0.55))
		"heart":
			heart(ci, c, s * 1.8, color)
		"boot", "dash", "double":
			var chevrons := 2 if glyph != "boot" else 1
			for i in chevrons:
				var o := Vector2(float(i) * s * 0.9 - (s * 0.45 if chevrons == 2 else 0.0), 0.0)
				ci.draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.5, -s * 0.8), c + o + Vector2(s * 0.4, 0), c + o + Vector2(-s * 0.5, s * 0.8)]), color, maxf(1.5, s * 0.3))
			if glyph == "boot":
				ci.draw_line(c + Vector2(-s, 0), c + Vector2(-s * 0.3, 0), color, maxf(1.5, s * 0.3))
		"clock":
			ci.draw_arc(c, s * 0.9, 0.0, TAU, 20, color, maxf(1.5, s * 0.25))
			ci.draw_line(c, c + Vector2(0, -s * 0.6), color, 1.5)
			ci.draw_line(c, c + Vector2(s * 0.45, s * 0.2), color, 1.5)
		"flask":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s), c + Vector2(s * 0.3, -s), c + Vector2(s * 0.3, -s * 0.2), c + Vector2(s * 0.9, s), c + Vector2(-s * 0.9, s), c + Vector2(-s * 0.3, -s * 0.2)]), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.6, s * 0.35), Vector2(s * 1.2, s * 0.5)), dark)
		"bite", "drain":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.9), c + Vector2(-s * 0.1, -s * 0.9), c + Vector2(-s * 0.5, s * 0.8)]), color)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s, -s * 0.9), c + Vector2(s * 0.1, -s * 0.9), c + Vector2(s * 0.5, s * 0.8)]), color)
			if glyph == "drain":
				ci.draw_circle(c + Vector2(0, s * 0.7), s * 0.25, Color(RED))
		"eye":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.4, -s * 0.6), c + Vector2(s * 0.4, -s * 0.6), c + Vector2(s, 0), c + Vector2(s * 0.4, s * 0.6), c + Vector2(-s * 0.4, s * 0.6), c + Vector2(-s, 0)]), color, 1.5)
			ci.draw_circle(c, s * 0.38, color)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8), c + Vector2(s * 0.8, s * 0.1), c + Vector2(0, s), c + Vector2(-s * 0.8, s * 0.1)]), color)
			ci.draw_line(c + Vector2(0, -s * 0.6), c + Vector2(0, s * 0.6), dark, 1.5)
		"magnet":
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.7, PI, TAU, 12, color, maxf(2.0, s * 0.4))
			ci.draw_line(c + Vector2(-s * 0.7, -s * 0.1), c + Vector2(-s * 0.7, s * 0.8), color, maxf(2.0, s * 0.4))
			ci.draw_line(c + Vector2(s * 0.7, -s * 0.1), c + Vector2(s * 0.7, s * 0.8), color, maxf(2.0, s * 0.4))
		"multi":
			for i in 3:
				var a := (float(i) - 1.0) * 0.55
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.7, s * 0.28, color)
			ci.draw_circle(c + Vector2(-s * 0.8, 0), s * 0.3, color)
		"pierce":
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), color, 1.5)
			ci.draw_circle(c + Vector2(-s * 0.2, 0), s * 0.45, dark)
			ci.draw_circle(c + Vector2(s * 0.6, 0), s * 0.35, color)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(s * 0.5, -s * 0.4), c + Vector2(s * 0.5, s * 0.4)]), color)
		"virus", "plague", "burst":
			ci.draw_circle(c, s * 0.5, color)
			for i in 8:
				var a := TAU * float(i) / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.5, c + Vector2(cos(a), sin(a)) * s, color, 1.5)
		"trail":
			for i in 3:
				ci.draw_circle(c + Vector2(float(i - 1) * s * 0.8, 0), s * (0.6 - float(i) * 0.15), color)
		"thorn":
			for i in 5:
				var a := TAU * float(i) / 5.0 - PI / 2.0
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a - 0.4), sin(a - 0.4)) * s * 0.4, c + Vector2(cos(a), sin(a)) * s, c + Vector2(cos(a + 0.4), sin(a + 0.4)) * s * 0.4]), color)
		"deflect":
			ci.draw_arc(c, s * 0.85, -PI * 0.8, PI * 0.8, 14, color, maxf(2.0, s * 0.3))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.9, 0), c + Vector2(s * 0.3, -s * 0.5), c + Vector2(s * 0.3, s * 0.5)]), color)
		"bounce":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.6), c + Vector2(-s * 0.2, s * 0.7), c + Vector2(s * 0.3, -s * 0.5), c + Vector2(s, s * 0.6)]), color, 1.8)
		"combo":
			ci.draw_line(c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, s * 0.7), color, 2.0)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.7, -s * 0.7), color, 2.0)
			ci.draw_circle(c, s * 0.3, color)
		"rage":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.6, -s * 0.1), c + Vector2(s * 0.5, s * 0.8), c + Vector2(0, s * 0.4), c + Vector2(-s * 0.5, s * 0.8), c + Vector2(-s * 0.6, -s * 0.1)]), color)
		"skull":
			ci.draw_circle(c + Vector2(0, -s * 0.15), s * 0.75, color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.3), Vector2(s * 0.8, s * 0.55)), color)
			ci.draw_circle(c + Vector2(-s * 0.3, -s * 0.2), s * 0.2, dark)
			ci.draw_circle(c + Vector2(s * 0.3, -s * 0.2), s * 0.2, dark)
		"wings":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, 0), c + Vector2(-s, -s * 0.8), c + Vector2(-s * 0.7, s * 0.5)]), color)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.1, 0), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.7, s * 0.5)]), color)
		"amber":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, 0), c + Vector2(0, s), c + Vector2(-s * 0.75, 0)]), color)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.1), c + Vector2(0, -s * 0.55), Color(1, 1, 1, 0.6), 1.0)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := TAU * float(i) / 10.0 - PI / 2.0
				var r := s if i % 2 == 0 else s * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, color)
		"plus":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.8), Vector2(s * 0.5, s * 1.6)), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.25), Vector2(s * 1.6, s * 0.5)), color)
		_:
			ci.draw_circle(c, s * 0.7, color)


## A square ability slot with a cooldown fill, key label and optional charge count.
static func ability_slot(ci: CanvasItem, rect: Rect2, glyph: String, ratio: float, key: String, color: Color, charges: int = -1, pulse: float = 0.0) -> void:
	var is_ready := ratio >= 0.999
	var border := color if is_ready else BORDER
	panel(ci, rect, PANEL_LIGHT, border)
	icon(ci, glyph, rect.get_center() + Vector2(0, -1), rect.size.x * 0.28, color if is_ready else color.darkened(0.45))
	if not is_ready:
		var covered := rect.size.y * (1.0 - clampf(ratio, 0.0, 1.0))
		ci.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2.0, maxf(0.0, covered - 2.0))), Color(0, 0, 0, 0.55))
	elif pulse > 0.0:
		ci.draw_rect(rect.grow(1.0), Color(color, 0.45 * pulse), false, 1.5)
	text(ci, key, rect.position + Vector2(2, rect.size.y - 2.0), 6, CREAM)
	if charges >= 0:
		text(ci, str(charges), rect.position + Vector2(rect.size.x - 6.0, 8.0), 7, YELLOW)


static func key_cap(ci: CanvasItem, label: String, at: Vector2) -> float:
	var w := text_width(label, 7) + 6.0
	var rect := Rect2(at, Vector2(w, 11.0))
	ci.draw_rect(rect, Color("#3a2c46"))
	ci.draw_rect(rect, BORDER, false, 1.0)
	text(ci, label, at + Vector2(3.0, 8.5), 7, CREAM)
	return w
