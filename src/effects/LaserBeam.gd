class_name LaserBeam
extends Node2D
## 激光扫射：先蓄力预警（细线）-> 高伤害光束（粗线）-> 消失。
## 围绕一个中心轴在 active 阶段扫射。

@export var warn_time: float = 1.0
@export var active_time: float = 1.4
@export var damage_per_sec: float = 60.0
@export var length: float = 1400.0
@export var width: float = 36.0
@export var sweep_range: float = PI * 0.5     # 扫过的总角度
@export var color_warn: Color = Color(1, 0.4, 0.4, 0.7)
@export var color_beam: Color = Color(1, 0.5, 0.9, 0.85)

var _age: float = 0.0
var _phase := "warn"
var _base_angle: float = 0.0
var _cur_angle: float = 0.0
var _player: Node2D = null
var _dmg_accum: float = 0.0
var _warn_pulse: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func setup(facing: float) -> void:
	_base_angle = facing - sweep_range * 0.5
	_cur_angle = _base_angle


func _process(delta: float) -> void:
	_age += delta
	if _phase == "warn":
		_cur_angle = _base_angle
		if _age >= warn_time:
			_phase = "active"
			_age = 0.0
	elif _phase == "active":
		var t := clampf(_age / active_time, 0.0, 1.0)
		_cur_angle = _base_angle + sweep_range * t
		# 持续伤害
		_apply_damage(delta)
		if _age >= active_time:
			queue_free()
			return
	queue_redraw()


func _apply_damage(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	# 判断玩家是否在激光矩形内：转换到本地坐标
	var to_local: Vector2 = (_player.global_position - global_position).rotated(-_cur_angle)
	if absf(to_local.y) <= width * 0.5 + 10 and to_local.x >= 0 and to_local.x <= length:
		_dmg_accum += damage_per_sec * delta
		if _dmg_accum >= 1.0:
			var d: float = floor(_dmg_accum)
			_dmg_accum -= d
			if _player.has_method("take_damage"):
				_player.take_damage(int(d))


func _draw() -> void:
	if _phase == "warn":
		# 画出完整扫射范围的扇形预警，让玩家清楚知道激光将覆盖的区域
		_warn_pulse += 0.15
		var pulse := 0.6 + 0.4 * sin(_warn_pulse)
		# 扫射范围两端角度
		var a0 := _base_angle
		var a1 := _base_angle + sweep_range
		# 扇形填充（半透明红）
		var pts := PackedVector2Array([Vector2.ZERO])
		var segs := 32
		for i in segs + 1:
			var a: float = lerpf(a0, a1, float(i) / segs)
			pts.append(Vector2(cos(a), sin(a)) * length)
		var fill := Color(color_warn.r, color_warn.g, color_warn.b, 0.18 * pulse)
		draw_colored_polygon(pts, fill)
		# 两条边缘实线（扫射边界）
		var edge_col := Color(color_warn.r, color_warn.g, color_warn.b, 0.85)
		draw_line(Vector2.ZERO, Vector2(cos(a0), sin(a0)) * length, edge_col, 2.5)
		draw_line(Vector2.ZERO, Vector2(cos(a1), sin(a1)) * length, edge_col, 2.5)
		# 外弧
		var arc_pts := PackedVector2Array()
		for i in segs + 1:
			var a: float = lerpf(a0, a1, float(i) / segs)
			arc_pts.append(Vector2(cos(a), sin(a)) * length)
		for i in arc_pts.size() - 1:
			draw_line(arc_pts[i], arc_pts[i + 1], edge_col, 2.0)
		# 当前扫到的指示线（脉动）
		var tip := Vector2(cos(_cur_angle), sin(_cur_angle)) * length
		draw_line(Vector2.ZERO, tip, Color(1, 0.4, 0.4, 0.7 * pulse), 3.0)
		# 中心警示圈
		draw_circle(Vector2.ZERO, width * 0.8, Color(1, 0.5, 0.5, 0.5 * pulse))
	else:
		# 旋转坐标系绘制矩形光束
		var t := Transform2D(_cur_angle, Vector2.ZERO)
		draw_set_transform_matrix(t)
		var half := Vector2(length * 0.5, width * 0.5)
		draw_rect(Rect2(Vector2(0, -half.y), Vector2(length, width)), color_beam)
		# 高亮核心
		draw_rect(Rect2(Vector2(0, -width * 0.15), Vector2(length, width * 0.3)), Color(1, 1, 1, 0.8))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# 起点
		draw_circle(Vector2.ZERO, width * 0.6, Color(1, 0.6, 0.9, 0.8))
