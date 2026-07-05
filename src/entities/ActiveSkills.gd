class_name ActiveSkills
extends Node
## 主动技能管理器（挂在 Player 下）。
## 技能需通过拾取对应 buff（巨剑核/激光核/时停核）解锁，并获得使用次数。
## 有次数才能释放；每次释放进入较短冷却。再拾取同种 buff 增加次数。

const GIANT_SWORD_SCENE := preload("res://src/entities/GiantSword.tscn")

# 技能定义：key -> {key, cooldown, charges_key}
# CD 缩短：巨剑 6s / 激光 5s / 时停 8s
const SKILLS := {
	"sword": {"key": "skill_sword", "cooldown": 6.0, "label": "Q"},
	"laser": {"key": "skill_laser", "cooldown": 5.0, "label": "E"},
	"timestop": {"key": "skill_timestop", "cooldown": 8.0, "label": "空格"},
}

# 解锁状态与剩余次数
var _unlocked: Dictionary = {"sword": false, "laser": false, "timestop": false}
var _charges: Dictionary = {"sword": 0, "laser": 0, "timestop": 0}
var _cooldowns: Dictionary = {"sword": 0.0, "laser": 0.0, "timestop": 0.0}
var _player: Player = null


func _ready() -> void:
	_player = get_parent() as Player
	_register_inputs()


func _register_inputs() -> void:
	_add_key_action("skill_sword", [KEY_Q])
	_add_key_action("skill_laser", [KEY_E])
	_add_key_action("skill_timestop", [KEY_SPACE])


func _add_key_action(action_name: String, keycodes: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for k in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)


func _process(delta: float) -> void:
	for k in _cooldowns:
		if _cooldowns[k] > 0:
			_cooldowns[k] = max(0.0, _cooldowns[k] - delta)
	# 广播状态供 HUD 显示（解锁/次数/冷却）
	for k in SKILLS:
		GameEvents.skill_state_changed.emit(k, _unlocked[k], _charges[k], _cooldowns[k], SKILLS[k].cooldown)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player):
		return
	if event.is_action_pressed("skill_sword"):
		_cast("sword")
	elif event.is_action_pressed("skill_laser"):
		_cast("laser")
	elif event.is_action_pressed("skill_timestop"):
		_cast("timestop")


## 拾取 buff 解锁技能 / 增加次数（由 Pickup 调用）。
func unlock_skill(skill: String, charges: int) -> void:
	_unlocked[skill] = true
	_charges[skill] += charges


func cast_skill(skill: String) -> void:
	_cast(skill)


func _cast(skill: String) -> void:
	if not _unlocked.get(skill, false):
		return
	if _charges.get(skill, 0) <= 0:
		return
	if _cooldowns.get(skill, 0.0) > 0:
		return
	var def: Dictionary = SKILLS[skill]
	_charges[skill] -= 1
	_cooldowns[skill] = def.cooldown
	var target_dir := _aim_direction()
	match skill:
		"sword": _cast_giant_sword(target_dir)
		"laser": _cast_laser(_multi_directions(target_dir, 3, 0.35))
		"timestop": _cast_timestop()


## 获取瞄准方向：找到玩家周围敌人最密集的方向（按角度分桶统计）。
## 若周围没有敌人，则退化为玩家移动方向或默认向右。
func _aim_direction() -> Vector2:
	var player_pos: Vector2 = _player.global_position
	var detect_r := 480.0
	var buckets: Array = []   # 8 个方向桶，每个累加敌人权重（越近权重越大）
	for i in 8:
		buckets.append(0.0)
	var found := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var ep: Vector2 = e.global_position
		var diff: Vector2 = ep - player_pos
		var d := diff.length()
		if d > detect_r or d < 1.0:
			continue
		found = true
		var angle := atan2(diff.y, diff.x)   # -PI..PI
		var idx := int(((angle + PI) / TAU) * 8) % 8
		buckets[idx] += 1.0 + (1.0 - d / detect_r) * 2.0   # 越近权重越高
	# 也统计 Boss
	for b in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b):
			continue
		var diff: Vector2 = b.global_position - player_pos
		var d := diff.length()
		if d < 1.0:
			continue
		found = true
		var angle := atan2(diff.y, diff.x)
		var idx := int(((angle + PI) / TAU) * 8) % 8
		buckets[idx] += 5.0   # Boss 权重很高
	if not found:
		# 退化：移动方向或向右
		var pv: Vector2 = _player.velocity
		if pv.length() > 4.0:
			return pv.normalized()
		return Vector2.RIGHT
	# 选最大权重的桶，方向为桶中心角度
	var best_idx := 0
	var best_w := -1.0
	for i in 8:
		if buckets[i] > best_w:
			best_w = buckets[i]
			best_idx = i
	var center_angle := (float(best_idx) + 0.5) / 8.0 * TAU - PI
	return Vector2(cos(center_angle), sin(center_angle))


func _cast_giant_sword(dir: Vector2) -> void:
	var gs := GIANT_SWORD_SCENE.instantiate()
	_player.get_parent().add_child(gs)
	gs.global_position = _player.global_position + dir * 30
	# 伤害以剑单次伤害为基准：巨剑冲撞是强力单次范围伤害 = 剑伤害 × 3
	var dmg := _player_sword_damage() * 3.0
	gs.setup(dir, dmg)
	GameEvents.hud_message.emit("巨剑冲撞!", 1.2)


func _cast_laser(dirs: Array) -> void:
	# 激光可朝多个方向发射（dirs 是方向数组）
	var dmg_per_sec := _player_sword_damage() * 6.0
	for d in dirs:
		var laser := preload("res://src/entities/PlayerLaser.gd").new()
		_player.get_parent().add_child(laser)
		laser.global_position = _player.global_position
		laser.setup(d)
		laser.damage_per_sec = dmg_per_sec
	GameEvents.hud_message.emit("毁灭激光!", 1.2)


func _cast_timestop() -> void:
	var field := preload("res://src/entities/TimeStopField.gd").new()
	_player.get_parent().add_child(field)
	field.global_position = _player.global_position
	GameEvents.hud_message.emit("时停力场!", 1.2)


## 以主方向为中心，生成 n 个方向（主方向 + 两侧均匀偏角 spread）。
## 例如 n=3, spread=0.35：返回 [主方向左偏0.35, 主方向, 主方向右偏0.35]。
func _multi_directions(main: Vector2, n: int, spread: float) -> Array:
	var dirs: Array = [main]
	if n <= 1:
		return dirs
	var base_angle := atan2(main.y, main.x)
	var step := spread * 2.0 / (n - 1)
	for i in n:
		var offset := -spread + step * i
		if offset == 0.0:
			continue   # 主方向已加入
		dirs.append(Vector2(cos(base_angle + offset), sin(base_angle + offset)))
	return dirs


func _player_sword_damage() -> float:
	var sm := _player.get_node_or_null("SwordManager") as SwordManager
	if sm:
		return sm.effective_damage()
	return 16.0


## 一局开始时重置（解锁与次数清空，重新靠拾取获取）。
func reset_for_new_run() -> void:
	for k in _unlocked:
		_unlocked[k] = false
		_charges[k] = 0
		_cooldowns[k] = 0.0


func get_cooldown(skill: String) -> float:
	return _cooldowns.get(skill, 0.0)


func is_unlocked(skill: String) -> bool:
	return _unlocked.get(skill, false)


func get_charges(skill: String) -> int:
	return _charges.get(skill, 0)
