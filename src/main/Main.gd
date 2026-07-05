class_name Main
extends Node2D
## 游戏主控制器（多关卡状态机）：
## - MENU：难度选择
## - STAGE_TRANSITION：关卡过渡展示
## - PLAYING：刷怪 / 经验 / 升级 / Boss / 死亡结算
## - GAME_OVER：结算面板（含名称输入与排行榜）
##
## 多关卡：Boss 击败 → 进入下一关（保留成长），全关卡通关 = 胜利（记录总时间）。
## 难度乘数（Difficulty）× 关卡乘数（stages）叠加应用到刷怪、敌人、Boss。

enum State { MENU, STAGE_TRANSITION, PLAYING, PAUSED, GAME_OVER }

@onready var _player: Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _hud: CanvasLayer = $HUD
@onready var _upgrade_ui: CanvasLayer = $UpgradeUI
@onready var _gameover_panel: Control = $GameOver
@onready var _diff_select: Control = $DifficultySelect
@onready var _lb_view: Control = $LeaderboardView
@onready var _bestiary: Control = $Bestiary
@onready var _pause_menu: Control = $PauseMenu
@onready var _bg: ColorRect = $Background
@onready var _stage_label: Label = $StageLabel

const ENEMY_SCENE := preload("res://src/entities/Enemy.tscn")
const BOSS_SCENE := preload("res://src/entities/Boss.tscn")
const PICKUP_SCENE := preload("res://src/entities/Pickup.tscn")

var _state: int = State.MENU
var _stage_index: int = 0
var _stage_time: float = 0.0          # 当前关卡内已过时间
var _total_time: float = 0.0          # 全程累计时间（胜利记录用）
var _spawn_timer: float = 0.0
var _spawn_interval: float = 1.4
var _pickup_timer: float = 6.0
var _cull_timer: float = 1.0
var _kills: int = 0
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _upgrade_taken: Dictionary = {}
var _stage_cfg: Dictionary = {}        # 当前关卡配置
var _state_before_pause: int = State.PLAYING   # 暂停前状态，用于恢复
var _transition_timer: float = 0.0     # 关卡过渡倒计时


func _ready() -> void:
	_player.global_position = Vector2.ZERO
	_spawn_interval = GameData.SPAWN_INTERVAL_START
	GameEvents.xp_collected.connect(_on_xp_collected)
	GameEvents.player_leveled_up.connect(_on_player_leveled_up)
	GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.player_died.connect(_on_player_died)
	GameEvents.game_over.connect(_on_game_over)
	_diff_select.start_requested.connect(_on_start_game)
	_diff_select.leaderboard_requested.connect(_show_leaderboard_from_menu)
	_diff_select.bestiary_requested.connect(_show_bestiary_from_menu)
	_bestiary.back_requested.connect(_on_bestiary_back)
	_lb_view.back_requested.connect(_on_lb_back)
	_gameover_panel.play_again_requested.connect(_on_play_again)
	_gameover_panel.back_to_menu_requested.connect(_on_back_to_menu)
	_pause_menu.resume_requested.connect(_on_pause_resume)
	_pause_menu.retry_stage_requested.connect(_on_pause_retry_stage)
	_pause_menu.restart_game_requested.connect(_on_pause_restart_game)
	_pause_menu.bestiary_requested.connect(_on_pause_bestiary)
	_pause_menu.back_to_menu_requested.connect(_on_back_to_menu)
	_pause_menu.visible = false
	_stage_label.visible = false
	# 全屏菜单 UI 必须挂在 CanvasLayer 下，否则作为 Node2D 子节点时 Control 的
	# anchor 布局不生效（size 为 0，看不到内容）。运行时创建 CanvasLayer 并 reparent。
	var menu_canvas := CanvasLayer.new()
	menu_canvas.name = "MenuCanvas"
	menu_canvas.layer = 10   # 在游戏世界之上
	add_child(menu_canvas)
	for ui in [_diff_select, _lb_view, _bestiary, _gameover_panel, _pause_menu]:
		if ui and ui.get_parent() == self:
			# 重新挂到 CanvasLayer
			remove_child(ui)
			menu_canvas.add_child(ui)
	_enter_menu()


