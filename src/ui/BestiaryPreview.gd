class_name BestiaryPreview
extends Control
## 图鉴用的怪物形状预览（小型，复用敌人的形状绘制）。

var shape: String = "square"
var color: Color = Color.WHITE
var elite: bool = false
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	var col := color
	var outline := col.darkened(0.5)
	# 底盘
	draw_circle(center, r * 1.4, Color(col.r, col.g, col.b, 0.15))
	# 轻微浮动
	var bob := sin(_t * 2.0) * 2.0
	var c := center + Vector2(0, bob)
	match shape:
		"square":   _shape_square(c, r, col, outline)
		"triangle": _shape_triangle(c, r, col, outline)
		"diamond":  _shape_diamond(c, r, col, outline)
		"ghost":    _shape_ghost(c, r, col, outline)
		"star":     _shape_star(c, r, col, outline)
		"boss":     _shape_boss(c, r, col, outline)
		_:          _shape_square(c, r, col, outline)


func _shape_square(c: Vector2, r: float, col: Color, outline: Color) -> void:
	var rect := Rect2(c.x - r, c.y - r, r * 2, r * 2)
	draw_rect(rect, col)
	draw_rect(rect, outline, false, 2.0)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.16, Color("ffd24a"))
	draw_circle(c + Vector2(r * 0.35, -r * 0.1), r * 0.16, Color("ffd24a"))


func _shape_triangle(c: Vector2, r: float, col: Color, outline: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, r*0.9), c + Vector2(-r, -r*0.8), c + Vector2(r, -r*0.8)])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 2.0)
	draw_circle(c + Vector2(-r*0.3, -r*0.2), r*0.14, Color("0a0a0a"))
	draw_circle(c + Vector2(r*0.3, -r*0.2), r*0.14, Color("0a0a0a"))


func _shape_diamond(c: Vector2, r: float, col: Color, outline: Color) -> void:
	var pts := PackedVector2Array([c+Vector2(0,-r), c+Vector2(r*0.75,0), c+Vector2(0,r), c+Vector2(-r*0.75,0)])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 2.0)
	draw_circle(c + Vector2(-r*0.25, -r*0.15), r*0.12, Color("ffd24a"))
	draw_circle(c + Vector2(r*0.25, -r*0.15), r*0.12, Color("ffd24a"))


func _shape_ghost(c: Vector2, r: float, col: Color, outline: Color) -> void:
	var pts := PackedVector2Array()
	var segs := 14
	for i in segs + 1:
		var a := PI + PI * float(i) / segs
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(c + Vector2(r * 0.5, r * 0.7))
	pts.append(c + Vector2(r * 0.2, r * 0.95))
	pts.append(c + Vector2(-r * 0.1, r * 0.7))
	pts.append(c + Vector2(-r * 0.4, r * 0.95))
	pts.append(c + Vector2(-r * 0.7, r * 0.7))
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 2.0)
	draw_circle(c + Vector2(-r*0.3, -r*0.15), r*0.16, Color("1a0a1a"))
	draw_circle(c + Vector2(r*0.3, -r*0.15), r*0.16, Color("1a0a1a"))


func _shape_star(c: Vector2, r: float, col: Color, outline: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI*0.5 + TAU*i/10.0
		var rr := r * 1.05 if i % 2 == 0 else r * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 2.5)
	draw_circle(c, r * 0.26, Color("ffe34a"))
	draw_circle(c, r * 0.14, Color.WHITE)


func _shape_boss(c: Vector2, r: float, col: Color, outline: Color) -> void:
	# Boss：大圆 + 王冠/角 + 红眼
	draw_circle(c, r * 1.1, col)
	draw_arc(c, r * 1.1, 0, TAU, 24, outline, 2.5)
	# 王冠（三个尖角）
	for i in 3:
		var a := -PI * 0.5 + (i - 1) * 0.5
		var p := c + Vector2(cos(a), sin(a)) * r * 1.1
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-r * 0.18, 0),
			p + Vector2(r * 0.18, 0),
			p + Vector2(0, -r * 0.4),
		]), Color("d6a6ff"))
	# 红眼
	draw_circle(c + Vector2(-r * 0.3, -r * 0.05), r * 0.16, Color("ff3a3a"))
	draw_circle(c + Vector2(r * 0.3, -r * 0.05), r * 0.16, Color("ff3a3a"))
