class_name PlayerLaser
extends Node2D
## 主动技能：毁灭激光（玩家发射）。
## 朝指定方向发射持续伤害激光，命中敌人造成高频伤害，持续 3 秒。

@export var damage_per_sec: float = 120.0
@export var duration: float = 3.0
@export var length: float = 1200.0
@export var width: float = 50.0

var _dir := Vector2.RIGHT
var _age: float = 0.0
var _dmg_accum: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	z_index = 50
	_player = get_tree().get_first_node_in_group("player")


func setup(direction: Vector2) -> void:
	_dir = direction.normalized()


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	# 激光始终从主角当前位置发射（跟随玩家移动）
	if is_instance_valid(_player):
		global_position = _player.global_position
	_apply_damage(delta)
	queue_redraw()


func _apply_damage(delta: float) -> void:
	# 对所有在激光矩形内的敌人造成伤害
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		if _is_in_beam(e.global_position):
			_dmg_accum += damage_per_sec * delta
			if _dmg_accum >= 1.0:
				var d: float = floor(_dmg_accum)
				_dmg_accum -= d
				e.take_damage(d, GameData.Element.LIGHTNING, {}, false, self)
	# Boss
	for b in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b) or not b.has_method("take_damage"):
			continue
		if _is_in_beam(b.global_position):
			_dmg_accum += damage_per_sec * delta
			if _dmg_accum >= 1.0:
				var d: float = floor(_dmg_accum)
				_dmg_accum -= d
				b.take_damage(d, GameData.Element.LIGHTNING, {}, false, self)


func _is_in_beam(pos: Vector2) -> bool:
	var to_local: Vector2 = (pos - global_position).rotated(-_dir.angle())
	return absf(to_local.y) <= width * 0.5 + 12 and to_local.x >= 0 and to_local.x <= length


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(_age * 30.0)
	# 旋转坐标系绘制
	var tf := Transform2D(_dir.angle(), Vector2.ZERO)
	draw_set_transform_matrix(tf)
	# 外光晕
	draw_rect(Rect2(0, -width * 0.5, length, width), Color("4a9eff", 0.3 * pulse))
	# 主体
	draw_rect(Rect2(0, -width * 0.3, length, width * 0.6), Color("7be0ff", 0.7 * pulse))
	# 核心
	draw_rect(Rect2(0, -width * 0.12, length, width * 0.24), Color(1, 1, 1, 0.95))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# 起点
	draw_circle(Vector2.ZERO, width * 0.5, Color("7be0ff", 0.6))
