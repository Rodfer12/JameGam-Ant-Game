extends TileMapLayer
class_name AnthillGenerator

## Generates one connected anthill on this TileMapLayer.
##
## The layout is deliberately kept separate from rendering:
## 1. Room rectangles and their neighbor graph are created.
## 2. Air cells are carved into a dictionary.
## 3. Air is written first, then every remaining cell is written as a wall.
##
## Change the constants below to tune the network without touching gameplay.

class Room:
	var id: String
	var rect: Rect2i
	var neighbors: Array[Room] = []

	func _init(room_id: String, room_rect: Rect2i) -> void:
		id = room_id
		rect = room_rect

	func center() -> Vector2:
		return Vector2(rect.position) + Vector2(rect.size) * 0.5

const GRID_SIZE := Vector2i(96, 64)
const TILE_SIZE := 16
const ROOM_PADDING := 1
const TUNNEL_WIDTH := 3
const ROOM_EDGE_VARIATION := 0.18

const AIR_SOURCE_ID := 0
const AIR_ATLAS := Vector2i(1, 3)
const WALL_SOURCE_ID := 0
const WALL_ATLAS := Vector2i(2, 11)

var rooms: Array[Room] = []
var layout: Dictionary = {}
var random := RandomNumberGenerator.new()

func _ready() -> void:
	generate(1337)

func generate(seed_value: int = 1337) -> void:
	random.seed = seed_value
	rooms.clear()
	layout.clear()
	_clear_layout()
	_create_rooms()
	_connect_rooms()
	_carve_room_air()
	_carve_tunnel_air()
	_write_layout()

func get_rooms() -> Array[Room]:
	return rooms

func is_wall_at_world(world_position: Vector2, radius: float = 0.0) -> bool:
	var min_cell := _world_to_cell(world_position - Vector2.ONE * radius)
	var max_cell := _world_to_cell(world_position + Vector2.ONE * radius)
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			if _is_wall_cell(Vector2i(x, y)):
				return true
	return false

func room_at_world(world_position: Vector2) -> Room:
	var cell := _world_to_cell(world_position)
	for room in rooms:
		if room.rect.grow(ROOM_PADDING).has_point(cell):
			return room
	return null

func room_index_at_world(world_position: Vector2) -> int:
	var room := room_at_world(world_position)
	return rooms.find(room)

func world_center(room: Room) -> Vector2:
	return (room.center() + Vector2.ONE * 0.5) * TILE_SIZE

func world_size() -> Vector2:
	return Vector2(GRID_SIZE) * TILE_SIZE

func _create_rooms() -> void:
	rooms = [
		Room.new("entry", Rect2i(4, 25, 12, 10)),
		Room.new("food_storage", Rect2i(19, 10, 13, 10)),
		Room.new("nursery", Rect2i(38, 7, 13, 10)),
		Room.new("worker_nest", Rect2i(9, 43, 13, 10)),
		Room.new("scarlet_vein", Rect2i(27, 30, 13, 10)),
		Room.new("crystal_warren", Rect2i(55, 20, 13, 10)),
		Room.new("mushroom_grotto", Rect2i(73, 8, 13, 10)),
		Room.new("old_nursery", Rect2i(48, 43, 14, 10)),
		Room.new("queen_antechamber", Rect2i(70, 32, 14, 10)),
		Room.new("queens_chamber", Rect2i(78, 51, 14, 10))
	]

func _connect_rooms() -> void:
	_link_rooms(rooms[0], rooms[1])
	_link_rooms(rooms[1], rooms[2])
	_link_rooms(rooms[0], rooms[3])
	_link_rooms(rooms[1], rooms[3])
	_link_rooms(rooms[1], rooms[4])
	_link_rooms(rooms[2], rooms[4])
	_link_rooms(rooms[2], rooms[5])
	_link_rooms(rooms[5], rooms[6])
	_link_rooms(rooms[4], rooms[7])
	_link_rooms(rooms[5], rooms[7])
	_link_rooms(rooms[6], rooms[8])
	_link_rooms(rooms[7], rooms[8])
	_link_rooms(rooms[8], rooms[9])

func _link_rooms(first: Room, second: Room) -> void:
	if not first.neighbors.has(second):
		first.neighbors.append(second)
	if not second.neighbors.has(first):
		second.neighbors.append(first)

func _carve_room_air() -> void:
	for room in rooms:
		var center := room.center()
		var radii := Vector2(room.rect.size) * 0.5
		for x in range(room.rect.position.x, room.rect.end.x):
			for y in range(room.rect.position.y, room.rect.end.y):
				var normalized := (Vector2(x, y) + Vector2.ONE * 0.5 - center) / radii
				var edge_noise := random.randf_range(-ROOM_EDGE_VARIATION, ROOM_EDGE_VARIATION)
				if normalized.length() <= 1.0 + edge_noise:
					_set_air(Vector2i(x, y))

func _carve_tunnel_air() -> void:
	var carved_pairs: Dictionary = {}
	for room in rooms:
		for neighbor in room.neighbors:
			var pair_key := room.id + ":" + neighbor.id if room.id < neighbor.id else neighbor.id + ":" + room.id
			if carved_pairs.has(pair_key):
				continue
			carved_pairs[pair_key] = true
			_carve_meandering_tunnel(room.center(), neighbor.center())

func _carve_meandering_tunnel(start: Vector2, target: Vector2) -> void:
	var current := Vector2i(start)
	var target_cell := Vector2i(target)
	var safety := GRID_SIZE.x * GRID_SIZE.y * 2
	while current != target_cell and safety > 0:
		safety -= 1
		_carve_tunnel_disc(current)
		var horizontal_distance := target_cell.x - current.x
		var vertical_distance := target_cell.y - current.y
		var move_horizontal: bool = abs(horizontal_distance) >= abs(vertical_distance)
		if random.randf() < 0.28:
			move_horizontal = not move_horizontal
		if move_horizontal and horizontal_distance != 0:
			current.x += 1 if horizontal_distance > 0 else -1
		elif vertical_distance != 0:
			current.y += 1 if vertical_distance > 0 else -1
		elif horizontal_distance != 0:
			current.x += 1 if horizontal_distance > 0 else -1
		current.x = clampi(current.x, 1, GRID_SIZE.x - 2)
		current.y = clampi(current.y, 1, GRID_SIZE.y - 2)
	_carve_tunnel_disc(target_cell)

func _carve_tunnel_disc(center: Vector2i) -> void:
	var half_width := TUNNEL_WIDTH / 2
	for x in range(center.x - half_width, center.x + half_width + 1):
		for y in range(center.y - half_width, center.y + half_width + 1):
			if Vector2i(x, y).distance_to(center) <= float(half_width) + 0.5:
				_set_air(Vector2i(x, y))

func _set_air(cell: Vector2i) -> void:
	if _is_inside_grid(cell):
		layout[cell] = false

func _is_wall_cell(cell: Vector2i) -> bool:
	return not layout.has(cell) or bool(layout[cell])

func _clear_layout() -> void:
	clear()
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			layout[Vector2i(x, y)] = true

func _write_layout() -> void:
	for cell in layout:
		if not bool(layout[cell]):
			set_cell(cell, AIR_SOURCE_ID, AIR_ATLAS)
	for cell in layout:
		if bool(layout[cell]):
			set_cell(cell, WALL_SOURCE_ID, WALL_ATLAS)

func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))

func _is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE.x and cell.y >= 0 and cell.y < GRID_SIZE.y