func _unhandled_input(event: InputEvent) -> void:
	# ESC 暂停切换（仅游戏中）
	if event.is_action_pressed("pause"):
		if _state == State.PLAYING:
			_enter_pause()
		elif _state == State.PAUSED:
			_exit_pause()
		get_viewport().set_input_as_handled()


func _process_playing(delta: float) -> void:
	_stage_time += delta
	_total_time += delta
	GameEvents.hud_timer_changed.emit(_stage_time)

	var dp := Difficulty.current_params
	# 关卡乘数
	var sm_hp := float(_stage_cfg.get("enemy_hp_mult", 1.0))
	var sm_dmg := float(_stage_cfg.get("enemy_damage_mult", 1.0))
	var sm_spawn := float(_stage_cfg.get("spawn_mult", 1.0))
	var combined_spawn := dp.spawn_rate_mult * sm_spawn

	# 刷怪节奏（难度 × 关卡）
	var interval_min := GameData.SPAWN_INTERVAL_MIN / combined_spawn
	_spawn_interval = maxf(interval_min, _spawn_interval * pow(GameData.SPAWN_INTERVAL_DECAY, delta))
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_timer = _spawn_interval / combined_spawn
		_spawn_wave()

	# Buff 道具
	_pickup_timer -= delta
	if _pickup_timer <= 0:
		_pickup_timer = GameData.PICKUP_SPAWN_INTERVAL + randf_range(-GameData.PICKUP_SPAWN_JITTER, GameData.PICKUP_SPAWN_JITTER)
		_spawn_pickup()

	# 怪物上限
	_cull_timer -= delta
	if _cull_timer <= 0:
		_cull_timer = GameData.ENEMY_CULL_CHECK_INTERVAL
		_cull_enemies()

	# Boss 触发（难度提前 + 关卡时长）
	var boss_time := maxf(20.0, _stage_cfg.get("duration", 90.0) - Difficulty.current_params.boss_early_time)
	if not _boss_spawned and _stage_time >= boss_time:
		_spawn_boss()


# ============================================================
#  关卡 / 状态切换
# ============================================================
func _enter_menu() -> void:
	_state = State.MENU
	_set_gameplay_active(false)
	_diff_select.visible = true
	_lb_view.visible = false
	_bestiary.visible = false
	_gameover_panel.hide_panel()
	_pause_menu.visible = false
	_hud.visible = false
	_stage_label.visible = false
	# 取消暂停（从暂停菜单返回时）
	get_tree().paused = false
	# 恢复相机缩放
	if _camera:
		_camera.zoom = Vector2(1.3, 1.3)


func _show_leaderboard_from_menu() -> void:
	_diff_select.visible = false
	_lb_view.visible = true
	_lb_view.refresh()


func _on_lb_back() -> void:
	_diff_select.visible = true
	_lb_view.visible = false


func _show_bestiary_from_menu() -> void:
	_diff_select.visible = false
	_bestiary.visible = true


func _on_bestiary_back() -> void:
	_bestiary.visible = false
	# 根据当前状态决定返回到哪
	if _state == State.PAUSED:
		_pause_menu.visible = true
	else:
		_diff_select.visible = true


# ============================================================
#  暂停菜单
# ============================================================
func _enter_pause() -> void:
	_state_before_pause = _state
	_state = State.PAUSED
	get_tree().paused = true
	_pause_menu.open()


func _exit_pause() -> void:
	_pause_menu.close()
	get_tree().paused = false
	_state = _state_before_pause


func _on_pause_resume() -> void:
	_exit_pause()


## 重打本关：重置玩家成长，从当前关卡重新开始。
func _on_pause_retry_stage() -> void:
	_pause_menu.close()
	get_tree().paused = false
	_reset_player_for_run()
	_upgrade_taken.clear()
	_kills = 0
	_enter_stage(_stage_index)


## 重新开始游戏：从第1关开始。
func _on_pause_restart_game() -> void:
	_pause_menu.close()
	get_tree().paused = false
	_start_new_run()


## 暂停时查看图鉴。
func _on_pause_bestiary() -> void:
	_pause_menu.visible = false
	_bestiary.visible = true


