class_name GiantSword
extends Area2D
## 主动技能：巨剑冲撞。
## 一把巨大的剑朝目标方向高速冲撞，沿途撞击敌人造成伤害，持续若干秒后消失。

@export var speed: float = 520.0
@export var damage: float = 60.0
@export var lifetime: float = 10.0
@export var hit_cooldown: float = 0.5

var _dir := Vector2.RIGHT
var _age: float = 0.0
var _spin: float = 0.0
var _hit_cd: Dictionary = {}   # enemy -> 剩余冷却

@onready var _shape: CollisionShape2D = $CollisionShape2D

const ENEMY_LAYER := 2
const BOSS_LAYER := 8


func _ready() -> void:
	collision_layer = 0
	collision_mask = ENEMY_LAYER | BOSS_LAYER
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(direction: Vector2, dmg: float = 0.0) -> void:
	_dir = direction.normalized()
	if dmg > 0:
		damage = dmg


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += _dir * speed * delta
	# 旋转效果
	_spin += delta * 8.0
	rotation = _dir.angle() + PI * 0.5 + sin(_spin) * 0.3
	# 更新命中冷却
	var expired: Array = []
	for k in _hit_cd:
		_hit_cd[k] -= delta
		if _hit_cd[k] <= 0:
			expired.append(k)
	for k in expired:
		_hit_cd.erase(k)


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(node: Node) -> void:
	if not is_instance_valid(node) or not node.has_method("take_damage"):
		return
	if _hit_cd.has(node):
		return
	_hit_cd[node] = hit_cooldown
	node.take_damage(damage, GameData.Element.PHYSICAL, {}, true, self)


func _draw() -> void:
	# 巨型剑（比普通剑大很多）
	var length := 70.0
	var width := 22.0
	var blade := Color("ffd24a")
	# 外发光
	draw_circle(Vector2.ZERO, length * 0.7, Color(blade.r, blade.g, blade.b, 0.2))
	# 剑身
	var tip := Vector2(0, -length)
	var base_l := Vector2(-width * 0.5, length * 0.2)
	var base_r := Vector2(width * 0.5, length * 0.2)
	draw_colored_polygon(PackedVector2Array([tip, base_l, base_r]), blade.blend(Color(1, 1, 1, 0.3)))
	draw_line(base_l, tip, Color(1, 1, 1, 0.9), 2.0)
	draw_line(base_r, tip, Color(1, 1, 1, 0.9), 2.0)
	# 护手
	draw_line(Vector2(-width, length * 0.2), Vector2(width, length * 0.2), Color("d6a632"), 4.0)
	# 剑柄
	draw_rect(Rect2(-3, length * 0.2, 6, length * 0.3), Color("5a4028"))
	# 拖尾光效
	draw_line(Vector2(0, length * 0.5), Vector2(0, length * 1.2), Color(blade.r, blade.g, blade.b, 0.4), 6.0)
