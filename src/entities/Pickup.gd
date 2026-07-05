class_name Pickup
extends Area2D
## 地图上随机刷新、走过去就能吃的 Buff 道具。
## 不需要打怪，纯走位拾取。类型从配置 pickup_buff.types 读取。

@export var collect_radius: float = 26.0
@export var magnet_range: float = 90.0

var _type: Dictionary = {}
var _player: Node2D = null
var _attracted := false
var _vel := Vector2.ZERO
var _age := 0.0
var _lifetime := 22.0   # 超时消失，避免地图堆积
var _bob_phase := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 0
	collision_mask = 1   # 只与玩家（layer 1）碰撞
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")
	(_shape.shape as CircleShape2D).radius = collect_radius
	_type = _type  # noop, 保留


func setup(t: Dictionary) -> void:
	_type = t


func _physics_process(delta: float) -> void:
	_age += delta
	_bob_phase += delta * 3.0
	if _age >= _lifetime:
		# 临消失前闪烁（由 _draw 处理），到点销毁
		queue_free()
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	# 磁吸：玩家靠近时被吸引
	var to_p := _player.global_position - global_position
	var dist := to_p.length()
	var pickup: float = _player.get("pickup_range") if "pickup_range" in _player else GameData.PLAYER_PICKUP_RANGE
	if not _attracted and dist < (magnet_range + pickup * 0.5):
		_attracted = true
	if _attracted:
		var dir := to_p.normalized()
		_vel = _vel.lerp(dir * 360.0, 0.2)
		global_position += _vel * delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_apply_effect(body)
		queue_free()


## 把效果应用到玩家（含瞬时与定时 Buff）。
func _apply_effect(player: Node) -> void:
	var id: String = _type.get("id", "")
	var name: String = _type.get("name", id)
	var dur: float = float(_type.get("duration", 0.0))
	var eff := GameData.PICKUP_EFFECT
	match id:
		"heal":
			player.heal(float(eff.get("heal_amount", 35.0)), true)
			_popup(player, "+治疗", Color("ff5a7a"))
		"speed":
			player.add_timed_buff("move_speed_mult", float(eff.get("speed_mult", 1.5)), dur)
			_popup(player, "加速!", Color("7be0ff"))
		"damage":
			player.add_timed_buff("sword_damage_mult", float(eff.get("damage_mult", 1.6)), dur)
			_popup(player, "攻击力↑", Color("ff8a3c"))
		"rot_speed":
			player.add_timed_buff("sword_rot_speed_mult", float(eff.get("rot_speed_mult", 1.6)), dur)
			_popup(player, "攻速↑", Color("ffd24a"))
		"magnet":
			player.add_timed_buff("pickup_range_bonus", float(eff.get("magnet_range_bonus", 320.0)), dur)
			_popup(player, "磁铁!", Color("c8a6ff"))
		"shield":
			player.add_timed_buff("damage_reduction", float(eff.get("shield_damage_reduction", 0.5)), dur)
			_popup(player, "护盾!", Color("8fffae"))
		"xp_burst":
			player.add_xp(int(eff.get("xp_burst_amount", 8)))
			_popup(player, "+经验", Color("8fffae"))
		"sword_add":
			# 永久增加一把剑
			var sm := player.get_node_or_null("SwordManager")
			if sm and sm.has_method("add_sword"):
				sm.add_sword()
			_popup(player, "+1 剑!", Color("ffd24a"))
		"element_fire":
			_apply_element(player, GameData.Element.FIRE)
			_popup(player, "火焰附魔!", Color("ff7a3c"))
		"element_frost":
			_apply_element(player, GameData.Element.FROST)
			_popup(player, "冰冻附魔!", Color("6cc7ff"))
		"element_lightning":
			_apply_element(player, GameData.Element.LIGHTNING)
			_popup(player, "雷电附魔!", Color("ffe34a"))
		"instant_level":
			# 直接升一级（带升级奖励但不弹选择面板）
			if player.has_method("add_xp"):
				player.add_xp(GameData.xp_to_reach(player.level))
			_popup(player, "升 级!", Color("c8a6ff"))
		"unlock_sword":
			_unlock_skill(player, "sword", "巨剑冲撞解锁!", Color("ffd24a"))
		"unlock_laser":
			_unlock_skill(player, "laser", "毁灭激光解锁!", Color("7be0ff"))
		"unlock_timestop":
			_unlock_skill(player, "timestop", "时停力场解锁!", Color("c8a6ff"))
		_:
			pass
	GameEvents.hud_message.emit("拾取: %s" % name, 1.2)


