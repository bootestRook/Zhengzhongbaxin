class_name DefenseNavigation
extends RefCounted

class Grid extends AStarGrid2D:
	var occupancy: Dictionary = {}
	func _compute_cost(from: Vector2i, to: Vector2i) -> float:
		return Vector2(from).distance_to(Vector2(to)) + mini(4, int(occupancy.get(to, 0)))
	func _estimate_cost(from: Vector2i, to: Vector2i) -> float:
		return Vector2(from).distance_to(Vector2(to))

var w
var grid = Grid.new()

func _init(world) -> void:
	w = world
	grid.region = Rect2i(7, 0, 19, 29)
	grid.cell_size = Vector2(50, 50)
	grid.offset = Vector2(25, 25)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	grid.update()

func rebuild() -> void:
	grid.occupancy.clear()
	for u: Dictionary in w.units.values():
		if not u.dead:
			var key = cell(u.pos)
			grid.occupancy[key] = int(grid.occupancy.get(key, 0)) + (2 if u.kind == "hero" else 1)

static func cell(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(pos.x / 50), 7, 25), clampi(floori(pos.y / 50), 0, 28))

func toward(u: Dictionary, destination: Vector2) -> Vector2:
	var goal = cell(destination)
	if w.time_ms >= int(u.get("path_at", 0)) or u.get("path_goal", Vector2i(-1, -1)) != goal:
		u["path"] = grid.get_id_path(cell(u.pos), goal)
		u["path_index"] = 1
		u["path_goal"] = goal
		u["path_at"] = w.time_ms + (200 if u.kind in ["hero", "boss"] else 500)
	var path: Array = u.path
	var index: int = u.path_index
	if index < path.size() and cell(u.pos) == path[index]:
		index += 1
		u.path_index = index
	if index < path.size():
		return Vector2(path[index]) * 50 + Vector2(25, 25)
	return destination
