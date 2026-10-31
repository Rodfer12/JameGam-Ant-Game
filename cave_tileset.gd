class_name CaveTileset
extends RefCounted

## Builds the cave art at runtime from small procedurally drawn 16x16 tiles.
## Tiles are shaded from their neighbours (wall shadows on the floor, lit rims
## and a visible wall face on walls), so the cave reads as one connected space
## and never depends on atlas coordinates that might not exist.

const TILE := 16
const ATLAS_COLUMNS := 32

const KIND_FLOOR := 0
const KIND_WALL := 1

## Neighbour bits. For floor tiles a set bit means "that neighbour is wall",
## for wall tiles it means "that neighbour is open air".
const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8
const BIT_NE := 16
const BIT_SE := 32
const BIT_SW := 64
const BIT_NW := 128

const THEME_NAMES: Array[String] = ["ROOTBOUND", "FUNGUS", "NURSERY", "NEST", "SCARLET", "CRYSTAL", "QUEEN"]

const PROP_TORCH := 0
const PROP_GATE := 1
const PROP_PEBBLES := 2
const PROP_MUSHROOM_PINK := 3
const PROP_MUSHROOM_TEAL := 4
const PROP_CRYSTAL_CYAN := 5
const PROP_CRYSTAL_PURPLE := 6
const PROP_EGG := 7
const PROP_ROOTS := 8
const PROP_BONE := 9
const PROP_RUBBLE := 10
const PROP_COUNT := 11

static var _tile_image_cache: Dictionary = {}
static var _prop_tile_set: TileSet
static var _light_texture: Texture2D

var _keys: Array[int] = []
var _index_by_key: Dictionary = {}


static func theme_index(theme_name: String) -> int:
	return maxi(THEME_NAMES.find(theme_name), 0)


static func theme_light_color(theme: int) -> Color:
	match theme:
		1: return Color(0.45, 1.0, 0.7)
		2: return Color(0.75, 0.55, 1.0)
		3: return Color(1.0, 0.8, 0.5)
		4: return Color(1.0, 0.4, 0.45)
		5: return Color(0.45, 0.7, 1.0)
		6: return Color(1.0, 0.45, 0.8)
		_: return Color(1.0, 0.65, 0.35)


static func light_texture() -> Texture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		gradient.colors = PackedColorArray([
			Color(1, 1, 1, 1),
			Color(0.45, 0.45, 0.45, 0.45),
			Color(0, 0, 0, 0)
		])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 256
		texture.height = 256
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		_light_texture = texture
	return _light_texture


## Registers a tile and returns its atlas coordinates (deduplicated).
func request(kind: int, theme: int, variant: int, mask: int) -> Vector2i:
	var key := kind | (theme << 1) | (variant << 4) | (mask << 6)
	if not _index_by_key.has(key):
		_index_by_key[key] = _keys.size()
		_keys.append(key)
	var index: int = _index_by_key[key]
	return Vector2i(index % ATLAS_COLUMNS, floori(float(index) / float(ATLAS_COLUMNS)))


func build_tile_set() -> TileSet:
	var count := maxi(_keys.size(), 1)
	var rows := ceili(float(count) / float(ATLAS_COLUMNS))
	var atlas := Image.create_empty(ATLAS_COLUMNS * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	for index in _keys.size():
		var tile_image := _get_tile_image(_keys[index])
		var column := index % ATLAS_COLUMNS
		var row := floori(float(index) / float(ATLAS_COLUMNS))
		atlas.blit_rect(tile_image, Rect2i(0, 0, TILE, TILE), Vector2i(column * TILE, row * TILE))
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(TILE, TILE)
	for index in _keys.size():
		source.create_tile(Vector2i(index % ATLAS_COLUMNS, floori(float(index) / float(ATLAS_COLUMNS))))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)
	return tile_set


static func build_prop_tile_set() -> TileSet:
	if _prop_tile_set != null:
		return _prop_tile_set
	var atlas := Image.create_empty(PROP_COUNT * TILE, TILE, false, Image.FORMAT_RGBA8)
	for prop in PROP_COUNT:
		var image := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
		_paint_prop(image, prop)
		atlas.blit_rect(image, Rect2i(0, 0, TILE, TILE), Vector2i(prop * TILE, 0))
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(TILE, TILE)
	for prop in PROP_COUNT:
		source.create_tile(Vector2i(prop, 0))
	var props_tile_set := TileSet.new()
	props_tile_set.tile_size = Vector2i(TILE, TILE)
	props_tile_set.add_source(source, 0)
	_prop_tile_set = props_tile_set
	return _prop_tile_set


