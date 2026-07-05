class_name Boss
extends CharacterBody2D
## Boss：拥有 6 种技能的状态机。
## 技能：冲锋 / 扇形斩 / 地面 AoE / 弹幕 / 召唤小怪 / 激光扫射。
## 与普通敌人共用 take_damage/apply_knockback 接口（剑可命中）。

signal health_changed(current: float, maximum: float)
signal defeated

@export var max_hp: float = 4200.0
@export var move_speed: float = 110.0
@export var contact_damage: float = 24.0
@export var body_radius: float = 36.0

var hp: float = 4200.0
var _player: Node2D = null
var _state: String = "idle"
var _state_time: float = 0.0
var _state_timer: float = 0.0
var _next_skill: float = 2.5
var _dead: bool = false
var _velocity_extra := Vector2.ZERO
var _hurt_flash: float = 0.0
var _facing: float = 0.0
var _display_name: String = "深渊领主"

# 冲锋状态数据
var _charge_dir := Vector2.ZERO
var _charge_speed := 0.0

const ENEMY_LAYER := 2
const BOSS_LAYER := 8

# 技能选择权重（id -> 权重）。血量越低，高风险技能权重越高。
const _SKILL_LIST := ["charge", "sector", "aoe", "bullet", "summon", "laser"]


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	# 从配置读取真实数值，并应用难度倍率
	max_hp = GameData.BOSS_MAX_HP * Difficulty.current_params.boss_hp_mult
	move_speed = GameData.BOSS_MOVE_SPEED
	contact_damage = GameData.BOSS_CONTACT_DAMAGE * Difficulty.current_params.enemy_damage_mult
	body_radius = GameData.BOSS_BODY_RADIUS
	collision_layer = BOSS_LAYER
	collision_mask = 0
	hp = max_hp
	_player = get_tree().get_first_node_in_group("player")
	var area := $HitArea as Area2D
	if area:
		area.body_entered.connect(_on_hit_body_entered)
	GameEvents.boss_spawned.emit(self)
	health_changed.emit(hp, max_hp)


## 从 bestiary_bosses 配置初始化（按关卡）。由 Main 在 instantiate 后调用。
func setup_from_bestiary(data: Dictionary) -> void:
	# 应用 bestiary 的 hp/伤害（叠加难度倍率）
	var bestiary_hp := float(data.get("max_hp", max_hp))
	var bestiary_dmg := float(data.get("contact_damage", contact_damage))
	max_hp = bestiary_hp * Difficulty.current_params.boss_hp_mult
	contact_damage = bestiary_dmg * Difficulty.current_params.enemy_damage_mult
	hp = max_hp
	# 显示用名称
	_display_name = String(data.get("name", "深渊领主"))
	health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	_state_time += delta
	_state_timer -= delta
	_hurt_flash = max(0.0, _hurt_flash - delta * 4.0)
	_velocity_extra = _velocity_extra.lerp(Vector2.ZERO, delta * 4.0)

	match _state:
		"idle":     _state_idle(delta)
		"charge":   _state_charge(delta)
		"sector":   _state_wait_skill(delta)
		"aoe":      _state_wait_skill(delta)
		"bullet":   _state_wait_skill(delta)
		"summon":   _state_wait_skill(delta)
		"laser":    _state_wait_skill(delta)

	# 朝向玩家（除冲锋外）
	if _state != "charge":
		var to := _player.global_position - global_position
		if to.length() > 1.0:
			_facing = atan2(to.y, to.x)

	queue_redraw()


# ---- 状态：待机/选择技能 ----
func _state_idle(delta: float) -> void:
	# 缓慢逼近玩家
	var to := _player.global_position - global_position
	var dir := to.normalized()
	var desired := dir * move_speed
	if to.length() > 140:
		velocity = desired + _velocity_extra
	else:
		velocity = _velocity_extra.lerp(Vector2.ZERO, 0.2)
	move_and_slide()

	if _state_timer <= 0:
		_pick_and_start_skill()


func _pick_and_start_skill() -> void:
	var skill := _choose_skill()
	_start_skill(skill)


func _choose_skill() -> String:
	var hp_ratio := hp / max_hp
	# 权重：低血量时高威胁技能权重上升
	var weights := {
		"charge": 2.0,
		"sector": 2.0,
		"aoe":    2.0,
		"bullet": 2.5,
		"summon": 1.5,
		"laser":  0.5 + (1.0 - hp_ratio) * 2.0,
	}
	# 低血量时连发弹幕与召唤
	if hp_ratio < 0.5:
		weights["bullet"] += 1.5
		weights["summon"] += 1.0
	if hp_ratio < 0.25:
		weights["charge"] += 1.0
		weights["laser"] += 1.0

	var total := 0.0
	for k in weights: total += weights[k]
	var r := randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "bullet"


