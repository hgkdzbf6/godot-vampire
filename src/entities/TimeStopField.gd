class_name TimeStopField
extends Node2D
## 主动技能：时停力场。
## 以玩家为中心的圆形力场，范围内敌人被冻结（减速到接近0），持续 3 秒后消失。

@export var radius: float = 260.0
@export var duration: float = 3.0
@export var slow: float = 0.95   # 减速比例（敌人速度乘以 1-slow）

var _age: float = 0.0
var _player: Node2D = null
var _affected: Dictionary = {}   # enemy -> 之前是否受影响（用于恢复）


func _ready() -> void:
	z_index = 40
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		# 恢复敌人速度
		_restore()
		queue_free()
		return
	# 跟随玩家
	if is_instance_valid(_player):
		global_position = _player.global_position
	# 对范围内敌人施加减速（每帧刷新，确保新进入的也生效）
	_apply_slow()
	queue_redraw()


func _apply_slow() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var ep: Vector2 = e.global_position
		if ep.distance_to(global_position) <= radius:
			# 设置减速（直接改 Enemy 的 _frost_time 和 _frost_slow）
			if "_frost_slow" in e:
				e._frost_slow = max(float(e._frost_slow), slow)
			if "_frost_time" in e:
				e._frost_time = 0.2   # 持续刷新，保持减速


func _restore() -> void:
	# 自然恢复：Enemy 的 _frost_time 会自行衰减，无需手动处理
	pass


func _draw() -> void:
	var fade := 1.0 - (_age / duration)
	var pulse := 0.6 + 0.4 * sin(_age * 8.0)
	# 外圈
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color("c8a6ff", 0.6 * fade), 3.0)
	# 填充
	draw_circle(Vector2.ZERO, radius, Color("c8a6ff", 0.08 * fade * pulse))
	# 内圈纹路
	for i in 6:
		var a := TAU * i / 6.0 + _age * 2.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * radius * 0.9, Color("c8a6ff", 0.15 * fade), 1.5)
	# 中心
	draw_circle(Vector2.ZERO, 20, Color("c8a6ff", 0.4 * fade))
