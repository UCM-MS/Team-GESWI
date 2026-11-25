extends Control
class_name NumberLine
## Číselná os (teplomer) – hráč posúva bod šípkami a potvrdí Enterom.

var min_v := -5.0
var max_v := 5.0
var step := 0.5
var value := 0.0
var point_name := "A"
var placed: Array = []   # už umiestnené body: [[meno, hodnota], ...]

const INK := Color("2b1d2e")
const MARK := Color("c8402e")
const DONE := Color("3d6fc4")


func _ready() -> void:
	custom_minimum_size = Vector2(0, 26)


func setup(mn: float, mx: float, st: float, pname: String) -> void:
	min_v = mn
	max_v = mx
	step = st
	point_name = pname
	value = 0.0
	queue_redraw()


func move(dir: int) -> void:
	value = clampf(value + dir * step, min_v, max_v)
	queue_redraw()


func _x(v: float) -> float:
	var pad := 10.0
	return pad + (v - min_v) / (max_v - min_v) * (size.x - 2 * pad)


func _draw() -> void:
	var y := 14.0
	var font := get_theme_default_font()
	draw_line(Vector2(_x(min_v) - 4, y), Vector2(_x(max_v) + 4, y), INK, 1.0)
	var v := min_v
	while v <= max_v + 0.001:
		var x := _x(v)
		var whole := absf(v - roundf(v)) < 0.001
		draw_line(Vector2(x, y - (3 if whole else 1)), Vector2(x, y + (3 if whole else 1)), INK, 1.0)
		if whole:
			var s := str(int(roundf(v))).replace("-", "−")
			draw_string(font, Vector2(x - 3, y + 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, INK)
		v += step
	for p in placed:
		var px := _x(float(p[1]))
		draw_circle(Vector2(px, y), 2.0, DONE)
		draw_string(font, Vector2(px - 2, y - 4), str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, DONE)
	var mx := _x(value)
	draw_circle(Vector2(mx, y), 2.5, MARK)
	draw_string(font, Vector2(mx - 2, y - 5), point_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, MARK)
