class_name AoEWarning
extends Node2D
## 地面范围攻击指示器：先红色半透明预警 -> 爆发伤害 -> 销毁。
## 圆形（地面 AoE）或扇形（Boss 扇形斩）。

@export var warn_time: float = 0.8
@export var active_time: float = 0.25
@export var damage: float = 18.0
@export var radius: float = 80.0
@export var is_sector: bool = false
@export var sector_angle: float = PI * 0.6    # 扇形张角
@export var sector_facing: float = 0.0         # 扇形朝向（弧度）
@export var color_warn: Color = Color(1, 0.3, 0.3, 0.35)
@export var color_burst: Color = Color(1, 0.6, 0.2, 0.6)

var _age: float = 0.0
var _phase := "warn"   # warn -> burst -> done
var _hit := false
var _player: Node2D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_age += delta
	if _phase == "warn" and _age >= warn_time:
		_phase = "burst"
		_age = 0.0
		_try_hit()
	elif _phase == "burst" and _age >= active_time:
		queue_free()
		return
	queue_redraw()


func _try_hit() -> void:
	if not is_instance_valid(_player):
		return
	if not _player.has_method("take_damage"):
		return
	var hit := false
	if is_sector:
		var to := _player.global_position - global_position
		var d := to.length()
		if d <= radius:
			var ang := atan2(to.y, to.x)
			var diff := angle_difference(ang, sector_facing)
			if abs(diff) <= sector_angle * 0.5:
				hit = true
	else:
		if global_position.distance_to(_player.global_position) <= radius:
			hit = true
	if hit:
		_player.take_damage(damage)


func _draw() -> void:
	if _phase == "warn":
		_draw_shape(color_warn, false)
	elif _phase == "burst":
		_draw_shape(color_burst, true)


func _draw_shape(col: Color, burst: bool) -> void:
	if is_sector:
		var pts := PackedVector2Array([Vector2.ZERO])
		var segs := 24
		var a0 := sector_facing - sector_angle * 0.5
		for i in segs + 1:
			var a := a0 + sector_angle * float(i) / segs
			pts.append(Vector2(cos(a), sin(a)) * radius)
		draw_colored_polygon(pts, col)
		# 边线
		draw_arc(Vector2.ZERO, radius, a0, a0 + sector_angle, segs, Color(1, 1, 1, 0.5), 1.5)
	else:
		draw_circle(Vector2.ZERO, radius, col)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(1, 1, 1, 0.5), 1.5)
		if burst:
			draw_circle(Vector2.ZERO, radius * 0.6, Color(1, 1, 0.8, 0.4))


static func angle_difference(a: float, b: float) -> float:
	var d := fmod(a - b, TAU)
	if d > PI: d -= TAU
	if d < -PI: d += TAU
	return d