static func _get_tile_image(key: int) -> Image:
	if _tile_image_cache.has(key):
		return _tile_image_cache[key]
	var kind := key & 1
	var theme := (key >> 1) & 7
	var variant := (key >> 4) & 3
	var mask := (key >> 6) & 255
	var image := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	var palette := _palette(theme)
	if kind == KIND_FLOOR:
		_paint_floor(image, palette, variant, mask, theme)
	else:
		_paint_wall(image, palette, variant, mask, theme)
	_tile_image_cache[key] = image
	return image


static func _make_palette(floor_hex: String, floor_light_hex: String, floor_dark_hex: String, top_hex: String, face_hex: String, face_dark_hex: String, rim_hex: String) -> Dictionary:
	return {
		"floor": Color.html(floor_hex),
		"floor_light": Color.html(floor_light_hex),
		"floor_dark": Color.html(floor_dark_hex),
		"top": Color.html(top_hex),
		"face": Color.html(face_hex),
		"face_dark": Color.html(face_dark_hex),
		"rim": Color.html(rim_hex)
	}


static func _palette(theme: int) -> Dictionary:
	match theme:
		1: return _make_palette("#3b5a45", "#486b52", "#2f4837", "#172720", "#2a4333", "#1f3327", "#5f8f69")
		2: return _make_palette("#5b4a6b", "#6a5879", "#473a56", "#231a2e", "#3d3150", "#2e2540", "#8a74a3")
		3: return _make_palette("#7a6045", "#8b6f50", "#634d37", "#2b2018", "#54402e", "#42322a", "#a98a66")
		4: return _make_palette("#6b3a42", "#7d4650", "#552d34", "#26141a", "#4b2630", "#391c25", "#9b5a66")
		5: return _make_palette("#3b4f78", "#496088", "#2f3f60", "#151c2e", "#2c3b5e", "#222e4a", "#6f95c8")
		6: return _make_palette("#6b3351", "#7d3f5f", "#552942", "#240f1d", "#4a2039", "#381830", "#b0588b")
		_: return _make_palette("#6b4a35", "#7c5840", "#54372a", "#2e1f1a", "#4a3226", "#3a261d", "#8a6347")


static func _hash01(x: int, y: int, seed_value: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed_value * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 65535) / 65535.0


static func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(image, xx, yy, color)


static func _ellipse(image: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_put(image, x, y, color)


static func _line(image: Image, from_point: Vector2, to_point: Vector2, color: Color) -> void:
	var steps := maxi(1, ceili(from_point.distance_to(to_point)))
	for i in range(steps + 1):
		var point := from_point.lerp(to_point, float(i) / float(steps))
		_put(image, floori(point.x), floori(point.y), color)


static func _polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	for y in TILE:
		for x in TILE:
			if Geometry2D.is_point_in_polygon(Vector2(float(x) + 0.5, float(y) + 0.5), points):
				_put(image, x, y, color)


static func _floor_shade(x: int, y: int, mask: int) -> float:
	var shade := 1.0
	var fx := float(x)
	var fy := float(y)
	if (mask & BIT_N) != 0:
		shade *= 1.0 - 0.62 * clampf((7.0 - fy) / 7.0, 0.0, 1.0)
	if (mask & BIT_S) != 0:
		shade *= 1.0 - 0.38 * clampf((fy - 11.0) / 4.0, 0.0, 1.0)
	if (mask & BIT_W) != 0:
		shade *= 1.0 - 0.5 * clampf((4.0 - fx) / 4.0, 0.0, 1.0)
	if (mask & BIT_E) != 0:
		shade *= 1.0 - 0.5 * clampf((fx - 11.0) / 4.0, 0.0, 1.0)
	if (mask & BIT_NW) != 0:
		shade *= 1.0 - 0.45 * clampf((6.0 - Vector2(fx, fy).length()) / 6.0, 0.0, 1.0)
	if (mask & BIT_NE) != 0:
		shade *= 1.0 - 0.45 * clampf((6.0 - Vector2(15.0 - fx, fy).length()) / 6.0, 0.0, 1.0)
	if (mask & BIT_SW) != 0:
		shade *= 1.0 - 0.45 * clampf((6.0 - Vector2(fx, 15.0 - fy).length()) / 6.0, 0.0, 1.0)
	if (mask & BIT_SE) != 0:
		shade *= 1.0 - 0.45 * clampf((6.0 - Vector2(15.0 - fx, 15.0 - fy).length()) / 6.0, 0.0, 1.0)
	return shade


static func _paint_floor(image: Image, palette: Dictionary, variant: int, mask: int, theme: int) -> void:
	var base: Color = palette["floor"]
	var light: Color = palette["floor_light"]
	var dark: Color = palette["floor_dark"]
	var seed_value := theme * 31 + variant * 7 + 3
	for y in TILE:
		for x in TILE:
			var n := _hash01(x, y, seed_value)
			var color := base
			if n > 0.86:
				color = light
			elif n < 0.14:
				color = dark
			elif n > 0.5 and (x + y) % 4 == 0:
				color = base.lerp(light, 0.35)
			var blob := _hash01(x >> 2, y >> 2, seed_value + 11)
			if blob > 0.62:
				color = color.lerp(light, 0.12)
			elif blob < 0.25:
				color = color.lerp(dark, 0.12)
			image.set_pixel(x, y, color)
	match variant:
		1:
			_line(image, Vector2(3, 4), Vector2(7, 8), dark)
			_line(image, Vector2(7, 8), Vector2(10, 9), dark)
			_line(image, Vector2(7, 8), Vector2(8, 12), dark)
		2:
			_ellipse(image, 5.0, 10.0, 1.8, 1.3, light.lightened(0.15))
			_ellipse(image, 11.0, 5.0, 1.4, 1.1, light.lightened(0.1))
			_put(image, 5, 11, dark)
			_put(image, 11, 6, dark)
		3:
			_put(image, 4, 5, dark.darkened(0.2))
			_put(image, 5, 5, dark.darkened(0.2))
			_put(image, 11, 11, dark.darkened(0.2))
	if mask != 0:
		for y in TILE:
			for x in TILE:
				var shade := _floor_shade(x, y, mask)
				if shade < 0.999:
					var c := image.get_pixel(x, y)
					image.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, 1.0))


