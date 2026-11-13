extends Control

var creature_name := ""

func setup(value: String) -> void:
	creature_name = value
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var unit := minf(size.x, size.y)
	var ink := Color("#26332d")
	draw_circle(Vector2(c.x, size.y * 0.86), unit * 0.27, Color(0.02, 0.04, 0.03, 0.3))
	match creature_name:
		"Mossling": _draw_mossling(c, unit, ink)
		"Thornback": _draw_thornback(c, unit, ink)
		"Aquafin": _draw_aquafin(c, unit, ink)
		"Barkbeetle": _draw_barkbeetle(c, unit, ink)
		_: draw_circle(c, unit * 0.25, Color("#a8b19c"))

func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), color)

func _draw_mossling(c: Vector2, u: float, ink: Color) -> void:
	var leaf := Color("#78ad63")
	var light_leaf := Color("#b3d67e")
	_triangle(c + Vector2(-u * 0.10, -u * 0.25), c + Vector2(-u * 0.35, -u * 0.58), c + Vector2(-u * 0.02, -u * 0.48), light_leaf)
	_triangle(c + Vector2(u * 0.04, -u * 0.28), c + Vector2(u * 0.34, -u * 0.57), c + Vector2(u * 0.28, -u * 0.24), leaf)
	draw_circle(c + Vector2(0, u * 0.10), u * 0.30, Color("#427553"))
	draw_circle(c + Vector2(0, u * 0.06), u * 0.26, Color("#8bc878"))
	draw_circle(c + Vector2(-u * 0.09, u * 0.02), u * 0.025, ink)
	draw_circle(c + Vector2(u * 0.09, u * 0.02), u * 0.025, ink)
	draw_arc(c + Vector2(0, u * 0.09), u * 0.10, 0.35, 2.8, 12, ink, maxf(1.0, u * 0.018))
	draw_line(c + Vector2(-u * 0.20, u * 0.33), c + Vector2(-u * 0.29, u * 0.44), ink, u * 0.04, true)
	draw_line(c + Vector2(u * 0.20, u * 0.33), c + Vector2(u * 0.29, u * 0.44), ink, u * 0.04, true)

func _draw_thornback(c: Vector2, u: float, ink: Color) -> void:
	var shell := Color("#6f9671")
	for point in [Vector2(-0.25, -0.18), Vector2(-0.36, 0.02), Vector2(-0.27, 0.22), Vector2(0.25, -0.18), Vector2(0.36, 0.02), Vector2(0.27, 0.22)]:
		var p: Vector2 = c + point * u
		_triangle(p + Vector2(-u * 0.09, u * 0.08), p + Vector2(u * 0.02, -u * 0.18), p + Vector2(u * 0.10, u * 0.09), Color("#d4bd83"))
	draw_circle(c + Vector2(0, u * 0.10), u * 0.32, Color("#805b43"))
	draw_circle(c + Vector2(0, u * 0.05), u * 0.27, shell)
	draw_circle(c + Vector2(-u * 0.09, u * 0.07), u * 0.025, ink)
	draw_circle(c + Vector2(u * 0.09, u * 0.07), u * 0.025, ink)
	draw_line(c + Vector2(-u * 0.18, u * 0.36), c + Vector2(-u * 0.25, u * 0.44), ink, u * 0.045, true)
	draw_line(c + Vector2(u * 0.18, u * 0.36), c + Vector2(u * 0.25, u * 0.44), ink, u * 0.045, true)

func _draw_aquafin(c: Vector2, u: float, ink: Color) -> void:
	var blue := Color("#58a9c2")
	var fin := Color("#b2e1dc")
	_triangle(c + Vector2(-u * 0.18, 0), c + Vector2(-u * 0.48, -u * 0.23), c + Vector2(-u * 0.43, u * 0.25), fin)
	_triangle(c + Vector2(u * 0.13, -u * 0.20), c + Vector2(u * 0.26, -u * 0.45), c + Vector2(u * 0.34, -u * 0.14), fin)
	draw_circle(c + Vector2(0, u * 0.08), u * 0.30, Color("#397b9c"))
	draw_circle(c + Vector2(0, u * 0.04), u * 0.25, blue)
	draw_circle(c + Vector2(u * 0.11, 0), u * 0.035, Color("#f5f2d9"))
	draw_circle(c + Vector2(u * 0.12, 0), u * 0.018, ink)
	draw_arc(c + Vector2(u * 0.16, u * 0.12), u * 0.08, 0.4, 2.6, 12, ink, maxf(1.0, u * 0.018))
	draw_line(c + Vector2(-u * 0.04, -u * 0.18), c + Vector2(-u * 0.14, -u * 0.33), fin, u * 0.045, true)

func _draw_barkbeetle(c: Vector2, u: float, ink: Color) -> void:
	var shell := Color("#9a573e")
	var armor := Color("#bf7650")
	for sign in [-1.0, 1.0]:
		draw_line(c + Vector2(sign * u * 0.19, u * 0.18), c + Vector2(sign * u * 0.43, u * 0.38), ink, u * 0.035, true)
		draw_line(c + Vector2(sign * u * 0.20, u * 0.02), c + Vector2(sign * u * 0.45, -u * 0.02), ink, u * 0.035, true)
		draw_line(c + Vector2(sign * u * 0.17, -u * 0.10), c + Vector2(sign * u * 0.40, -u * 0.28), ink, u * 0.035, true)
	_triangle(c + Vector2(-u * 0.12, -u * 0.23), c + Vector2(-u * 0.22, -u * 0.51), c + Vector2(-u * 0.02, -u * 0.28), Color("#d39a61"))
	_triangle(c + Vector2(u * 0.12, -u * 0.23), c + Vector2(u * 0.22, -u * 0.51), c + Vector2(u * 0.02, -u * 0.28), Color("#d39a61"))
	draw_circle(c + Vector2(0, u * 0.12), u * 0.32, ink)
	draw_circle(c + Vector2(0, u * 0.10), u * 0.28, shell)
	draw_circle(c + Vector2(0, -u * 0.16), u * 0.17, armor)
	draw_line(c, c + Vector2(0, u * 0.38), Color("#573b32"), u * 0.018, true)
	draw_circle(c + Vector2(-u * 0.07, -u * 0.18), u * 0.025, Color("#f2d697"))
	draw_circle(c + Vector2(u * 0.07, -u * 0.18), u * 0.025, Color("#f2d697"))
