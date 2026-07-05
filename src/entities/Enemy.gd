class_name Enemy
extends CharacterBody2D
## 普通敌人：追击玩家、接触造成伤害、被击杀掉落经验宝石。
## 兼容剑的 take_damage/apply_knockback 接口，并处理元素状态。

@export var max_hp: float = 30.0
@export var move_speed: float = 80.0
@export var contact_damage: float = 10.0
@export var contact_interval: float = 0.6
@export var xp_value: int = 1
@export var body_radius: float = 12.0
@export var enemy_color: Color = Color("9b3b3b")
@export var enemy_outline: Color = Color("3a1010")
@export var is_elite: bool = false
@export var shape: String = "square"   # square / triangle / diamond / ghost / star
@export var movement: String = "chase" # chase（追击）/ charge（直线冲撞）/ wander（随机游走）

# 运动状态（charge/wander 模式用）
var _move_dir := Vector2.ZERO
var _move_timer := 0.0
var _move_duration := 2.0
const _CHARGE_RANGE := 520.0   # charge 模式超出此距离重选方向

var hp: float = 30.0
var _contact_cd: float = 0.0
var _player: Node2D = null
var _velocity_extra := Vector2.ZERO   # 击退速度

# 状态效果
var _burn_time: float = 0.0
var _burn_dps: float = 0.0
var _frost_time: float = 0.0
var _frost_slow: float = 0.0
var _hurt_flash: float = 0.0
var _dead: bool = false
# 血条：受击后显示一段时间，无伤害时淡出隐藏
var _hp_bar_timer: float = 0.0      # >0 时显示血条
const HP_BAR_SHOW_TIME := 1.2      # 受击后血条持续显示时长（秒）
# 怪物等级（星级）
var _grade_stars: int = 2
var _grade_name: String = "普通"

const ENEMY_LAYER := 2


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = ENEMY_LAYER
	collision_mask = 0
	hp = max_hp
	_player = get_tree().get_first_node_in_group("player")
	# 用 Area2D 监测接触玩家
	var area := $HitArea as Area2D
	if area:
		area.body_entered.connect(_on_hit_area_body_entered)
		area.area_entered.connect(_on_hit_area_area_entered)


func configure(p_max_hp: float, p_speed: float, p_dmg: float, p_xp: int, p_color: Color, p_elite := false, p_shape := "square", p_movement := "chase") -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	move_speed = p_speed
	contact_damage = p_dmg
	xp_value = p_xp
	enemy_color = p_color
	is_elite = p_elite
	shape = p_shape
	movement = p_movement
	# 精英怪强制追击
	if p_elite:
		movement = "chase"
		body_radius = 18.0
		scale = Vector2(1.5, 1.5)
	# 初始化运动方向
	_pick_new_move_dir()


## 应用关卡视觉缩放（高关卡让普通怪也变大），叠加在精英基础缩放上。
## 同时放大碰撞半径，使视觉与判定一致。
func apply_visual_scale(mult: float) -> void:
	if mult == 1.0:
		return
	body_radius *= mult
	# 调整接触检测区
	var area := get_node_or_null("HitArea/Shape") as CollisionShape2D
	if area and area.shape is CircleShape2D:
		(area.shape as CircleShape2D).radius = body_radius + 4.0
	# 物理碰撞体
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = body_radius


## 设置怪物等级（星级 + 名称），头顶显示星数。
func set_grade(stars: int, gname: String) -> void:
	_grade_stars = clampi(stars, 1, 5)
	_grade_name = gname


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	# 状态效果更新
	_update_status(delta)

	# 按运动模式计算方向
	var dir := _compute_move_dir(delta)
	var slow := 1.0 - _frost_slow if _frost_time > 0 else 1.0
	velocity = dir * move_speed * slow + _velocity_extra
	_velocity_extra = _velocity_extra.lerp(Vector2.ZERO, delta * 6.0)
	move_and_slide()

	if _contact_cd > 0:
		_contact_cd -= delta
	if _hurt_flash > 0:
		_hurt_flash -= delta * 4.0
	if _hp_bar_timer > 0:
		_hp_bar_timer -= delta

	queue_redraw()


