class_name UpgradeCard
extends Control
## 升级选项卡片（竖版 320×480）。
##
## 设计原则（参考 Vampire Survivors / Hades）：
## - 严格阅读顺序：图标 → 名称(最大) → 数值 → 描述，玩家 <100ms 看懂。
## - 统一深色底 + 细稀有度边框 + 外发光，仅靠边框/发光/图标色区分品质。
## - 缩放走节点 scale 属性（中心缩放），_draw 始终在 320×480 原始局部坐标绘制，
##   绝不使用 draw_set_transform_matrix（避免位移到框外）。
## - 内容占据卡牌约 70% 高度，紧凑不空旷。

signal selected(index: int)

const CARD_W := 320
const CARD_H := 480
const PADDING := 22.0

var _upgrade: Dictionary = {}
var _index: int = 0
var _rarity: int = UpgradeDefs.Rarity.COMMON
var _rarity_col := Color.WHITE

# 动画状态（全部驱动节点 scale / position，不干扰 _draw 的局部坐标）
var _entry_progress := 0.0       # 入场 0..1
var _entry_delay := 0.0
var _hover_progress := 0.0       # 悬停 0..1
var _press_anim := 0.0           # 点击放大反馈
var _is_hovered := false
var _font: Font = null


func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 暂停期间也要响应（升级面板在 paused 状态下操作）
	process_mode = Node.PROCESS_MODE_ALWAYS
	pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)   # 中心缩放
	_font = ThemeDB.get_default_theme().default_font


func setup(u: Dictionary, idx: int, entry_delay: float = 0.0) -> void:
	_upgrade = u
	_index = idx
	_rarity = UpgradeDefs.rarity_of(u)
	_rarity_col = UpgradeDefs.rarity_color(_rarity)
	_entry_delay = entry_delay
	_entry_progress = 0.0
	scale = Vector2(0.5, 0.5)   # 入场初始小


func _process(delta: float) -> void:
	# 入场（延迟后弹性弹出）
	if _entry_delay > 0:
		_entry_delay -= delta
	else:
		_entry_progress = min(1.0, _entry_progress + delta * 3.0)

	# 悬停插值
	var hover_target := 1.0 if _is_hovered else 0.0
	_hover_progress += (hover_target - _hover_progress) * min(1.0, delta * 14.0)

	# 点击反馈衰减
	if _press_anim > 0:
		_press_anim = max(0.0, _press_anim - delta * 4.0)

	# 组合缩放：入场弹性 × 悬停(放大6%) × 点击(先放大再缩) × UI缩放
	var s := _ease_out_back(_entry_progress)
	if _hover_progress > 0.01:
		s *= 1.0 + 0.06 * _hover_progress
	if _press_anim > 0:
		# 点击瞬间放大到 1.12 再回落
		s *= 1.0 + 0.12 * _press_anim
	s *= UIScale.scale   # 小屏整体放大卡片（含字号/图标）
	scale = Vector2(s, s)

	queue_redraw()


func _on_mouse_entered() -> void:
	_is_hovered = true

func _on_mouse_exited() -> void:
	_is_hovered = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _entry_progress >= 0.85:
			_press_anim = 1.0
			selected.emit(_index)


func trigger_select() -> void:
	_press_anim = 1.0
	selected.emit(_index)


