class_name Drawing
extends RefCounted
## 代码绘制图形的辅助函数，避免依赖任何外部素材。

## 在给定 CanvasItem 上绘制带描边的实心圆。
static func draw_disc(item: CanvasItem, radius: float, fill: Color, outline := Color.BLACK, outline_w := 0.0) -> void:
	item.draw_circle(Vector2.ZERO, radius, fill)
	if outline_w > 0.0:
		item.draw_arc(Vector2.ZERO, radius, 0, TAU, 36, outline, outline_w, true)


## 绘制一个剑形三角形（带柄），指向上方(-y)。
static func draw_sword(item: CanvasItem, length: float, width: float, blade: Color, edge := Color.WHITE) -> void:
	var half := width * 0.5
	var tip := Vector2(0, -length)             # 剑尖
	var base_l := Vector2(-half, 0.0)          # 剑身根部左
	var base_r := Vector2(half, 0.0)
	var pommel := Vector2(0, length * 0.18)    # 剑柄底
	var guard_l := Vector2(-half * 1.6, 0.0)
	var guard_r := Vector2(half * 1.6, 0.0)

	item.draw_polygon(
		PackedVector2Array([tip, base_l, base_r]),
		PackedColorArray([blade.blend(Color(1, 1, 1, 0.25)), blade, blade])
	)
	# 高光边
	item.draw_line(base_l, tip, edge, 1.0)
	item.draw_line(base_r, tip, edge, 1.0)
	# 护手
	item.draw_line(guard_l, guard_r, Color(0.92, 0.78, 0.32), 2.0)
	# 剑柄
	item.draw_line(Vector2.ZERO, pommel, Color(0.55, 0.4, 0.25), 2.0)


## 绘制矩形（中心在原点）。
static func draw_rect_centered(item: CanvasItem, half: Vector2, fill: Color) -> void:
	item.draw_rect(Rect2(-half, half * 2.0), fill)


## 绘制圆角矩形（中心在原点）。
static func draw_round_rect(item: CanvasItem, half: Vector2, fill: Color, radius := 8.0) -> void:
	var rect := Rect2(-half, half * 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	item.draw_set_transform(rect.position, 0, rect.size)
	item.draw_style_box(style, Rect2(Vector2.ZERO, Vector2.ONE))
	item.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
