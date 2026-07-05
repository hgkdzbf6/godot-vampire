class_name Player
extends CharacterBody2D
## 玩家角色。负责移动、生命、经验/升级、绘制、被击反馈。
## 自动攻击完全交给 SwordManager（子节点）。

signal hp_changed(current: float, maximum: float)

@export var move_speed: float = 230.0
@export var max_hp: float = 100.0

# 等级 / 经验
var level: int = 1
var xp: int = 0
var xp_to_next: int = GameData.xp_to_reach(1)

# 战斗状态（部分由升级修改）
var hp: float = GameData.PLAYER_BASE_MAX_HP
var invul_time: float = 0.0
var regen_per_sec: float = 0.0
var _move_speed_mult_base: float = 1.0   # 由升级累积
var dodge_chance: float = 0.0          # 闪避概率 0..1

# 基础拾取范围（可被升级扩展）。当前生效值见 pickup_range（含 buff）。
var _pickup_range_base: float = GameData.PLAYER_PICKUP_RANGE

# ---- 定时 Buff 系统 ----
# _buffs[key] = {"value": float, "time": float}
# value 含义随 key 不同：
#   move_speed_mult / sword_damage_mult / sword_rot_speed_mult : 乘数
#   pickup_range_bonus : 加到拾取范围的绝对值
#   damage_reduction : 受到伤害的减免比例 0..1
var _buffs: Dictionary = {}

# 碰撞掩码：player 层 = 1
const _PLAYER_LAYER := 1
const _ENEMY_LAYER := 2

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _hurt_flash: ColorRect = $HurtFlash
@onready var _sword_mgr: Node2D = $SwordManager

# 受伤时短暂红色闪烁
var _hurt_alpha := 0.0

# 移动方向，用于绘制朝向/倾斜
var _facing := 1.0
var _walk_phase := 0.0

# 升级暂停期间锁定输入
var _input_locked := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = _PLAYER_LAYER
	collision_mask = 0   # 玩家不靠物理推开敌人；用 Area 监测
	# 从配置读取真实初始值（避免依赖解析时序）
	move_speed = GameData.PLAYER_BASE_MOVE_SPEED
	max_hp = GameData.PLAYER_BASE_MAX_HP
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	GameEvents.player_xp_changed.emit(xp, xp_to_next)
	GameEvents.upgrade_selected.connect(_on_upgrade_selected)
	GameEvents.upgrade_applied.connect(_on_upgrade_applied)
	# 监听升级菜单打开/关闭，用于锁定输入
	GameEvents.level_up_opened.connect(func(_c): _input_locked = true)
	GameEvents.upgrade_applied.connect(func(_u): _input_locked = false)
	_hurt_flash.color = Color(1, 0.15, 0.15, 0.0)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 当前生效的拾取范围（基础 + 升级 + 磁铁 buff）。
var pickup_range: float:
	get:
		var bonus := 0.0
		if _buffs.has("pickup_range_bonus"):
			bonus = _buffs["pickup_range_bonus"]["value"]
		return _pickup_range_base + bonus


## 当前生效的移速乘数（升级累积 × 速度 buff）。
var move_speed_mult: float:
	get:
		var m := _move_speed_mult_base
		if _buffs.has("move_speed_mult"):
			m *= _buffs["move_speed_mult"]["value"]
		return m


## 增加一个定时 buff。同 key 会刷新时长并叠加 value（乘数类取最大，加成类取最大）。
func add_timed_buff(key: String, value: float, duration: float) -> void:
	if duration <= 0.0:
		# 瞬时 buff（如完全治疗不应走这里）；这里只做无操作保护
		return
	var existing_value := value
	if _buffs.has(key):
		existing_value = max(_buffs[key]["value"], value)
	_buffs[key] = {"value": existing_value, "time": duration}


## 当前伤害减免比例（护盾 buff）0..1
func damage_reduction() -> float:
	if _buffs.has("damage_reduction"):
		return _buffs["damage_reduction"]["value"]
	return 0.0


## 重置玩家属性到一局开始的状态，并应用当前难度。
func reset_for_new_run() -> void:
	var dp := Difficulty.current_params
	# 基础值（从配置）× 难度倍率
	move_speed = GameData.PLAYER_BASE_MOVE_SPEED
	max_hp = GameData.PLAYER_BASE_MAX_HP * dp.player_hp_mult
	hp = max_hp
	invul_time = 0.0
	regen_per_sec = 0.0
	_move_speed_mult_base = 1.0
	_pickup_range_base = GameData.PLAYER_PICKUP_RANGE
	dodge_chance = 0.0
	_buffs.clear()
	# 等级 / 经验
	level = 1
	xp = 0
	xp_to_next = GameData.xp_to_reach(1)
	# 状态
	modulate.a = 1.0
	_hurt_alpha = 0.0
	# 广播初始 HUD
	hp_changed.emit(hp, max_hp)
	GameEvents.player_xp_changed.emit(xp, xp_to_next)
	set_physics_process(true)
	# 重置主动技能（解锁与次数清空）
	var ask := get_node_or_null("ActiveSkills")
	if ask and ask.has_method("reset_for_new_run"):
		ask.reset_for_new_run()