# ============================================================
#  绘制 —— 全部在 (0,0)-(320,480) 局部坐标，绝不出框
# ============================================================
func _draw() -> void:
	var alpha := clampf(_entry_progress * 1.6, 0.0, 1.0)
	var rect := Rect2(0, 0, CARD_W, CARD_H)

	# ---- 外发光（悬停增强，代替粗边框）----
	if _hover_progress > 0.01 or _rarity >= UpgradeDefs.Rarity.RARE:
		var glow_strength := 0.35 + 0.5 * _hover_progress + 0.15 * (float(_rarity) / 4.0)
		var glow := Color(_rarity_col.r, _rarity_col.g, _rarity_col.b, glow_strength * alpha * 0.5)
		# 多层渐隐发光框
		for i in 4:
			var a := glow.a * (1.0 - float(i) / 4.0)
			draw_rect(rect.grow(2.0 + i * 2.0), Color(_rarity_col.r, _rarity_col.g, _rarity_col.b, a), false, 1.5)

	# ---- 阴影 ----
	draw_rect(rect.grow(2), Color(0, 0, 0, 0.5 * alpha), false, 8.0)

	# ---- 卡牌底色：统一深色，仅极轻微稀有度染色 ----
	var bg := Color(0.09, 0.11, 0.16, 0.97 * alpha)
	bg = bg.lerp(Color(_rarity_col.r, _rarity_col.g, _rarity_col.b, bg.a), 0.06)
	draw_rect(rect, bg)

	# ---- 内部高光 / 毛玻璃边缘 ----
	# 顶部高光
	var top_grad := Rect2(0, 0, CARD_W, 80)
	draw_rect(top_grad, Color(1, 1, 1, 0.04 * alpha), true)
	# 细边框（2px，稀有度色）
	draw_rect(rect, Color(_rarity_col.r, _rarity_col.g, _rarity_col.b, alpha), false, 2.0)
	# 内描边高光
	draw_rect(Rect2(3, 3, CARD_W - 6, CARD_H - 6), Color(1, 1, 1, 0.05 * alpha), false, 1.0)

	# ---- 内容区：严格垂直布局，紧凑居中 ----
	# Y 锚点：稀有度 38 → 图标中心 165 → 名称 285 → 数值 345 → 描述 400
	_draw_centered_text(Vector2(CARD_W * 0.5, 42), UpgradeDefs.rarity_name(_rarity),
		16, Color(_rarity_col.r, _rarity_col.g, _rarity_col.b, alpha))

	# 稀有度下细分隔线
	draw_rect(Rect2(CARD_W * 0.3, 60, CARD_W * 0.4, 1.5),
		Color(_rarity_col.r, _rarity_col.g, _rarity_col.b, alpha * 0.5))

	# 图标（大，圆形底盘 + 主题图标，固定在卡牌内）
	_draw_icon(Vector2(CARD_W * 0.5, 158), String(_upgrade.get("icon", "")), 44, alpha)

	# 技能名称（最大字体 34）
	var title_col := Color(1, 0.97, 0.88, alpha)
	_draw_centered_text(Vector2(CARD_W * 0.5, 290), String(_upgrade.get("title", "")), 34, title_col)

	# 强化数值（醒目，比名称小一点但加粗高亮）
	var vstr: String = _upgrade.get("value_str", "")
	var val_col := Color("ffe34a")
	val_col.a = alpha
	_draw_centered_text(Vector2(CARD_W * 0.5, 345), vstr, 28, val_col, true)

	# 描述（最浅最小，可换行，居中）
	var desc: String = _upgrade.get("desc", "")
	_draw_paragraph(Vector2(CARD_W * 0.5, 392), desc, 17,
		Color(0.72, 0.76, 0.85, alpha), CARD_W - PADDING * 2)

	# 底部操作提示
	_draw_centered_text(Vector2(CARD_W * 0.5, CARD_H - 24),
		"按 %d  ·  点击" % (_index + 1), 13,
		Color(0.55, 0.6, 0.68, alpha * 0.9))


# ---- 文本辅助（统一带阴影描边，居中绘制）----
func _draw_centered_text(pos: Vector2, text: String, size: int, col: Color, bold := false) -> void:
	if text.is_empty() or _font == null:
		return
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	var origin := Vector2(pos.x - tw * 0.5, pos.y)
	# 阴影
	draw_string(_font, origin + Vector2(1.5, 1.5), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(0, 0, 0, col.a * 0.75))
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, col)


func _draw_paragraph(top_center: Vector2, text: String, size: int, col: Color, max_w: float) -> void:
	if text.is_empty() or _font == null:
		return
	var lines := _wrap_text(text, size, max_w)
	var y := top_center.y
	for line in lines:
		var tw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		var origin := Vector2(top_center.x - tw * 0.5, y)
		draw_string(_font, origin + Vector2(1, 1), line,
			HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(0, 0, 0, col.a * 0.7))
		draw_string(_font, origin, line, HORIZONTAL_ALIGNMENT_CENTER, -1, size, col)
		y += size + 4