## 根据运动模式返回当前移动方向。
func _compute_move_dir(delta: float) -> Vector2:
	var to_p := _player.global_position - global_position
	match movement:
		"chase":
			# 持续追击玩家（精英怪默认）
			return to_p.normalized() if to_p.length() > 1.0 else Vector2.ZERO
		"charge":
			# 直线冲撞：选定方向后高速直冲，撞太远或到时间后重新瞄准玩家方向
			_move_timer -= delta
			var dist := global_position.distance_to(_player.global_position)
			if _move_timer <= 0 or dist > _CHARGE_RANGE or _move_dir == Vector2.ZERO:
				# 重新瞄准玩家（带轻微随机偏角）
				var base := to_p.normalized() if to_p.length() > 1.0 else Vector2.RIGHT
				_move_dir = base.rotated(randf_range(-0.4, 0.4))
				_move_duration = randf_range(1.2, 2.4)
				_move_timer = _move_duration
			return _move_dir
		"wander":
			# 随机游走：周期性改方向，轻微偏向玩家
			_move_timer -= delta
			if _move_timer <= 0 or _move_dir == Vector2.ZERO:
				var base := to_p.normalized() if to_p.length() > 1.0 else Vector2.RIGHT
				_move_dir = base.rotated(randf_range(-PI * 0.7, PI * 0.7))
				_move_duration = randf_range(0.8, 1.8)
				_move_timer = _move_duration
			return _move_dir
		_:
			return to_p.normalized() if to_p.length() > 1.0 else Vector2.ZERO


func _pick_new_move_dir() -> void:
	_move_dir = Vector2.from_angle(randf() * TAU)
	_move_timer = 0.0


func _update_status(delta: float) -> void:
	if _burn_time > 0:
		_burn_time -= delta
		_take_pure_damage(_burn_dps * delta, false)
		if _burn_time <= 0:
			_burn_dps = 0.0
	if _frost_time > 0:
		_frost_time -= delta


# ---- 受击 ----
func take_damage(amount: float, element: int = GameData.Element.PHYSICAL, flags: Dictionary = {}, crit: bool = false, _src: Node = null) -> void:
	if _dead:
		return
	if amount <= 0.0:
		# 0/负伤害不结算、不飘字（修复死后出现"0"白字）
		return
	hp -= amount
	_hurt_flash = 1.0
	_hp_bar_timer = HP_BAR_SHOW_TIME   # 受击即显示血条
	_spawn_damage_number(int(round(amount)), element, crit)

	# 元素状态
	if flags.get("burn", false):
		_burn_time = 2.0
		_burn_dps = max(_burn_dps, flags.get("source_damage", amount) * 0.25)
	if flags.get("frost", false):
		_frost_time = 1.5
		_frost_slow = 0.5
	if flags.get("lightning", false):
		# 雷电：对附近另一个敌人造成一半伤害
		_chain_lightning(flags.get("source_damage", amount) * 0.5)

	if hp <= 0:
		_die()


func _take_pure_damage(amount: float, _show: bool = true) -> void:
	if _dead:
		return
	hp -= amount
	_hp_bar_timer = HP_BAR_SHOW_TIME   # 燃烧等持续伤害也刷新血条
	if hp <= 0:
		_die()


func apply_knockback(vel: Vector2) -> void:
	_velocity_extra += vel


func _die() -> void:
	if _dead:
		return
	_dead = true
	GameEvents.enemy_killed.emit(self)
	# 掉落经验
	_drop_xp()
	queue_free()


func _drop_xp() -> void:
	var gem_scene := preload("res://src/entities/XPGem.tscn")
	var drops := 1
	var value := xp_value
	if is_elite:
		drops = 3
		value = GameData.XP_GEM_VALUE_BIG
	for i in drops:
		var g := gem_scene.instantiate()
		get_parent().add_child(g)
		var off := Vector2(randf_range(-12, 12), randf_range(-12, 12))
		g.global_position = global_position + off
		g.setup(value)