static func _paint_wall(image: Image, palette: Dictionary, variant: int, mask: int, theme: int) -> void:
	var top: Color = palette["top"]
	var face: Color = palette["face"]
	var face_dark: Color = palette["face_dark"]
	var rim: Color = palette["rim"]
	var has_face := (mask & BIT_S) != 0
	var seed_value := theme * 17 + variant * 5 + 101
	for y in TILE:
		for x in TILE:
			var n := _hash01(x, y, seed_value)
			var color: Color
			if has_face:
				color = face
				if y % 5 == 4:
					color = face_dark
				elif n > 0.88:
					color = face.lightened(0.12)
				elif n < 0.1:
					color = face_dark
				if y >= 14:
					color = color.darkened(0.35)
			else:
				color = top
				if n > 0.9:
					color = top.lightened(0.16)
				elif n < 0.16:
					color = top.darkened(0.2)
			image.set_pixel(x, y, color)
	if has_face:
		var crack_x := 4 + variant * 3
		for y in range(4, 12):
			_put(image, crack_x + (y % 2), y, face_dark)
	elif mask == 0:
		if variant == 1 or variant == 3:
			_ellipse(image, 5.0, 6.0, 3.0, 2.2, top.lightened(0.1))
		if variant == 2 or variant == 3:
			_ellipse(image, 11.0, 11.0, 2.6, 2.0, top.lightened(0.08))
	# Lit rims where the wall meets open air.
	if (mask & BIT_N) != 0:
		for x in TILE:
			_put(image, x, 0, rim)
			if not has_face:
				_put(image, x, 1, rim.darkened(0.3))
	if (mask & BIT_W) != 0:
		for y in TILE:
			_put(image, 0, y, rim.darkened(0.1))
	if (mask & BIT_E) != 0:
		for y in TILE:
			_put(image, 15, y, rim.darkened(0.45))
	if (mask & BIT_NW) != 0:
		_put(image, 0, 0, rim)
	if (mask & BIT_NE) != 0:
		_put(image, 15, 0, rim.darkened(0.2))


