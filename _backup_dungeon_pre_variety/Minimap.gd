extends Control
## Minimap.gd — tiny map of the dungeon (top-right). Only rooms you have visited (and the
## rooms next to them) are shown. Locked doors are drawn in their key colour.

var game
var dungeon

const CELL := Vector2(30.0, 20.0)
const GAP := 5.0


func _process(_delta: float) -> void:
	queue_redraw()


func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x), float(cell.y)) * (CELL + Vector2(GAP, GAP))


func _draw() -> void:
	if game == null or dungeon == null:
		return
	var visited: Dictionary = game.visited
	var current: String = game.current_room
	var shown: Dictionary = {}
	for id in visited:
		shown[id] = true
	for d in dungeon.DOORS:
		var a: String = d["a"]
		var b: String = d["b"]
		if visited.has(a):
			shown[b] = true
		if visited.has(b):
			shown[a] = true
	draw_rect(Rect2(Vector2(-6, -6), Vector2(4.0 * (CELL.x + GAP) + 7.0, 2.0 * (CELL.y + GAP) + 7.0)), Color(0, 0, 0, 0.45))
	for d in dungeon.DOORS:
		var a: String = d["a"]
		var b: String = d["b"]
		if not (shown.has(a) and shown.has(b)):
			continue
		var pa: Vector2 = _cell_pos(dungeon.cell_of(a)) + CELL * 0.5
		var pb: Vector2 = _cell_pos(dungeon.cell_of(b)) + CELL * 0.5
		var col: Color = Color(0.6, 0.6, 0.65)
		var key: String = d["key"]
		if key == "bronze":
			col = Color(0.85, 0.5, 0.22)
		elif key == "gold":
			col = Color(1.0, 0.82, 0.25)
		draw_line(pa, pb, col, 3.0)
	for id in shown:
		var p: Vector2 = _cell_pos(dungeon.cell_of(id))
		var seen: bool = visited.has(id)
		var fill: Color = Color(0.32, 0.34, 0.45, 0.95) if seen else Color(0.14, 0.15, 0.2, 0.8)
		if id == "F":
			fill = Color(0.5, 0.12, 0.14, 0.95) if seen else Color(0.28, 0.08, 0.1, 0.8)
		draw_rect(Rect2(p, CELL), fill)
		draw_rect(Rect2(p, CELL), Color(0.75, 0.75, 0.85, 0.6), false, 1.0)
		if id == current:
			draw_rect(Rect2(p, CELL).grow(1.5), Color(1.0, 0.9, 0.4), false, 2.0)
			draw_circle(p + CELL * 0.5, 3.5, Color(1.0, 0.9, 0.4))