func _spawn_damage_number(amount: int, element: int, crit: bool) -> void:
	var dn := preload("res://src/effects/DamageNumber.tscn").instantiate()
	get_parent().add_child(dn)
	dn.global_position = global_position + Vector2(randf_range(-6, 6), -body_radius - 6)
	var color := Color.WHITE
	if crit:
		color = Color("ffd24a")
	elif element != GameData.Element.PHYSICAL:
		color = GameData.element_color(element)
	dn.setup(str(amount), color, crit)


func _chain_lightning(dmg: float) -> void:
	var best: Node = null
	var best_d := 160.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		best.take_damage(dmg, GameData.Element.LIGHTNING, {}, false)


# ---- 接触玩家造成伤害 ----
func _on_hit_area_body_entered(body: Node) -> void:
	_try_damage_player(body)


func _on_hit_area_area_entered(area: Area2D) -> void:
	# 兼容玩家用 Area 的情况（本游戏玩家是 CharacterBody2D，body 路径生效）
	pass


func _try_damage_player(node: Node) -> void:
	if not node.is_in_group("player"):
		return
	if _contact_cd > 0:
		return
	if node.has_method("take_damage"):
		node.take_damage(contact_damage)
		_contact_cd = contact_interval
		# 撞到玩家后怪物立即自爆消失（不计入击杀、不掉经验）
		_contact_self_destruct()


## 接触玩家后自爆：静默消失，不触发 enemy_killed 信号、不掉落经验。
func _contact_self_destruct() -> void:
	if _dead:
		return
	_dead = true
	# 小型爆炸视觉（无伤害 AoE）
	_spawn_destruct_puff()
	queue_free()


func _spawn_destruct_puff() -> void:
	# 复用 DamageNumber 机制飘一个简短反馈
	pass


func _draw() -> void:
	# 阴影
	draw_circle(Vector2(0, body_radius * 0.9), body_radius * 0.9, Color(0, 0, 0, 0.3))
	var col := enemy_color
	if _hurt_flash > 0:
		col = col.lerp(Color.WHITE, clampf(_hurt_flash, 0.0, 1.0))
	if _frost_time > 0:
		col = col.lerp(Color("6cc7ff"), 0.4)

	# 按形状绘制身体
	match shape:
		"square":   _draw_body_square(col)
		"triangle": _draw_body_triangle(col)
		"diamond":  _draw_body_diamond(col)
		"ghost":    _draw_body_ghost(col)
		"star":     _draw_body_star(col)
		_:          _draw_body_square(col)

	# 火焰光晕
	if _burn_time > 0:
		draw_circle(Vector2.ZERO, body_radius * 1.6, Color(1, 0.5, 0.2, 0.18))
	# 血条：仅在受击后显示
	if _hp_bar_timer > 0.0 and max_hp > 0:
		_draw_hp_bar()
	# 星级标记（精英及以上显示在头顶）
	if _grade_stars >= 3:
		_draw_grade_stars()


# ---- 不同形状的身体绘制 ----
func _draw_body_square(col: Color) -> void:
	var r := body_radius
	var rect := Rect2(-r, -r, r * 2, r * 2)
	draw_rect(rect, col)
	draw_rect(rect, enemy_outline, false, 2.0)
	# 眼睛
	var er := r * 0.18
	draw_circle(Vector2(-r * 0.35, -r * 0.1), er, Color("ffd24a"))
	draw_circle(Vector2(r * 0.35, -r * 0.1), er, Color("ffd24a"))


func _draw_body_triangle(col: Color) -> void:
	var r := body_radius
	# 倒三角（朝下，骷髅感）
	var pts := PackedVector2Array([
		Vector2(0, r * 0.9),
		Vector2(-r, -r * 0.8),
		Vector2(r, -r * 0.8),
	])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), enemy_outline, 2.0)
	# 双眼
	draw_circle(Vector2(-r * 0.3, -r * 0.2), r * 0.16, Color("0a0a0a"))
	draw_circle(Vector2(r * 0.3, -r * 0.2), r * 0.16, Color("0a0a0a"))