func _wrap_text(text: String, size: int, max_w: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	var cur := ""
	for ch in text:
		var test := cur + ch
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x > max_w and not cur.is_empty():
			lines.append(cur)
			cur = ch
		else:
			cur = test
	if not cur.is_empty():
		lines.append(cur)
	return lines


# ============================================================
#  图标绘制 —— 全部以 center 为圆心，固定半径，绝不使用 transform_matrix
# ============================================================
func _draw_icon(center: Vector2, icon: String, r: float, alpha: float) -> void:
	var col := Color(_rarity_col.r, _rarity_col.g, _rarity_col.b, alpha)
	# 圆形背景盘（带稀有度染色）
	draw_circle(center, r * 1.35, Color(col.r, col.g, col.b, 0.12 * alpha))
	draw_circle(center, r * 1.05, Color(0.05, 0.07, 0.12, 0.5 * alpha))
	draw_arc(center, r * 1.35, 0, TAU, 32, Color(1, 1, 1, 0.15 * alpha), 1.0)

	# 各图标直接在 center 周围画，无旋转矩阵
	match icon:
		"sword":       _icon_sword(center, r, col, PI * 0.25)
		"sword_big":   _icon_sword(center, r * 1.15, col, PI * 0.25)
		"radius":      _icon_radius(center, r, col)
		"spin":        _icon_spin(center, r, col)
		"pierce":      _icon_pierce(center, r, col)
		"crit":        _icon_star(center, r, col)
		"knockback":   _icon_knockback(center, r, col)
		"vampire":     _icon_vampire(center, r, col)
		"fire":        _icon_flame(center, r, col)
		"frost":       _icon_snowflake(center, r, col)
		"lightning":   _icon_lightning(center, r, col)
		"heart":       _icon_heart(center, r, col)
		"shield":      _icon_shield(center, r, col)
		"dodge":       _icon_dodge(center, r, col)
		"boot":        _icon_boot(center, r, col)
		"cross":       _icon_cross(center, r, col)
		_:             draw_circle(center, r * 0.7, col)


# 剑图标：用旋转向量计算顶点，避免 transform_matrix
func _icon_sword(center: Vector2, r: float, col: Color, angle: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))       # 剑身朝向
	var perp := Vector2(-dir.y, dir.x)                # 垂直方向
	var tip := center + dir * r
	var base := center - dir * r * 0.25
	var base_l := base - perp * r * 0.18
	var base_r := base + perp * r * 0.18
	draw_colored_polygon(PackedVector2Array([tip, base_l, base_r]), col.blend(Color(1, 1, 1, 0.25)))
	draw_line(base_l, tip, Color(1, 1, 1, 0.85), 1.5)
	# 护手
	var gl := base - perp * r * 0.42
	var gr := base + perp * r * 0.42
	draw_line(gl, gr, Color("d6a632"), 3.0)
	# 剑柄
	draw_line(base, base - dir * r * 0.45, Color("5a4028"), 3.0)


func _icon_radius(center: Vector2, r: float, col: Color) -> void:
	# 中心点 + 三把环绕小剑
	draw_circle(center, r * 0.15, col)
	draw_arc(center, r * 0.62, 0, TAU, 32, Color(1, 1, 1, 0.25 * col.a), 1.0)
	for i in 3:
		var a := TAU * i / 3.0 - PI * 0.5
		var c := center + Vector2(cos(a), sin(a)) * r * 0.62
		_icon_sword(c, r * 0.32, col, a + PI * 0.5)


func _icon_spin(center: Vector2, r: float, col: Color) -> void:
	# 螺旋箭头
	var end_a := TAU * 1.4
	var segs := 24
	var prev := center
	for i in segs:
		var t := float(i) / segs
		var a := end_a * t
		var p := center + Vector2(cos(a), sin(a)) * r * 0.85
		if i > 0:
			draw_line(prev, p, col, 4.0)
		prev = p
	draw_circle(prev, 5, col)


func _icon_pierce(center: Vector2, r: float, col: Color) -> void:
	_icon_sword(center, r, col, PI * 0.25)
	# 穿透点（沿剑身方向的小圆）
	for i in 3:
		var t := -0.5 + i * 0.45
		var p := center + Vector2(cos(PI*0.25), sin(PI*0.25)) * r * t
		draw_circle(p, 3.5, Color("ffd24a"))


func _icon_star(center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		var rr := r * 0.9 if i % 2 == 0 else r * 0.4
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


func _icon_knockback(center: Vector2, r: float, col: Color) -> void:
	for i in 4:
		var a := TAU * i / 4.0
		var p1 := center + Vector2(cos(a), sin(a)) * r * 0.3
		var p2 := center + Vector2(cos(a), sin(a)) * r * 0.9
		draw_line(p1, p2, col, 4.0)
		draw_line(p2, p2 + Vector2(cos(a + 2.4), sin(a + 2.4)) * 9, col, 3.0)
		draw_line(p2, p2 + Vector2(cos(a - 2.4), sin(a - 2.4)) * 9, col, 3.0)


func _icon_vampire(center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(0, -r * 0.85),
		center + Vector2(r * 0.6, 0),
		center + Vector2(0, r * 0.95),
		center + Vector2(-r * 0.6, 0),
	])
	draw_colored_polygon(pts, Color("d63b3b"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.6 * col.a), 1.5)
	# 高光
	draw_circle(center + Vector2(-r * 0.2, -r * 0.2), r * 0.12, Color(1, 1, 1, 0.5))