func _on_start_game() -> void:
	_diff_select.visible = false
	_lb_view.visible = false
	_total_time = 0.0
	_stage_index = 0
	_start_new_run()


## 开始一局新游戏（从第一关开始，重置玩家成长）。
func _start_new_run() -> void:
	_clear_entities()
	_reset_player_for_run()
	_total_time = 0.0
	_stage_index = 0
	_kills = 0   # 新一局击杀数清零
	_upgrade_taken.clear()
	_enter_stage(0)


## 进入指定关卡（保留玩家成长与累计击杀，重置关卡内状态）。
func _enter_stage(idx: int) -> void:
	_stage_index = idx
	if idx >= GameData.STAGE_COUNT:
		# 全部关卡通关 = 胜利
		_show_victory()
		return
	_stage_cfg = GameData.STAGES[idx]
	_stage_time = 0.0
	# _kills 跨关卡累计保留（仅 _start_new_run 清零）
	_boss_spawned = false
	_boss_defeated = false
	_spawn_interval = GameData.SPAWN_INTERVAL_START
	_spawn_timer = 0.0
	_pickup_timer = 6.0
	_cull_timer = 1.0
	_clear_entities()
	# 背景色
	var bg_col := Color.from_string(String(_stage_cfg.get("bg_color", "#10141f")), Color("10141f"))
	_bg.color = bg_col
	# 相机缩放（高关卡拉远视野，防止放大的敌人/Boss 占满屏幕）
	var zoom: float = float(_stage_cfg.get("camera_zoom", 1.3))
	if _camera:
		_camera.zoom = Vector2(zoom, zoom)
	# 更新统计面板的关卡信息
	var sp := _hud.get_node_or_null("StatsPanel") as StatsPanel
	if sp:
		sp.set_stage(idx, GameData.STAGE_COUNT)
	# 关卡过渡展示
	_state = State.STAGE_TRANSITION
	_show_stage_transition()
	# 用 _process 计时过渡（不依赖 SceneTreeTimer，更可靠）
	_transition_timer = 2.2


func _process(delta: float) -> void:
	match _state:
		State.PLAYING:
			_process_playing(delta)
		State.STAGE_TRANSITION:
			# 关卡过渡倒计时，到点进入游戏
			_transition_timer -= delta
			if _transition_timer <= 0.0:
				_begin_play_after_transition()
		_:
			pass


func _begin_play_after_transition() -> void:
	if _state != State.STAGE_TRANSITION:
		return
	_stage_label.visible = false
	_state = State.PLAYING
	_set_gameplay_active(true)
	_hud.visible = true
	get_tree().paused = false
	GameEvents.hud_kills_changed.emit(_kills)
	GameEvents.hud_message.emit("第 %d 关 · %s" % [_stage_index + 1, _stage_cfg.get("name", "")], 2.0)


func _show_stage_transition() -> void:
	_stage_label.text = "%s\n第 %d 关 / %d" % [_stage_cfg.get("name", ""), _stage_index + 1, GameData.STAGE_COUNT]
	_stage_label.visible = true
	_stage_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_stage_label, "modulate:a", 1.0, 0.4)
	t.tween_interval(1.4)
	t.tween_property(_stage_label, "modulate:a", 0.0, 0.4)


func _reset_player_for_run() -> void:
	_player.reset_for_new_run()
	var sm := _player.get_node("SwordManager") as SwordManager
	if sm:
		sm.reset_for_new_run()


func _on_play_again() -> void:
	_start_new_run()


func _on_back_to_menu() -> void:
	_enter_menu()


# ============================================================
#  Boss 击败 → 下一关 / 胜利
# ============================================================
func _on_boss_defeated() -> void:
	_boss_defeated = true
	GameEvents.hud_message.emit("关卡通过！深渊领主已陨落", 3.0)
	# 清理当前关残留敌人，给短暂喘息
	call_deferred("_after_boss_defeated")


func _after_boss_defeated() -> void:
	# 进入下一关（保留成长）。若已是最后一关则胜利。
	var next := _stage_index + 1
	if next >= GameData.STAGE_COUNT:
		_show_victory()
	else:
		GameEvents.hud_message.emit("进入下一关...", 2.0)
		_enter_stage(next)


