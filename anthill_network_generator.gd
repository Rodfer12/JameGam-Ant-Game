class_name AnthillGenerator
extends TileMapLayer

## Procedural ant-hill: a chain of rooms (entrance -> fights -> boss) joined by
## 3-tile corridors, plus optional dead-end side rooms (treasure / rest).
## Rendering uses CaveTileset; collision is a plain grid lookup so the game never
## needs physics bodies. Rooms seal with thorn gates while a fight is running.

const GRID_SIZE := Vector2i(96, 64)
const TILE := 16
const WALL_SAMPLES: Array[Vector2] = [
	Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7)
]

# Must match the ROOM_* constants in game_data.gd.
enum RoomType { START, COMBAT, ELITE, TREASURE, REST, BOSS }


class Room:
	var rect := Rect2i()
	var type := 0
	var theme := 0
	var title := ""
	var description := ""
	var center := Vector2i.ZERO
	var door_cells: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = []


var minimap_texture: ImageTexture
var rooms: Array[Room] = []

var _grid := PackedByteArray()
var _sealed := PackedByteArray()
var _theme := PackedByteArray()
var _room_index := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _props: TileMapLayer
var _lights: Array[PointLight2D] = []
var _base_theme := 0


func _ensure_props() -> void:
	if _props != null:
		return
	_props = TileMapLayer.new()
	_props.name = "Props"
	_props.z_index = 1
	_props.tile_set = CaveTileset.build_prop_tile_set()
	add_child(_props)


# --- Public API ---------------------------------------------------------------------------

## config: {"rooms": int, "sides": Array[int room types], "themes": Array[int], "elites": int}
func generate(seed_value: int, config: Dictionary) -> void:
	_ensure_props()
	_rng.seed = seed_value
	var main_count := int(config.get("rooms", 6))
	var side_types: Array = config.get("sides", [])
	var themes: Array = config.get("themes", [0])
	var elite_count := int(config.get("elites", 0))
	_base_theme = int(themes[0])
	var ok := false
	for attempt in 60:
		var target := main_count
		if attempt >= 30:
			target = maxi(4, main_count - 1)
		if attempt >= 45:
			target = maxi(3, main_count - 2)
		if _try_layout(target, side_types, themes):
			ok = true
			break
	if not ok:
		_fallback_layout(themes)
	_assign_elites(elite_count)
	_finish()


func get_rooms() -> Array[Room]:
	return rooms


func world_size() -> Vector2:
	return Vector2(GRID_SIZE * TILE)


func world_center(room: Room) -> Vector2:
	return cell_to_world(room.center)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(TILE * 0.5, TILE * 0.5)


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(TILE)), floori(pos.y / float(TILE)))