static func _paint_prop(image: Image, prop: int) -> void:
	match prop:
		PROP_TORCH:
			_rect(image, 7, 8, 2, 5, Color.html("#4a2e1a"))
			_rect(image, 6, 7, 4, 1, Color.html("#6b6b73"))
			_ellipse(image, 8.0, 4.5, 2.6, 3.6, Color.html("#ff8a1f"))
			_ellipse(image, 8.0, 5.2, 1.4, 2.2, Color.html("#ffd24a"))
			_put(image, 8, 5, Color.html("#fff6c8"))
		PROP_GATE:
			var dark := Color.html("#2a1420")
			var mid := Color.html("#5b2a3a")
			var glow := Color.html("#e0507a")
			_line(image, Vector2(0, 3), Vector2(15, 13), dark)
			_line(image, Vector2(0, 2), Vector2(15, 12), mid)
			_line(image, Vector2(0, 13), Vector2(15, 3), dark)
			_line(image, Vector2(0, 12), Vector2(15, 2), mid)
			_line(image, Vector2(0, 8), Vector2(15, 8), dark)
			_line(image, Vector2(0, 7), Vector2(15, 7), mid)
			for p in [Vector2i(4, 4), Vector2i(11, 4), Vector2i(4, 11), Vector2i(11, 11), Vector2i(8, 8)]:
				_put(image, p.x, p.y, glow)
				_put(image, p.x, p.y - 1, glow.darkened(0.3))
		PROP_PEBBLES:
			_ellipse(image, 4.0, 11.0, 2.2, 1.6, Color.html("#8a8378"))
			_ellipse(image, 11.0, 7.0, 1.7, 1.3, Color.html("#7a746a"))
			_ellipse(image, 8.0, 12.0, 1.2, 0.9, Color.html("#9a9488"))
			_put(image, 4, 12, Color.html("#4a463f"))
		PROP_MUSHROOM_PINK, PROP_MUSHROOM_TEAL:
			var cap := Color.html("#d36eaa") if prop == PROP_MUSHROOM_PINK else Color.html("#4fd1b0")
			_rect(image, 7, 9, 2, 4, Color.html("#e6d5b0"))
			_ellipse(image, 8.0, 8.0, 4.5, 3.2, cap)
			_rect(image, 3, 9, 10, 1, cap.darkened(0.35))
			_put(image, 6, 7, Color.html("#fff0c2"))
			_put(image, 10, 8, Color.html("#fff0c2"))
		PROP_CRYSTAL_CYAN, PROP_CRYSTAL_PURPLE:
			var main_color := Color.html("#78d9e6") if prop == PROP_CRYSTAL_CYAN else Color.html("#ad7ee8")
			var side_color := main_color.darkened(0.3)
			_polygon(image, PackedVector2Array([Vector2(8, 2), Vector2(11, 8), Vector2(10, 14), Vector2(6, 14), Vector2(5, 8)]), main_color)
			_polygon(image, PackedVector2Array([Vector2(3, 8), Vector2(5, 11), Vector2(4, 14), Vector2(1, 14)]), side_color)
			_line(image, Vector2(8, 3), Vector2(7, 12), Color.html("#e6ffff"))
		PROP_EGG:
			_ellipse(image, 8.0, 13.0, 6.0, 2.0, Color.html("#6b4a35"))
			_ellipse(image, 8.0, 9.0, 4.0, 5.2, Color.html("#e8c2a8"))
			_put(image, 6, 6, Color.html("#fff1e0"))
			_put(image, 7, 6, Color.html("#fff1e0"))
			_put(image, 9, 10, Color.html("#c98b78"))
			_put(image, 7, 11, Color.html("#c98b78"))
		PROP_ROOTS:
			var root := Color.html("#5a3a22")
			var root_light := Color.html("#7d5636")
			_line(image, Vector2(2, 14), Vector2(5, 8), root)
			_line(image, Vector2(5, 8), Vector2(4, 3), root)
			_line(image, Vector2(8, 14), Vector2(8, 6), root)
			_line(image, Vector2(13, 14), Vector2(11, 9), root)
			_line(image, Vector2(9, 14), Vector2(9, 7), root_light)
		PROP_BONE:
			var bone := Color.html("#e8e2d0")
			_line(image, Vector2(3, 11), Vector2(12, 6), bone)
			_line(image, Vector2(3, 12), Vector2(12, 7), bone.darkened(0.2))
			_ellipse(image, 3.0, 11.0, 1.8, 1.8, bone)
			_ellipse(image, 12.0, 6.0, 1.8, 1.8, bone)
		_:
			_polygon(image, PackedVector2Array([Vector2(2, 13), Vector2(4, 8), Vector2(8, 7), Vector2(9, 13)]), Color.html("#6f655a"))
			_polygon(image, PackedVector2Array([Vector2(8, 13), Vector2(10, 9), Vector2(14, 10), Vector2(14, 13)]), Color.html("#857a6c"))
			_line(image, Vector2(4, 9), Vector2(7, 8), Color.html("#a39887"))
