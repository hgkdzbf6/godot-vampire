class_name Sword
extends Area2D
## 单把环绕剑。负责绘制与命中检测，伤害结算委托给 SwordManager。

var _mgr: SwordManager = null
var _index: int = 0
# 同一敌人的命中冷却：enemy_id(inst) -> 剩余时间
var _hit_cd: Dictionary = {}

@onready var _shape: CollisionShape2D = $CollisionShape2D

const ENEMY_LAYER := 2
const BOSS_LAYER := 8


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = ENEMY_LAYER | BOSS_LAYER
	# 从配置应用命中碰撞胶囊尺寸（更大的判定范围）
	var cap := _shape.shape as CapsuleShape2D
	if cap:
		cap.radius = GameData.SWORD_HIT_CAPSULE_RADIUS
		cap.height = GameData.SWORD_HIT_CAPSULE_HEIGHT
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(mgr: SwordManager, idx: int) -> void:
	_mgr = mgr
	_index = idx


func _process(delta: float) -> void:
	# 更新命中冷却
	var expired: Array = []
	for k in _hit_cd:
		_hit_cd[k] -= delta
		if _hit_cd[k] <= 0:
			expired.append(k)
	for k in expired:
		_hit_cd.erase(k)

	# 同步缩放
	scale = Vector2.ONE * _mgr.size_mult
	queue_redraw()


func _can_hit(target: Node) -> bool:
	return not _hit_cd.has(target)


func _mark_hit(target: Node) -> void:
	_hit_cd[target] = GameData.SWORD_HIT_COOLDOWN


func _on_area_entered(area: Area2D) -> void:
	# 在物理查询 flush 期间不能立即修改碰撞/树结构，延迟处理
	call_deferred("_try_hit", area)


func _on_body_entered(body: Node) -> void:
	call_deferred("_try_hit", body)


func _try_hit(node: Node) -> void:
	if not is_instance_valid(node):
		return
	# 只命中带 take_damage 的目标（敌人/Boss/召唤物）
	if not node.has_method("take_damage"):
		return
	if not _can_hit(node):
		return
	_mark_hit(node)
	_mgr.on_sword_hit_enemy(node, self)


func _draw() -> void:
	var blade_color: Color = GameData.element_color(_mgr.element)
	Drawing.draw_sword(
		self,
		GameData.SWORD_LENGTH,
		GameData.SWORD_WIDTH,
		blade_color,
		Color(1, 1, 1, 0.9)
	)
	# 元素光晕
	if _mgr.element != GameData.Element.PHYSICAL:
		draw_circle(Vector2.ZERO, GameData.SWORD_LENGTH * 0.55,
			Color(blade_color.r, blade_color.g, blade_color.b, 0.18))