func _icon_flame(center: Vector2, r: float, col: Color) -> void:
	var outer := PackedVector2Array([
		center + Vector2(0, -r * 0.95),
		center + Vector2(r * 0.55, -r * 0.1),
		center + Vector2(r * 0.4, r * 0.55),
		center + Vector2(0, r * 0.85),
		center + Vector2(-r * 0.4, r * 0.55),
		center + Vector2(-r * 0.55, -r * 0.1),
	])
	draw_colored_polygon(outer, col)
	var inner := PackedVector2Array([
		center + Vector2(0, -r * 0.45),
		center + Vector2(r * 0.25, 0),
		center + Vector2(r * 0.18, r * 0.4),
		center + Vector2(0, r * 0.55),
		center + Vector2(-r * 0.18, r * 0.4),
		center + Vector2(-r * 0.25, 0),
	])
	draw_colored_polygon(inner, Color(1, 0.9, 0.5))


func _icon_snowflake(center: Vector2, r: float, col: Color) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		var p2 := center + Vector2(cos(a), sin(a)) * r * 0.85
		draw_line(center, p2, col, 3.0)
		var branch_base := center + Vector2(cos(a), sin(a)) * r * 0.45
		draw_line(branch_base, branch_base + Vector2(cos(a + 1.0), sin(a + 1.0)) * r * 0.22, col, 2.0)
		draw_line(branch_base, branch_base + Vector2(cos(a - 1.0), sin(a - 1.0)) * r * 0.22, col, 2.0)


func _icon_lightning(center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-r * 0.3, -r * 0.9),
		center + Vector2(r * 0.4, -r * 0.9),
		center + Vector2(-r * 0.05, -r * 0.1),
		center + Vector2(r * 0.45, -r * 0.1),
		center + Vector2(-r * 0.3, r * 0.95),
		center + Vector2(r * 0.05, r * 0.1),
		center + Vector2(-r * 0.4, r * 0.1),
	])
	draw_polyline(pts, Color("ffe34a"), 5.0)


func _icon_heart(center: Vector2, r: float, col: Color) -> void:
	draw_circle(center + Vector2(-r * 0.3, -r * 0.2), r * 0.42, col)
	draw_circle(center + Vector2(r * 0.3, -r * 0.2), r * 0.42, col)
	var tp := PackedVector2Array([
		center + Vector2(-r * 0.68, -r * 0.05),
		center + Vector2(r * 0.68, -r * 0.05),
		center + Vector2(0, r * 0.85),
	])
	draw_colored_polygon(tp, col)


func _icon_shield(center: Vector2, r: float, col: Color) -> void:
	var sp := PackedVector2Array([
		center + Vector2(-r * 0.7, -r * 0.7),
		center + Vector2(r * 0.7, -r * 0.7),
		center + Vector2(r * 0.6, r * 0.5),
		center + Vector2(0, r * 0.9),
		center + Vector2(-r * 0.6, r * 0.5),
	])
	draw_colored_polygon(sp, col)
	draw_polyline(sp + PackedVector2Array([sp[0]]), Color(0, 0, 0, 0.5 * col.a), 2.0)
	# 十字
	draw_line(center + Vector2(0, -r * 0.4), center + Vector2(0, r * 0.4), Color(0.1, 0.1, 0.15, col.a), 3.0)
	draw_line(center + Vector2(-r * 0.3, 0), center + Vector2(r * 0.3, 0), Color(0.1, 0.1, 0.15, col.a), 3.0)


func _icon_dodge(center: Vector2, r: float, col: Color) -> void:
	# 闪光（四芒星）
	var pts := PackedVector2Array([
		center + Vector2(0, -r * 0.9),
		center + Vector2(r * 0.2, -r * 0.2),
		center + Vector2(r * 0.9, 0),
		center + Vector2(r * 0.2, r * 0.2),
		center + Vector2(0, r * 0.9),
		center + Vector2(-r * 0.2, r * 0.2),
		center + Vector2(-r * 0.9, 0),
		center + Vector2(-r * 0.2, -r * 0.2),
	])
	draw_colored_polygon(pts, col)


func _icon_boot(center: Vector2, r: float, col: Color) -> void:
	var bp := PackedVector2Array([
		center + Vector2(-r * 0.3, -r * 0.8),
		center + Vector2(r * 0.3, -r * 0.8),
		center + Vector2(r * 0.3, r * 0.2),
		center + Vector2(r * 0.75, r * 0.7),
		center + Vector2(-r * 0.75, r * 0.7),
	])
	draw_colored_polygon(bp, col)
	draw_polyline(bp + PackedVector2Array([bp[0]]), Color(0, 0, 0, 0.4 * col.a), 2.0)


func _icon_cross(center: Vector2, r: float, col: Color) -> void:
	draw_rect(Rect2(center.x - 7, center.y - r * 0.7, 14, r * 1.4), col)
	draw_rect(Rect2(center.x - r * 0.5, center.y - 7, r, 14), col)


# ---- 缓动 ----
func _ease_out_back(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