func _start_skill(skill: String) -> void:
	_state = skill
	_state_time = 0.0
	match skill:
		"charge":  _do_charge_start()
		"sector":  _do_sector()
		"aoe":     _do_aoe()
		"bullet":  _do_bullet()
		"summon":  _do_summon()
		"laser":   _do_laser()


# 技能执行后回到 idle 的统一回调（非持续型技能）
func _state_wait_skill(_delta: float) -> void:
	if _state_timer <= 0:
		_back_to_idle()


func _back_to_idle() -> void:
	_state = "idle"
	_state_time = 0.0
	# 下次技能间隔（随血量缩短）
	var hp_ratio := hp / max_hp
	_state_timer = randf_range(1.6, 2.6) * (0.6 + hp_ratio * 0.6)


# ---- 技能：冲锋 ----
func _do_charge_start() -> void:
	var to := _player.global_position - global_position
	_charge_dir = to.normalized()
	_charge_speed = 620.0
	_state_timer = 1.2     # 冲锋持续时长
	# 提示
	_spawn_warning_text("冲锋!")


func _state_charge(delta: float) -> void:
	velocity = _charge_dir * _charge_speed + _velocity_extra
	_charge_speed = lerpf(_charge_speed, 120.0, delta * 1.2)
	move_and_slide()
	if _state_timer <= 0:
		# 冲锋结束留下小范围 AoE
		_spawn_aoe_at(global_position, 90.0, 22.0, 0.4)
		_back_to_idle()


# ---- 技能：扇形斩 ----
func _do_sector() -> void:
	var to := _player.global_position - global_position
	var facing := atan2(to.y, to.x)
	# AoEWarning 作为世界固定节点直接挂到父节点，避免随 Boss 移动
	var warn := AoEWarning.new()
	get_parent().add_child(warn)
	warn.global_position = global_position
	warn.is_sector = true
	warn.sector_facing = facing
	warn.sector_angle = PI * 0.7
	warn.radius = 260.0
	warn.damage = 26.0
	warn.warn_time = 0.7
	warn.active_time = 0.25
	_spawn_warning_text("扇形斩!")
	_state_timer = 1.0


# ---- 技能：地面 AoE（玩家脚下多重爆炸）----
func _do_aoe() -> void:
	var n := 4
	for i in n:
		var delay := i * 0.18
		get_tree().create_timer(delay).timeout.connect(_spawn_aoe_at_player)
	_spawn_warning_text("范围轰炸!")
	_state_timer = 1.4


func _spawn_aoe_at_player() -> void:
	if not is_instance_valid(_player):
		return
	_spawn_aoe_at(_player.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 96.0, 20.0, 0.7)


func _spawn_aoe_at(pos: Vector2, r: float, dmg: float, warn: float) -> void:
	var aoe := AoEWarning.new()
	get_parent().add_child(aoe)
	aoe.global_position = pos
	aoe.radius = r
	aoe.damage = dmg
	aoe.warn_time = warn
	aoe.active_time = 0.25


# ---- 技能：弹幕 ----
func _do_bullet() -> void:
	var n := 16
	for i in n:
		var a := TAU * float(i) / n
		_fire_bullet(Vector2(cos(a), sin(a)), 240.0, 9.0, Color("ff6a6a"))
	# 第二波朝玩家方向
	get_tree().create_timer(0.4).timeout.connect(_fire_aimed_wave)
	_spawn_warning_text("弹幕!")
	_state_timer = 1.2


func _fire_aimed_wave() -> void:
	if _dead or not is_instance_valid(_player):
		return
	var base := (_player.global_position - global_position).angle()
	for i in 5:
		var a := base + (i - 2) * 0.18
		_fire_bullet(Vector2(cos(a), sin(a)), 300.0, 10.0, Color("ffa14a"))


func _fire_bullet(dir: Vector2, speed: float, dmg: float, col: Color) -> void:
	var b := preload("res://src/entities/Bullet.tscn").instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + dir * (body_radius + 4)
	b.setup(dir, speed, dmg, col, 0.0)


# ---- 技能：召唤小怪 ----
func _do_summon() -> void:
	var n := 3
	for i in n:
		var a := TAU * float(i) / n + randf() * 0.5
		var pos := global_position + Vector2(cos(a), sin(a)) * 80.0
		_spawn_minion(pos)
	_spawn_warning_text("召唤!")
	_state_timer = 1.2