func _draw_body_diamond(col: Color) -> void:
	var r := body_radius
	var pts := PackedVector2Array([
		Vector2(0, -r),
		Vector2(r * 0.75, 0),
		Vector2(0, r),
		Vector2(-r * 0.75, 0),
	])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), enemy_outline, 2.0)
	# 蝙蝠小翅膀
	var wcol := col.darkened(0.2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.6, 0), Vector2(-r * 1.5, -r * 0.3), Vector2(-r * 1.3, r * 0.2)
	]), wcol)
	draw_colored_polygon(PackedVector2Array([
		Vector2(r * 0.6, 0), Vector2(r * 1.5, -r * 0.3), Vector2(r * 1.3, r * 0.2)
	]), wcol)
	# 眼睛
	draw_circle(Vector2(-r * 0.25, -r * 0.15), r * 0.14, Color("ffd24a"))
	draw_circle(Vector2(r * 0.25, -r * 0.15), r * 0.14, Color("ffd24a"))


func _draw_body_ghost(col: Color) -> void:
	var r := body_radius
	# 顶部半圆 + 底部波浪
	var pts := PackedVector2Array()
	var segs := 18
	for i in segs + 1:
		var a := PI + PI * float(i) / segs   # 上半圆
		pts.append(Vector2(cos(a), sin(a)) * r)
	# 底部三个波浪
	var waves := 3
	for w in waves:
		var cx := r * (1.0 - float(w) * 2.0 / waves) - r / waves
		pts.append(Vector2(cx, r * 0.7))
		pts.append(Vector2(cx - r / waves * 0.5, r * 0.95))
	# 闭合
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), enemy_outline, 2.0)
	# 半透明感（幽魂）
	modulate.a = 0.92
	# 幽魂眼睛（空洞）
	draw_circle(Vector2(-r * 0.3, -r * 0.15), r * 0.18, Color("1a0a1a"))
	draw_circle(Vector2(r * 0.3, -r * 0.15), r * 0.18, Color("1a0a1a"))
	draw_circle(Vector2(-r * 0.3, -r * 0.15), r * 0.09, Color("ff5a5a"))
	draw_circle(Vector2(r * 0.3, -r * 0.15), r * 0.09, Color("ff5a5a"))


func _draw_body_star(col: Color) -> void:
	var r := body_radius
	# 五角星（精英守卫）
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		var rr := r * 1.05 if i % 2 == 0 else r * 0.5
		pts.append(Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), enemy_outline, 2.5)
	# 中心宝石眼
	draw_circle(Vector2.ZERO, r * 0.28, Color("ffe34a"))
	draw_circle(Vector2.ZERO, r * 0.16, Color.WHITE)
	# 环绕小点
	for i in 5:
		var a := -PI * 0.5 + TAU * i / 5.0 + PI
		draw_circle(Vector2(cos(a), sin(a)) * r * 1.3, r * 0.08, Color("d6a6ff"))


## 在敌人头顶绘制血条，受击后显示，无伤害时隐藏。
func _draw_hp_bar() -> void:
	var bar_w := body_radius * 2.2
	var bar_h := 4.0
	var bar_y := -body_radius - 10.0
	var bar_x := -bar_w * 0.5
	# 淡出：最后 0.3 秒渐隐
	var alpha := 1.0
	if _hp_bar_timer < 0.3:
		alpha = _hp_bar_timer / 0.3
	# 背景
	draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(0, 0, 0, 0.6 * alpha))
	# 灰色底
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.25, 0.12, 0.12, alpha))
	# 红色前景（按比例）
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var fill_col := Color("ff5a5a") if ratio > 0.3 else Color("ff8a3c")
	draw_rect(Rect2(bar_x, bar_y, bar_w * ratio, bar_h), Color(fill_col.r, fill_col.g, fill_col.b, alpha))


## 头顶绘制等级星数（≥3星显示）。
func _draw_grade_stars() -> void:
	var star_y := -body_radius - 22.0
	var s := "★".repeat(_grade_stars)
	var col := Color("4a9eff") if _grade_stars == 3 else (Color("c062ff") if _grade_stars == 4 else Color("ffc83d"))
	# 用默认字体绘制星号
	var font := ThemeDB.get_default_theme().default_font
	var tw: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
	draw_string(font, Vector2(-tw * 0.5, star_y), s, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-tw * 0.5, star_y - 1), s, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, col)