func _show_victory() -> void:
	_state = State.GAME_OVER
	_set_gameplay_active(false)
	# 胜利记录用总时间
	_gameover_panel.show_victory(_total_time, _kills, _player.level)


# ============================================================
#  实体清理 / 玩家激活
# ============================================================
func _clear_entities() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.set_deferred("_dead", true)
			e.queue_free()
	for e in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e):
			e.queue_free()
	for g in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(g):
			g.queue_free()
	for g in get_tree().get_nodes_in_group("xp_gem"):
		if is_instance_valid(g):
			g.queue_free()
	for c in get_tree().get_nodes_in_group("damage_number"):
		if is_instance_valid(c):
			c.queue_free()


func _set_gameplay_active(active: bool) -> void:
	_player.set_physics_process(active)
	_player.visible = active
	var sm := _player.get_node_or_null("SwordManager")
	if sm:
		sm.set_physics_process(active)
		for s in sm.get_children():
			if is_instance_valid(s):
				s.set_process(active)


# ============================================================
#  刷怪（难度 × 关卡乘数）
# ============================================================
func _spawn_wave() -> void:
	var pool_min := float(_stage_cfg.get("enemy_pool_min_time", 0.0))
	var pool := EnemyTypes.pool_for(_stage_time, pool_min)
	if pool.is_empty():
		return
	var dp := Difficulty.current_params
	var sm_hp := float(_stage_cfg.get("enemy_hp_mult", 1.0))
	var sm_dmg := float(_stage_cfg.get("enemy_damage_mult", 1.0))
	var visual_scale := float(_stage_cfg.get("enemy_visual_scale", 1.0))
	var n := GameData.SPAWN_WAVE_COUNT_BASE + int(_stage_time / GameData.SPAWN_WAVE_COUNT_TIME_DIVISOR)
	n = clamp(n, 1, GameData.SPAWN_WAVE_COUNT_MAX)
	# 当前关卡可选的等级范围（关卡越高，怪物等级越高）
	var grade_min := clampi(_stage_index, 0, 3)         # 第1关0, 第2关1, 第3关2
	var grade_max := clampi(_stage_index + 1, 1, 4)     # 第1关1, 第2关2, 第3关3
	for i in n:
		var t: EnemyTypes.Type = EnemyTypes.pick(pool)
		var e: Enemy = ENEMY_SCENE.instantiate()
		add_child(e)
		var a := randf() * TAU
		var pos := _player.global_position + Vector2(cos(a), sin(a)) * GameData.SPAWN_RADIUS
		e.global_position = pos
		# 抽取本只怪的等级
		var gid := randi_range(grade_min, grade_max)
		var grade := GameData.monster_grade(gid)
		var g_hp := float(grade.get("hp_mult", 1.0))
		var g_dmg := float(grade.get("dmg_mult", 1.0))
		var g_spd := float(grade.get("speed_mult", 1.0))
		var g_vis := float(grade.get("visual_mult", 1.0))
		# 基础值 × 时间成长 × 难度 × 关卡 × 等级
		var hp_scale := (1.0 + _stage_time * GameData.ENEMY_HP_SCALE_PER_SECOND) * dp.enemy_hp_mult * sm_hp * g_hp
		e.configure(
			t.max_hp * hp_scale,
			t.speed * dp.enemy_speed_mult * g_spd,
			t.dmg * dp.enemy_damage_mult * sm_dmg * g_dmg,
			t.xp,
			t.color,
			t.elite,
			t.shape,
			t.movement
		)
		# 设置等级星级（供敌人头顶显示）
		e.set_grade(int(grade.get("stars", 2)), String(grade.get("name", "普通")))
		# 高关卡视觉放大 × 等级视觉放大
		e.apply_visual_scale(visual_scale * g_vis)