func is_wall_cell(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= GRID_SIZE.x or y >= GRID_SIZE.y:
		return true
	var i := y * GRID_SIZE.x + x
	return _grid[i] == 0 or _sealed[i] == 1


func is_wall_at_world(pos: Vector2, radius: float) -> bool:
	var r := radius * 0.8
	for offset in WALL_SAMPLES:
		var p := pos + offset * r
		if is_wall_cell(floori(p.x / float(TILE)), floori(p.y / float(TILE))):
			return true
	return false


func room_index_at_world(pos: Vector2) -> int:
	var cell := world_to_cell(pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return -1
	return _room_index[cell.y * GRID_SIZE.x + cell.x]


func room_index_deep_at_world(pos: Vector2, depth: int) -> int:
	var index := room_index_at_world(pos)
	if index < 0:
		return -1
	var cell := world_to_cell(pos)
	if rooms[index].rect.grow(-depth).has_point(cell):
		return index
	return -1


func get_room_floor_cells(index: int) -> Array[Vector2i]:
	if index < 0 or index >= rooms.size():
		return []
	return rooms[index].floor_cells


func set_room_sealed(index: int, sealed: bool) -> void:
	if index < 0 or index >= rooms.size():
		return
	for cell in rooms[index].door_cells:
		_sealed[cell.y * GRID_SIZE.x + cell.x] = 1 if sealed else 0
		if sealed:
			_props.set_cell(cell, 0, Vector2i(CaveTileset.PROP_GATE, 0))
		else:
			_props.erase_cell(cell)


# --- Layout --------------------------------------------------------------------------------

func _reset_grid() -> void:
	var count := GRID_SIZE.x * GRID_SIZE.y
	_grid = PackedByteArray()
	_grid.resize(count)
	_sealed = PackedByteArray()
	_sealed.resize(count)
	_theme = PackedByteArray()
	_theme.resize(count)
	_theme.fill(255)
	_room_index = PackedInt32Array()
	_room_index.resize(count)
	_room_index.fill(-1)
	rooms.clear()


func _rect_ok(rect: Rect2i) -> bool:
	if rect.position.x < 3 or rect.position.y < 3:
		return false
	if rect.end.x > GRID_SIZE.x - 3 or rect.end.y > GRID_SIZE.y - 3:
		return false
	for room in rooms:
		if room.rect.grow(4).intersects(rect):
			return false
	return true


func _theme_for(index: int, themes: Array) -> int:
	return int(themes[index % themes.size()])


func _place_room(rect: Rect2i, type: int, theme_idx: int) -> int:
	var room := Room.new()
	room.rect = rect
	room.type = type
	room.theme = theme_idx
	room.center = rect.position + rect.size / 2
	rooms.append(room)
	var index := rooms.size() - 1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var corner := (x == rect.position.x or x == rect.end.x - 1) and (y == rect.position.y or y == rect.end.y - 1)
			var i := y * GRID_SIZE.x + x
			_room_index[i] = index
			if corner:
				continue
			_grid[i] = 1
			_theme[i] = theme_idx
	return index


func _link(a_index: int, b_index: int) -> void:
	var a := rooms[a_index]
	var b := rooms[b_index]
	var corner := Vector2i(b.center.x, a.center.y)
	if _rng.randf() < 0.5:
		corner = Vector2i(a.center.x, b.center.y)
	_carve_line(a.center, corner, a.theme)
	_carve_line(corner, b.center, a.theme)


func _carve_line(from_cell: Vector2i, to_cell: Vector2i, theme_idx: int) -> void:
	var step := Vector2i(signi(to_cell.x - from_cell.x), signi(to_cell.y - from_cell.y))
	var cell := from_cell
	for guard in 400:
		_carve_brush(cell, theme_idx)
		if cell == to_cell:
			break
		cell += step


func _carve_brush(cell: Vector2i, theme_idx: int) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cell.x + dx
			var y := cell.y + dy
			if x < 1 or y < 1 or x >= GRID_SIZE.x - 1 or y >= GRID_SIZE.y - 1:
				continue
			var i := y * GRID_SIZE.x + x
			_grid[i] = 1
			if _theme[i] == 255:
				_theme[i] = theme_idx


@warning_ignore("integer_division")
func _try_layout(main_count: int, side_types: Array, themes: Array) -> bool:
	_reset_grid()
	for i in main_count:
		var is_boss := i == main_count - 1
		var size := Vector2i(_rng.randi_range(12, 17), _rng.randi_range(9, 12))
		if is_boss:
			size = Vector2i(_rng.randi_range(20, 23), _rng.randi_range(14, 16))
		var placed := false
		for attempt in 160:
			var rect := Rect2i()
			if i == 0:
				rect = Rect2i(Vector2i(_rng.randi_range(4, 12), _rng.randi_range(4, GRID_SIZE.y - size.y - 4)), size)
			else:
				var prev := rooms[i - 1]
				var angle := _rng.randf() * TAU
				var dist := _rng.randf_range(20.0, 38.0)
				var c := Vector2(prev.center) + Vector2(cos(angle), sin(angle)) * dist
				rect = Rect2i(Vector2i(roundi(c.x) - size.x / 2, roundi(c.y) - size.y / 2), size)
			if not _rect_ok(rect):
				continue
			var type: int = RoomType.COMBAT
			if i == 0:
				type = RoomType.START
			elif is_boss:
				type = RoomType.BOSS
			var theme_idx := int(themes[themes.size() - 1]) if is_boss else _theme_for(i, themes)
			var index := _place_room(rect, type, theme_idx)
			if i > 0:
				_link(index - 1, index)
			placed = true
			break
		if not placed:
			return false
	# Dead-end side rooms hanging off the main path.
	for side_type in side_types:
		for attempt in 120:
			var parent_index := _rng.randi_range(1, maxi(1, main_count - 2))
			if parent_index >= rooms.size():
				parent_index = 0
			var parent := rooms[parent_index]
			var size := Vector2i(_rng.randi_range(10, 12), _rng.randi_range(8, 10))
			var angle := _rng.randf() * TAU
			var dist := _rng.randf_range(22.0, 32.0)
			var c := Vector2(parent.center) + Vector2(cos(angle), sin(angle)) * dist
			var rect := Rect2i(Vector2i(roundi(c.x) - size.x / 2, roundi(c.y) - size.y / 2), size)
			if not _rect_ok(rect):
				continue
			var index := _place_room(rect, int(side_type), parent.theme)
			_link(parent_index, index)
			break
	return true



func _fallback_layout(themes: Array) -> void:
	_reset_grid()
	for i in 5:
		var is_boss := i == 4
		var size := Vector2i(16, 12) if is_boss else Vector2i(12, 9)
		var rect := Rect2i(Vector2i(3 + i * 18, 24 if is_boss else 26), size)
		var type: int = RoomType.COMBAT
		if i == 0:
			type = RoomType.START
		elif is_boss:
			type = RoomType.BOSS
		var index := _place_room(rect, type, _theme_for(i, themes))
		if i > 0:
			_link(index - 1, index)


func _assign_elites(count: int) -> void:
	var candidates: Array[int] = []
	for i in rooms.size():
		if rooms[i].type == RoomType.COMBAT and i >= 2:
			candidates.append(i)
	candidates.shuffle()
	for n in mini(count, candidates.size()):
		rooms[candidates[n]].type = RoomType.ELITE


# --- Finishing: pillars, doors, tiles, props --------------------------------------------------

func _finish() -> void:
	for i in rooms.size():
		_add_pillars(i)
	for i in rooms.size():
		_compute_doors(i)
		_compute_floor_cells(i)
	_name_rooms()
	_paint_tiles()
	_place_props()
	_build_minimap()


func _add_pillars(index: int) -> void:
	var room := rooms[index]
	if room.type != RoomType.COMBAT and room.type != RoomType.ELITE and room.type != RoomType.BOSS:
		return
	var count := _rng.randi_range(2, 4)
	if room.type == RoomType.BOSS:
		count = _rng.randi_range(4, 6)
	var inner := room.rect.grow(-3)
	if inner.size.x <= 0 or inner.size.y <= 0:
		return
	for n in count:
		for attempt in 14:
			var x := _rng.randi_range(inner.position.x, inner.end.x - 1)
			var y := _rng.randi_range(inner.position.y, inner.end.y - 1)
			if absi(x - room.center.x) < 3 or absi(y - room.center.y) < 3:
				continue
			var size := 2 if _rng.randf() < 0.5 else 1
			if _pillar_fits(x, y, size):
				for yy in size:
					for xx in size:
						_grid[(y + yy) * GRID_SIZE.x + (x + xx)] = 0
				break


func _pillar_fits(x: int, y: int, size: int) -> bool:
	for yy in range(y - 1, y + size + 1):
		for xx in range(x - 1, x + size + 1):
			if xx < 1 or yy < 1 or xx >= GRID_SIZE.x - 1 or yy >= GRID_SIZE.y - 1:
				return false
			if _grid[yy * GRID_SIZE.x + xx] != 1:
				return false
	return true


func _compute_doors(index: int) -> void:
	var room := rooms[index]
	var ring := room.rect.grow(1)
	room.door_cells.clear()
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var on_ring := x == ring.position.x or x == ring.end.x - 1 or y == ring.position.y or y == ring.end.y - 1
			if not on_ring:
				continue
			if x < 0 or y < 0 or x >= GRID_SIZE.x or y >= GRID_SIZE.y:
				continue
			var i := y * GRID_SIZE.x + x
			if _grid[i] == 1 and _room_index[i] == -1:
				room.door_cells.append(Vector2i(x, y))


func _compute_floor_cells(index: int) -> void:
	var room := rooms[index]
	room.floor_cells.clear()
	for y in range(room.rect.position.y, room.rect.end.y):
		for x in range(room.rect.position.x, room.rect.end.x):
			if _grid[y * GRID_SIZE.x + x] == 1:
				room.floor_cells.append(Vector2i(x, y))


func _name_rooms() -> void:
	var counters: Dictionary = {}
	for room in rooms:
		match room.type:
			RoomType.START:
				room.title = "THE WAY IN"
			RoomType.TREASURE:
				room.title = "THE TREASURY"
			RoomType.REST:
				room.title = "QUIET BURROW"
			RoomType.BOSS:
				room.title = "THE BOSS CHAMBER"
			_:
				var names: Array = GameData.ROOM_NAMES[clampi(room.theme, 0, GameData.ROOM_NAMES.size() - 1)]
				var k := int(counters.get(room.theme, 0))
				counters[room.theme] = k + 1
				room.title = str(names[k % names.size()])
		room.description = GameData.ROOM_FLAVOR[clampi(room.theme, 0, GameData.ROOM_FLAVOR.size() - 1)]


func _is_open(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= GRID_SIZE.x or y >= GRID_SIZE.y:
		return false
	return _grid[y * GRID_SIZE.x + x] == 1


func _cell_theme(x: int, y: int) -> int:
	var t := int(_theme[y * GRID_SIZE.x + x])
	if t != 255:
		return t
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= GRID_SIZE.x or ny >= GRID_SIZE.y:
				continue
			var nt := int(_theme[ny * GRID_SIZE.x + nx])
			if nt != 255:
				return nt
	return _base_theme


func _paint_tiles() -> void:
	var set_builder := CaveTileset.new()
	var coords: Array[Vector2i] = []
	coords.resize(GRID_SIZE.x * GRID_SIZE.y)
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var theme_idx := _cell_theme(x, y)
			var h: int = (x * 73856093) ^ (y * 19349663)
			var roll := (h >> 4) % 10
			var variant := 0 if roll < 6 else ((roll - 5) % 3) + 1
			var mask := 0
			var kind := CaveTileset.KIND_FLOOR
			if _is_open(x, y):
				if not _is_open(x, y - 1): mask |= CaveTileset.BIT_N
				if not _is_open(x + 1, y): mask |= CaveTileset.BIT_E
				if not _is_open(x, y + 1): mask |= CaveTileset.BIT_S
				if not _is_open(x - 1, y): mask |= CaveTileset.BIT_W
				if not _is_open(x + 1, y - 1): mask |= CaveTileset.BIT_NE
				if not _is_open(x + 1, y + 1): mask |= CaveTileset.BIT_SE
				if not _is_open(x - 1, y + 1): mask |= CaveTileset.BIT_SW
				if not _is_open(x - 1, y - 1): mask |= CaveTileset.BIT_NW
			else:
				kind = CaveTileset.KIND_WALL
				if _is_open(x, y - 1): mask |= CaveTileset.BIT_N
				if _is_open(x + 1, y): mask |= CaveTileset.BIT_E
				if _is_open(x, y + 1): mask |= CaveTileset.BIT_S
				if _is_open(x - 1, y): mask |= CaveTileset.BIT_W
				if _is_open(x + 1, y - 1): mask |= CaveTileset.BIT_NE
				if _is_open(x + 1, y + 1): mask |= CaveTileset.BIT_SE
				if _is_open(x - 1, y + 1): mask |= CaveTileset.BIT_SW
				if _is_open(x - 1, y - 1): mask |= CaveTileset.BIT_NW
			coords[y * GRID_SIZE.x + x] = set_builder.request(kind, theme_idx, variant, mask)
	tile_set = set_builder.build_tile_set()
	clear()
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			set_cell(Vector2i(x, y), 0, coords[y * GRID_SIZE.x + x])


func _place_props() -> void:
	_props.clear()
	for light in _lights:
		if is_instance_valid(light):
			light.queue_free()
	_lights.clear()
	for room in rooms:
		# Torches mounted on the wall face above the room.
		var top_y := room.rect.position.y - 1
		for x: int in [room.rect.position.x + 3, room.rect.end.x - 4]:
			if _is_open(x, top_y) or not _is_open(x, top_y + 1):
				continue
			_props.set_cell(Vector2i(x, top_y), 0, Vector2i(CaveTileset.PROP_TORCH, 0))
			var light := PointLight2D.new()
			light.texture = CaveTileset.light_texture()
			light.color = CaveTileset.theme_light_color(room.theme)
			light.energy = 0.75
			light.texture_scale = 1.25
			light.position = cell_to_world(Vector2i(x, top_y)) + Vector2(0, 4)
			add_child(light)
			_lights.append(light)
		if room.type == RoomType.TREASURE or room.type == RoomType.REST or room.type == RoomType.START:
			continue
		for cell in room.floor_cells:
			if absi(cell.x - room.center.x) < 3 and absi(cell.y - room.center.y) < 3:
				continue
			if _rng.randf() > 0.04:
				continue
			_props.set_cell(cell, 0, Vector2i(_pick_decor(room.theme), 0))


func _pick_decor(theme_idx: int) -> int:
	var options: Array[int] = [CaveTileset.PROP_PEBBLES, CaveTileset.PROP_RUBBLE, CaveTileset.PROP_BONE]
	match theme_idx:
		0:
			options.append_array([CaveTileset.PROP_ROOTS, CaveTileset.PROP_ROOTS])
		1:
			options.append_array([CaveTileset.PROP_MUSHROOM_PINK, CaveTileset.PROP_MUSHROOM_TEAL, CaveTileset.PROP_MUSHROOM_TEAL])
		2, 3:
			options.append_array([CaveTileset.PROP_EGG, CaveTileset.PROP_EGG, CaveTileset.PROP_MUSHROOM_PINK])
		5:
			options.append_array([CaveTileset.PROP_CRYSTAL_CYAN, CaveTileset.PROP_CRYSTAL_PURPLE, CaveTileset.PROP_CRYSTAL_CYAN])
		6:
			options.append_array([CaveTileset.PROP_EGG, CaveTileset.PROP_CRYSTAL_PURPLE])
		_:
			options.append_array([CaveTileset.PROP_BONE, CaveTileset.PROP_RUBBLE])
	return options[_rng.randi_range(0, options.size() - 1)]


func _build_minimap() -> void:
	var image := Image.create_empty(GRID_SIZE.x, GRID_SIZE.y, false, Image.FORMAT_RGBA8)
	var floor_color := Color(0.78, 0.7, 0.88, 0.9)
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			if _grid[y * GRID_SIZE.x + x] == 1:
				image.set_pixel(x, y, floor_color)
	minimap_texture = ImageTexture.create_from_image(image)