func _spawn_minion(pos: Vector2) -> void:
	var e := preload("res://src/entities/Enemy.tscn").instantiate()
	get_parent().add_child(e)
	e.global_position = pos
	# 较弱的小怪
	e.configure(18.0, 110.0, 6.0, 1, Color("b14fd6"), false)


# ---- 技能：激光扫射 ----
func _do_laser() -> void:
	var laser := LaserBeam.new()
	get_parent().add_child(laser)
	laser.global_position = global_position
	var to := _player.global_position - global_position
	laser.setup(atan2(to.y, to.x))
	laser.warn_time = 1.0
	laser.active_time = 1.6
	laser.sweep_range = PI * 0.6
	laser.damage_per_sec = 70.0
	_spawn_warning_text("激光扫射!")
	_state_timer = 2.6


# ---- 接触玩家造成伤害 ----
func _on_hit_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)


# ---- 受击（兼容剑的接口）----
func take_damage(amount: float, element: int = GameData.Element.PHYSICAL, flags: Dictionary = {}, crit: bool = false, _src: Node = null) -> void:
	if _dead:
		return
	if amount <= 0.0:
		return
	hp -= amount
	_hurt_flash = 1.0
	_spawn_damage_number(int(round(amount)), element, crit)
	health_changed.emit(hp, max_hp)
	GameEvents.boss_health_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func apply_knockback(_vel: Vector2) -> void:
	# Boss 免疫击退
	pass


## 应用关卡视觉缩放（高关卡 Boss 更大），同步放大碰撞半径。
func apply_visual_scale(mult: float) -> void:
	if mult == 1.0:
		return
	body_radius *= mult
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = body_radius
	var area_shape := get_node_or_null("HitArea/Shape") as CollisionShape2D
	if area_shape and area_shape.shape is CircleShape2D:
		(area_shape.shape as CircleShape2D).radius = body_radius + 4.0


func _die() -> void:
	if _dead:
		return
	_dead = true
	defeated.emit()
	GameEvents.boss_defeated.emit()
	# 死亡爆炸：多重 AoE 视觉
	for i in 5:
		var a := TAU * float(i) / 5
		_spawn_aoe_at(global_position + Vector2(cos(a), sin(a)) * 40, 70, 0, 0.3)
	# 大量经验
	_drop_big_xp()
	queue_free()


func _drop_big_xp() -> void:
	var gem_scene := preload("res://src/entities/XPGem.tscn")
	for i in 12:
		var g := gem_scene.instantiate()
		get_parent().add_child(g)
		g.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		g.setup(GameData.XP_GEM_VALUE_BIG)


func _spawn_damage_number(amount: int, element: int, crit: bool) -> void:
	var dn := preload("res://src/effects/DamageNumber.tscn").instantiate()
	get_parent().add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-10, 10), -body_radius - 10)
	var color := Color.WHITE
	if crit:
		color = Color("ffd24a")
	elif element != GameData.Element.PHYSICAL:
		color = GameData.element_color(element)
	dn.setup(str(amount), color, crit)


func _spawn_warning_text(text: String) -> void:
	var dn := preload("res://src/effects/DamageNumber.tscn").instantiate()
	get_parent().add_child(dn)
	dn.global_position = global_position + Vector2(0, -body_radius - 30)
	dn.setup(text, Color("ff6a6a"), true)


func _draw() -> void:
	# 阴影
	draw_circle(Vector2(0, body_radius * 0.85), body_radius * 0.95, Color(0, 0, 0, 0.4))
	var col := Color("7a1f8f")
	if _hurt_flash > 0:
		col = col.lerp(Color.WHITE, _hurt_flash)
	Drawing.draw_disc(self, body_radius, col, Color("2a0a35"), 3.0)
	# 王冠/角
	for i in 3:
		var a := -PI * 0.5 + (i - 1) * 0.5
		var p := Vector2(cos(a), sin(a)) * body_radius
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-6, 0),
			p + Vector2(6, 0),
			p + Vector2(0, -14),
		]), Color("d6a6ff"))
	# 眼睛（朝向）
	var ex := cos(_facing) * 6
	var ey := sin(_facing) * 6
	draw_circle(Vector2(-10, -2) + Vector2(ex, ey) * 0.3, 5, Color("ff3a3a"))
	draw_circle(Vector2(10, -2) + Vector2(ex, ey) * 0.3, 5, Color("ff3a3a"))
	# 血量低时身体发红
	if hp / max_hp < 0.33:
		draw_circle(Vector2.ZERO, body_radius * 1.5, Color(1, 0.2, 0.2, 0.15))