# ---- 怪物数量上限管理 ----
func _cull_enemies() -> void:
	var max_count := GameData.ENEMY_MAX_COUNT
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	var ppos := _player.global_position
	var cull_r := GameData.ENEMY_CULL_RADIUS
	for e in enemies:
		if not is_instance_valid(e) or e.is_in_group("boss"):
			continue
		if e.global_position.distance_to(ppos) > cull_r:
			e.set_deferred("_dead", true)
			e.queue_free()
			enemies.erase(e)
	if enemies.size() <= max_count:
		return
	enemies.sort_custom(func(a, b):
		if not is_instance_valid(a): return false
		if not is_instance_valid(b): return true
		if a.is_in_group("boss"): return false
		if b.is_in_group("boss"): return true
		return a.global_position.distance_to(ppos) > b.global_position.distance_to(ppos)
	)
	var excess := enemies.size() - max_count
	var removed := 0
	for e in enemies:
		if removed >= excess:
			break
		if not is_instance_valid(e) or e.is_in_group("boss"):
			continue
		e.set_deferred("_dead", true)
		e.queue_free()
		removed += 1


# ---- Buff 道具刷新 ----
func _spawn_pickup() -> void:
	var types: Array = GameData.PICKUP_TYPES
	if types.is_empty():
		return
	var total := 0.0
	for t in types:
		total += float(t.get("weight", 1.0))
	var r := randf() * total
	var chosen: Dictionary = types[0]
	for t in types:
		r -= float(t.get("weight", 1.0))
		if r <= 0.0:
			chosen = t
			break
	var p := PICKUP_SCENE.instantiate()
	add_child(p)
	var a := randf() * TAU
	var dist := randf_range(GameData.PICKUP_SPAWN_RADIUS_MIN, GameData.PICKUP_SPAWN_RADIUS_MAX)
	p.global_position = _player.global_position + Vector2(cos(a), sin(a)) * dist
	p.setup(chosen)


# ---- 经验 / 升级 ----
func _on_xp_collected(amount: int) -> void:
	_player.add_xp(int(round(amount * Difficulty.current_params.xp_mult)))


func _on_player_leveled_up(_level: int) -> void:
	var choices := UpgradeDefs.roll(GameData.UPGRADE_CHOICE_COUNT, _upgrade_taken, Difficulty.current_preset)
	if choices.is_empty():
		return
	GameEvents.level_up_opened.emit(choices)


func _on_enemy_killed(_e: Node) -> void:
	_kills += 1
	GameEvents.hud_kills_changed.emit(_kills)
	var sp := _hud.get_node_or_null("StatsPanel") as StatsPanel
	if sp:
		sp.set_kills(_kills)


# ---- Boss ----
func _spawn_boss() -> void:
	_boss_spawned = true
	# 取当前关卡对应的 Boss 数据（bestiary_bosses 按 stage）
	var bosses: Array = GameData.BESTIARY_BOSSES
	var boss_data: Dictionary = bosses[0] if bosses.size() > 0 else {}
	for bd in bosses:
		if int(bd.get("stage", 1)) == _stage_index + 1:
			boss_data = bd
			break
	var boss_name: String = String(boss_data.get("name", "深渊领主"))
	GameEvents.hud_message.emit("%s 降临！" % boss_name, 2.5)
	var b: Boss = BOSS_SCENE.instantiate()
	add_child(b)
	# 用 bestiary 数据初始化（关卡 Boss 属性）
	if not boss_data.is_empty():
		b.setup_from_bestiary(boss_data)
	# Boss 体积随关卡变大（高关卡 Boss 更大）
	var boss_visual := float(_stage_cfg.get("enemy_visual_scale", 1.0))
	b.apply_visual_scale(boss_visual)
	var a := randf() * TAU
	b.global_position = _player.global_position + Vector2(cos(a), sin(a)) * 360.0


func _on_boss_spawned(b: Node) -> void:
	# 更新 HUD 的 Boss 名字
	if b and "get" in b and b.get("_display_name"):
		var hud := _hud as HUD
		if hud and hud.has_method("set_boss_name"):
			hud.set_boss_name(String(b._display_name))


# ---- 失败 ----
func _on_player_died() -> void:
	pass


func _on_game_over() -> void:
	_state = State.GAME_OVER
	_set_gameplay_active(false)
	# 失败记录用总时间
	_gameover_panel.show_defeat(_total_time, _kills, _player.level)
