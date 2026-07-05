class_name SkillBar
extends Control
## 主动技能栏（HUD 底部中央）。
## 显示 3 个技能：未解锁（灰色锁）、已解锁有次数（彩色+次数）、冷却中（遮罩）、无次数（暗）。

const SKILLS := [
	{"id": "sword", "label": "Q", "name": "巨剑冲撞", "color": "#ffd24a"},
	{"id": "laser", "label": "E", "name": "毁灭激光", "color": "#7be0ff"},
	{"id": "timestop", "label": "空格", "name": "时停力场", "color": "#c8a6ff"},
]

var _unlocked: Dictionary = {"sword": false, "laser": false, "timestop": false}
var _charges: Dictionary = {"sword": 0, "laser": 0, "timestop": 0}
var _cooldowns: Dictionary = {"sword": 0.0, "laser": 0.0, "timestop": 0.0}
var _totals: Dictionary = {"sword": 6.0, "laser": 5.0, "timestop": 8.0}


func _ready() -> void:
	# 应用 UI 缩放（递归缩放所有子控件的字号）
	UIScale.apply_font_scale(self)
	UIScale.scale_changed.connect(func(_s): UIScale.apply_font_scale(self))
	GameEvents.skill_state_changed.connect(_on_state_changed)
	# 触屏设备由 TouchInput 提供更大的技能按钮，桌面端才显示底部 SkillBar
	if UIScale.is_touchscreen:
		visible = false
		set_process(false)


func _on_state_changed(skill_id: String, unlocked: bool, charges: int, cd_remaining: float, cd_total: float) -> void:
	_unlocked[skill_id] = unlocked
	_charges[skill_id] = charges
	_cooldowns[skill_id] = cd_remaining
	_totals[skill_id] = cd_total
	queue_redraw()


func _draw() -> void:
	var box := 64
	var gap := 14
	var total_w := SKILLS.size() * box + (SKILLS.size() - 1) * gap
	var start_x := (size.x - total_w) * 0.5
	var y := size.y - box - 18.0
	var font := get_theme_default_font()
	for i in SKILLS.size():
		var s: Dictionary = SKILLS[i]
		var x: float = start_x + i * (box + gap)
		var rect := Rect2(x, y, box, box)
		var col := Color.from_string(s.color, Color.WHITE)
		var unlocked: bool = _unlocked.get(s.id, false)
		var charges: int = _charges.get(s.id, 0)
		var cd: float = _cooldowns.get(s.id, 0.0)
		var total: float = _totals.get(s.id, 1.0)
		var ready: bool = unlocked and charges > 0 and cd <= 0.0

		# 背景框
		draw_rect(rect, Color(0.06, 0.08, 0.13, 0.92), true)
		# 边框：未解锁灰色，就绪亮色，否则暗
		if not unlocked:
			draw_rect(rect, Color(0.3, 0.3, 0.32, 0.7), false, 2.0)
		elif ready:
			draw_rect(rect, Color(col.r, col.g, col.b, 0.95), false, 2.0)
		else:
			draw_rect(rect, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.5), false, 2.0)

		# 图标或锁定
		var center := rect.position + rect.size * 0.5
		if not unlocked:
			_draw_lock(center, Color(0.45, 0.45, 0.5))
		else:
			_draw_icon(center, s.id, col, ready)

		# 冷却遮罩
		if unlocked and cd > 0.0:
			var ratio: float = cd / total
			var mask_h: float = box * ratio
			draw_rect(Rect2(x, y, box, mask_h), Color(0, 0, 0, 0.65))

		# 按键标签
		draw_string(font, Vector2(x + 5, y + 15), s.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))

		# 次数 / 冷却数字
		if not unlocked:
			# 显示锁定
			pass
		elif cd > 0.0:
			var cd_str := "%.0f" % cd
			var tw := font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
			draw_string(font, center + Vector2(-tw * 0.5, 6), cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(1, 0.9, 0.5))
		elif charges > 0:
			# 显示剩余次数
			var cs := "×%d" % charges
			var tw2 := font.get_string_size(cs, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
			draw_string(font, Vector2(rect.end.x - tw2 - 4, rect.end.y - 4), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col.r, col.g, col.b, 0.95))


func _draw_lock(center: Vector2, col: Color) -> void:
	# 锁体
	draw_rect(Rect2(center.x - 8, center.y - 2, 16, 12), col)
	# 锁环
	draw_arc(center + Vector2(0, -4), 6, PI, TAU, 12, col, 2.0)


func _draw_icon(center: Vector2, sid: String, col: Color, ready: bool) -> void:
	var a := 1.0 if ready else 0.5
	var c := Color(col.r, col.g, col.b, a)
	match sid:
		"sword":
			draw_line(center + Vector2(-10, 10), center + Vector2(10, -10), c, 3.0)
			draw_line(center + Vector2(-12, 4), center + Vector2(-4, 12), c, 2.0)
		"laser":
			draw_rect(Rect2(center.x - 14, center.y - 3, 28, 6), c)
			draw_circle(center, 5, c)
		"timestop":
			draw_arc(center, 11, 0, TAU, 20, c, 2.0)
			draw_line(center, center + Vector2(0, -7), c, 2.0)
			draw_line(center, center + Vector2(5, 2), c, 2.0)
