class_name Bullet
extends Area2D
## 通用飞行物：Boss 弹幕 / 玩家方向子弹。命中玩家造成伤害后销毁。

@export var speed: float = 220.0
@export var damage: float = 8.0
@export var lifetime: float = 6.0
@export var radius: float = 8.0
@export var bullet_color: Color = Color("ff5a5a")
@export var homing: float = 0.0      # 0=直线，>0 转向玩家

var _dir := Vector2.RIGHT
var _age := 0.0
var _player: Node2D = null

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 16        # bullet 层
	collision_mask = 1          # 只命中玩家
	body_entered.connect(_on_body_entered)
	(_shape.shape as CircleShape2D).radius = radius
	_player = get_tree().get_first_node_in_group("player")


func setup(direction: Vector2, p_speed: float = 0.0, p_damage: float = 0.0, p_color: Color = Color(), p_homing: float = 0.0) -> void:
	_dir = direction.normalized()
	if p_speed > 0: speed = p_speed
	if p_damage > 0: damage = p_damage
	if p_color != Color(): bullet_color = p_color
	homing = p_homing


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if homing > 0 and is_instance_valid(_player):
		var desired := (_player.global_position - global_position).normalized()
		_dir = _dir.lerp(desired, clampf(homing * delta, 0.0, 1.0)).normalized()
	global_position += _dir * speed * delta
	rotation = _dir.angle()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()


func _draw() -> void:
	# 尖头能量弹：细长三角箭头 + 拖尾，与圆形怪物明显区分
	# 尖端朝向运动方向（+x），rotation 已在 _physics_process 设为 _dir.angle()
	var r := radius
	var tail := r * 2.6
	# 拖尾（渐隐三角）
	var tail_pts := PackedVector2Array([
		Vector2(-r * 0.6, 0),
		Vector2(-tail, -r * 0.3),
		Vector2(-tail, r * 0.3),
	])
	draw_colored_polygon(tail_pts, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.25))
	# 主体箭头（菱形 + 尖头）
	var body_pts := PackedVector2Array([
		Vector2(r * 1.2, 0),       # 尖头
		Vector2(r * 0.2, r * 0.7),
		Vector2(-r * 0.8, 0),
		Vector2(r * 0.2, -r * 0.7),
	])
	draw_colored_polygon(body_pts, bullet_color)
	draw_polyline(body_pts + PackedVector2Array([body_pts[0]]), Color(1, 1, 1, 0.9), 1.2)
	# 核心高光
	draw_circle(Vector2(-r * 0.1, 0), r * 0.25, Color(1, 1, 1, 0.85))