## 解锁主动技能并增加使用次数。
func _unlock_skill(player: Node, skill: String, msg: String, color: Color) -> void:
	var ask := player.get_node_or_null("ActiveSkills")
	var eff := GameData.PICKUP_EFFECT
	var charges_key := "skill_charges_per_pickup" if skill != "timestop" else "skill_charges_timestop"
	var charges := int(eff.get(charges_key, 3))
	if ask and ask.has_method("unlock_skill"):
		ask.unlock_skill(skill, charges)
	_popup(player, msg, color)


## 应用元素附魔到剑（火焰/冰冻/雷电）。
func _apply_element(player: Node, element: int) -> void:
	var sm := player.get_node_or_null("SwordManager")
	if sm and sm.has_method("apply_element"):
		sm.apply_element(element)


func _popup(player: Node, text: String, color: Color) -> void:
	var dn := preload("res://src/effects/DamageNumber.tscn").instantiate()
	get_parent().add_child(dn)
	dn.global_position = player.global_position + Vector2(0, -24)
	dn.setup(text, color, true)


func _draw() -> void:
	var col := Color.from_string(_type.get("color", "#ffffff"), Color.WHITE)
	# 临近消失时闪烁
	if _age > _lifetime - 4.0:
		var blink := sin(_age * 16.0) * 0.5 + 0.5
		col.a = clampf(blink, 0.3, 1.0)
	# 浮动偏移
	var bob := sin(_bob_phase) * 2.0
	# 外光晕
	draw_circle(Vector2(0, bob), 18.0, Color(col.r, col.g, col.b, 0.22))
	# 主体六边形
	var r := 11.0
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0 + _bob_phase * 0.3
		pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0, bob))
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE * 0.9, 1.2)
	# 图标符号
	_draw_icon(Vector2(0, bob), String(_type.get("icon", "")), Color.WHITE)


func _draw_icon(center: Vector2, icon: String, col: Color) -> void:
	match icon:
		"cross":   # 治疗
			draw_line(center + Vector2(-4,-6), center + Vector2(-4,6), col, 2.5)
			draw_line(center + Vector2(-6,-4), center + Vector2(6,-4), col, 2.5)
			draw_line(center + Vector2(4,-6), center + Vector2(4,6), col, 2.5)
			draw_line(center + Vector2(-6,4), center + Vector2(6,4), col, 2.5)
		"arrow":   # 加速
			draw_line(center + Vector2(-5,4), center + Vector2(0,-5), col, 2.5)
			draw_line(center + Vector2(0,-5), center + Vector2(5,4), col, 2.5)
		"sword":   # 攻击
			draw_line(center + Vector2(-4,4), center + Vector2(4,-4), col, 2.5)
		"spin":    # 攻速
			draw_arc(center, 5.0, 0, TAU * 1.3, 12, col, 2.0)
		"magnet":  # 磁铁
			draw_arc(center + Vector2(0,2), 5.0, PI, TAU, 10, col, 2.0)
			draw_line(center + Vector2(-5,2), center + Vector2(-5,5), col, 2.0)
			draw_line(center + Vector2(5,2), center + Vector2(5,5), col, 2.0)
		"shield":  # 护盾
			var p := PackedVector2Array([center+Vector2(-5,-4), center+Vector2(5,-4), center+Vector2(4,5), center+Vector2(0,7), center+Vector2(-4,5)])
			draw_polyline(p + PackedVector2Array([p[0]]), col, 2.0)
		"gem":     # 经验
			var gp := PackedVector2Array([center+Vector2(0,-6), center+Vector2(5,0), center+Vector2(0,6), center+Vector2(-5,0)])
			draw_polyline(gp + PackedVector2Array([gp[0]]), col, 2.0)
		"fire":    # 火焰
			var fp := PackedVector2Array([center+Vector2(0,-7), center+Vector2(4,-1), center+Vector2(2,5), center+Vector2(-2,5), center+Vector2(-4,-1)])
			draw_colored_polygon(fp, col)
		"frost":   # 冰冻（雪花）
			for i in 3:
				var a := PI * float(i) / 3.0
				draw_line(center+Vector2(cos(a),sin(a))*-6, center+Vector2(cos(a),sin(a))*6, col, 2.0)
		"lightning":  # 雷电
			var lp := PackedVector2Array([center+Vector2(-2,-6), center+Vector2(3,-6), center+Vector2(0,-1), center+Vector2(3,-1), center+Vector2(-2,6), center+Vector2(0,1), center+Vector2(-3,1)])
			draw_polyline(lp, col, 2.0)
		"star":    # 升阶卷轴（星）
			var sp := PackedVector2Array()
			for i in 10:
				var a := -PI*0.5 + TAU*i/10.0
				var rr := 6.0 if i%2==0 else 2.5
				sp.append(center+Vector2(cos(a),sin(a))*rr)
			draw_colored_polygon(sp, col)
