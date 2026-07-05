class_name SwordManager
extends Node2D
## 管理环绕玩家的所有飞剑：旋转半径/速度/数量/大小/伤害/穿透/元素/暴击/吸血。
## 剑本身是纯代码自绘，命中检测用 Area2D（每把剑一个）。

@export var base_count: int = 1
@export var radius: float = 70.0
@export var rot_speed: float = 2.8
@export var size_mult: float = 1.0
@export var damage: float = 16.0
@export var pierce: int = 0
@export var knockback: float = 90.0

# 暴击
var crit_chance: float = 0.0
var crit_mult: float = 2.0

# 吸血
var lifesteal: float = 0.0           # 每次命中回血（绝对值）

# 元素（每把剑可独立或统一）。这里统一管理。
var element: int = GameData.Element.PHYSICAL
# 元素强化：触发概率与持续效果
var burn_chance: float = 0.0         # 火焰：每秒造成 damage*0.25，持续 2s
var frost_chance: float = 0.0        # 冰冻：减速 50%，持续 1.5s
var lightning_chance: float = 0.0    # 雷电：连击附近 1 个敌人

var _angle: float = 0.0
var _swords: Array[Node2D] = []      # 当前实际剑节点

@onready var _player: CharacterBody2D = get_parent()


func _ready() -> void:
	_init_from_config()
	_rebuild_swords()


## 从配置 + 难度初始化基础属性。
func _init_from_config() -> void:
	base_count = GameData.SWORD_BASE_COUNT
	radius = GameData.SWORD_BASE_RADIUS
	rot_speed = GameData.SWORD_BASE_ROT_SPEED
	size_mult = GameData.SWORD_BASE_SIZE
	damage = GameData.SWORD_BASE_DAMAGE * Difficulty.current_params.player_damage_mult
	pierce = GameData.SWORD_BASE_PIERCE
	knockback = GameData.SWORD_BASE_KNOCKBACK


## 一局开始时重置（由 Main 调用），重新应用难度。
func reset_for_new_run() -> void:
	# 清掉升级累积的状态
	crit_chance = 0.0
	crit_mult = 2.0
	lifesteal = 0.0
	element = GameData.Element.PHYSICAL
	burn_chance = 0.0
	frost_chance = 0.0
	lightning_chance = 0.0
	_init_from_config()
	_rebuild_swords()


## 当前生效伤害（基础 × 伤害 buff）。
func effective_damage() -> float:
	var m := 1.0
	if _player and "_buffs" in _player and _player._buffs.has("sword_damage_mult"):
		m = _player._buffs["sword_damage_mult"]["value"]
	return damage * m


## 当前生效旋转速度（基础 × 攻速 buff）。
func effective_rot_speed() -> float:
	var m := 1.0
	if _player and "_buffs" in _player and _player._buffs.has("sword_rot_speed_mult"):
		m = _player._buffs["sword_rot_speed_mult"]["value"]
	return rot_speed * m


## 永久增加一把剑（Pickup 的剑灵核 buff 调用）。
func add_sword() -> void:
	base_count += 1
	_rebuild_swords()


## 应用元素附魔（火/冰/雷，Pickup 晶石 buff 调用）。
func apply_element(element: int) -> void:
	self.element = element
	match element:
		GameData.Element.FIRE:
			burn_chance = max(burn_chance, 0.6)
		GameData.Element.FROST:
			frost_chance = max(frost_chance, 0.6)
		GameData.Element.LIGHTNING:
			lightning_chance = max(lightning_chance, 0.4)
	_rebuild_swords()   # 刷新剑外观颜色


func _physics_process(delta: float) -> void:
	_angle += effective_rot_speed() * delta
	var n := _swords.size()
	for i in n:
		var a := _angle + TAU * float(i) / float(max(1, n))
		var pos := Vector2(cos(a), sin(a)) * radius
		_swords[i].position = pos
		# 剑尖朝向运动切线方向（旋转方向 +90°）
		_swords[i].rotation = a + PI * 0.5


## 重建剑节点，保持数量与当前一致。
func _rebuild_swords() -> void:
	for s in _swords:
		if is_instance_valid(s):
			s.queue_free()
	_swords.clear()
	for i in base_count:
		var sw := preload("res://src/entities/Sword.tscn").instantiate()
		add_child(sw)
		sw.setup(self, i)
		_swords.append(sw)


func get_player() -> CharacterBody2D:
	return _player


## 当剑与敌人重叠时由 Sword 调用，统一处理伤害结算。
func on_sword_hit_enemy(enemy: Node, sword: Node2D) -> void:
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	# 单把剑对同一敌人有冷却（由 Sword 自己处理 cooldown 字典）
	var dmg := effective_damage()
	var crit := randf() < crit_chance
	if crit:
		dmg *= crit_mult
	enemy.take_damage(dmg, element, _compute_element_flags(), crit, sword)

	# 击退
	if "apply_knockback" in enemy and enemy.has_method("apply_knockback"):
		var ep: Vector2 = enemy.global_position
		var dir: Vector2 = (ep - _player.global_position).normalized()
		enemy.apply_knockback(dir * knockback)

	# 吸血
	if lifesteal > 0.0:
		_player.call("heal", lifesteal, false)


func _compute_element_flags() -> Dictionary:
	return {
		"burn": randf() < burn_chance,
		"frost": randf() < frost_chance,
		"lightning": randf() < lightning_chance,
		"source_damage": effective_damage(),
	}


# ---- 升级接口 ----
func apply_upgrade(u: Dictionary) -> void:
	match u.get("id", ""):
		"sword_count":
			base_count += u.get("value", 1)
			_rebuild_swords()
		"sword_radius":
			radius *= u.get("mult", 1.2)
		"sword_rot_speed":
			rot_speed *= u.get("mult", 1.25)
		"sword_size":
			size_mult *= u.get("mult", 1.25)
		"sword_damage":
			damage *= u.get("mult", 1.3)
		"sword_pierce":
			pierce += u.get("value", 1)
		"crit_chance":
			crit_chance = clampf(crit_chance + u.get("value", 0.1), 0.0, 1.0)
		"crit_mult":
			crit_mult += u.get("value", 0.3)
		"lifesteal":
			lifesteal += u.get("value", 1.0)
		"element_fire":
			element = GameData.Element.FIRE
			burn_chance = max(burn_chance, u.get("value", 0.5))
		"element_frost":
			element = GameData.Element.FROST
			frost_chance = max(frost_chance, u.get("value", 0.5))
		"element_lightning":
			element = GameData.Element.LIGHTNING
			lightning_chance = max(lightning_chance, u.get("value", 0.3))
		"knockback":
			knockback *= u.get("mult", 1.5)