func _physics_process(delta: float) -> void:
	if _input_locked:
		velocity = velocity.lerp(Vector2.ZERO, 0.3)
	else:
		var input := _read_move_input()
		velocity = input * (move_speed * move_speed_mult)
		if input.length() > 0.1:
			_walk_phase += delta * 10.0
			_facing = signf(input.x) if absf(input.x) > 0.1 else _facing
		else:
			_walk_phase = lerp(_walk_phase, 0.0, 0.2)

	move_and_slide()

	# 生命回复
	if regen_per_sec > 0.0 and hp < max_hp:
		heal(regen_per_sec * delta, false)

	# 无敌时间衰减 + 隐身闪烁（被击后 1 秒无敌）
	if invul_time > 0:
		invul_time = max(0.0, invul_time - delta)
		# 快速闪烁：约每 0.12s 切换可见性，整体偏半透明
		var blink := sin(invul_time * 40.0) * 0.5 + 0.5
		modulate.a = lerp(0.25, 0.7, blink)
	else:
		modulate.a = 1.0

	# 定时 Buff 计时
	_tick_buffs(delta)

	# 受伤闪烁淡出
	if _hurt_alpha > 0:
		_hurt_alpha = max(0.0, _hurt_alpha - delta * 3.0)
		_hurt_flash.color.a = _hurt_alpha * 0.45

	queue_redraw()


func _tick_buffs(delta: float) -> void:
	if _buffs.is_empty():
		return
	var expired: Array = []
	for key in _buffs:
		_buffs[key]["time"] -= delta
		if _buffs[key]["time"] <= 0.0:
			expired.append(key)
	for key in expired:
		_buffs.erase(key)


func _read_move_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  v.x -= 1
	if Input.is_action_pressed("move_right"): v.x += 1
	if Input.is_action_pressed("move_up"):    v.y -= 1
	if Input.is_action_pressed("move_down"):  v.y += 1
	return v.normalized()


func _draw() -> void:
	# 阴影
	draw_circle(Vector2(0, 14), 14, Color(0, 0, 0, 0.35))
	# 身体（带轻微走路上下浮动）
	var bob := sin(_walk_phase) * 1.5
	var body_color := Color("5d8bf0")
	var outline := Color("22305c")
	# 腿
	draw_rect(Rect2(-7, 6 + bob, 5, 8), Color("33416b"))
	draw_rect(Rect2(2, 6 + bob, 5, 8), Color("33416b"))
	# 身躯
	Drawing.draw_round_rect(self, Vector2(11, 12 + bob), body_color, 6)
	# 头
	Drawing.draw_disc(self, 9, Color("f0c39b"), outline, 2)
	# 眼睛（朝向）
	var eye_off := Vector2(_facing * 2.0, -1 + bob)
	draw_circle(Vector2(-3, 0) + eye_off, 1.4, Color.WHITE)
	draw_circle(Vector2(3, 0) + eye_off, 1.4, Color.WHITE)
	# 头发
	draw_arc(Vector2(0, -3 + bob), 8, PI, TAU, 16, Color("3a2a1a"), 4, true)


# ---- 生命 / 伤害 ----
func take_damage(amount: float) -> void:
	if invul_time > 0:
		return
	if randf() < dodge_chance:
		_spawn_text("闪避!", Color("ffe34a"))
		return
	# 护盾 buff 减免
	var actual := amount * (1.0 - damage_reduction())
	hp = max(0.0, hp - actual)
	invul_time = GameData.PLAYER_HIT_INVUL_TIME
	_hurt_alpha = 1.0
	hp_changed.emit(hp, max_hp)
	GameEvents.player_damaged.emit(hp, max_hp)
	if hp <= 0:
		_die()


func heal(amount: float, show_text: bool = true) -> void:
	var before := hp
	hp = minf(max_hp, hp + amount)
	if show_text and hp > before + 0.5:
		_spawn_text("+%d" % int(amount), Color("8fffae"))
	hp_changed.emit(hp, max_hp)
	GameEvents.player_healed.emit(hp, max_hp)


func _die() -> void:
	set_physics_process(false)
	GameEvents.player_died.emit()
	GameEvents.game_over.emit()


# ---- 经验 / 升级 ----
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		_on_level_up()
		xp_to_next = GameData.xp_to_reach(level)
	GameEvents.player_xp_changed.emit(xp, xp_to_next)


func _on_level_up() -> void:
	level += 1
	GameEvents.player_leveled_up.emit(level)
	# 升级时回血 25%
	heal(max_hp * 0.25, true)


func _on_upgrade_selected(_u: Dictionary) -> void:
	pass


func _on_upgrade_applied(upgrade: Dictionary) -> void:
	apply_upgrade(upgrade)


## 应用一项升级到玩家自身属性（剑相关交给 SwordManager）。
func apply_upgrade(u: Dictionary) -> void:
	match u.get("id", ""):
		"max_hp":
			max_hp += u.get("value", 20)
			heal(u.get("value", 20), true)
		"move_speed":
			_move_speed_mult_base *= u.get("mult", 1.1)
		"regen":
			regen_per_sec += u.get("value", 1.0)
		"pickup_range":
			_pickup_range_base += u.get("value", 40.0)
		"dodge":
			dodge_chance = clampf(dodge_chance + u.get("value", 0.05), 0.0, 0.75)
		"heal_full":
			heal(max_hp, true)
		# 剑相关升级：转发给 SwordManager
		_:
			if _sword_mgr and _sword_mgr.has_method("apply_upgrade"):
				_sword_mgr.apply_upgrade(u)


# ---- 工具 ----
func _spawn_text(text: String, color: Color) -> void:
	var dn := preload("res://src/effects/DamageNumber.tscn").instantiate()
	get_parent().add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-8, 8), -18)
	dn.setup(text, color, false)
