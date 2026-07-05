extends Node
## 全局事件总线（Autoload 单例）。
## 所有跨模块通信通过这里的信号解耦。

# 玩家
signal player_damaged(current_hp: float, max_hp: float)
signal player_healed(current_hp: float, max_hp: float)
signal player_xp_changed(xp: int, xp_to_next: int)
signal player_leveled_up(level: int)
signal player_died

# 敌人 / 经验
signal enemy_killed(enemy)
signal xp_collected(amount: int)

# 升级
signal level_up_opened(choices: Array)
signal upgrade_selected(upgrade: Dictionary)
signal upgrade_applied(upgrade: Dictionary)

# Boss
signal boss_spawned(boss)
signal boss_health_changed(current: float, maximum: float)
signal boss_defeated

# HUD 杂项
signal hud_timer_changed(seconds: float)
signal hud_kills_changed(kills: int)
signal hud_message(text: String, duration: float)

# 游戏流程
signal game_started
signal game_over

# 主动技能
signal skill_state_changed(skill_id: String, unlocked: bool, charges: int, cd_remaining: float, cd_total: float)


func _ready() -> void:
	_setup_input_map()
	_setup_cjk_font()


## 注册输入动作，避免 ini 中冗长的 InputEvent 序列化。
func _setup_input_map() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("pause", [KEY_ESCAPE, KEY_P])
	_add_key_action("restart", [KEY_R])
	_add_key_action("upgrade_1", [KEY_1, KEY_KP_1])
	_add_key_action("upgrade_2", [KEY_2, KEY_KP_2])
	_add_key_action("upgrade_3", [KEY_3, KEY_KP_3])


func _add_key_action(action_name: String, keycodes: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for k in keycodes:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)


## 设置支持中文（CJK）的默认字体。
## 使用项目内置的 Noto Sans SC 字体文件（OFL 开源，可自由分发），
## 彻底不依赖系统字体，保证在任何机器上中文都能正常显示。
func _setup_cjk_font() -> void:
	var loaded = load("res://assets/fonts/NotoSansSC-Regular.otf")
	if loaded == null or not (loaded is Font):
		push_error("[GameEvents] 内置中文字体加载失败，回退到默认字体")
		return
	var font: Font = loaded
	var theme := ThemeDB.get_default_theme()
	# 给所有使用字体的控件类型设置默认字体
	for type_name in ["", "Label", "Button", "LineEdit", "ProgressBar", "RichTextLabel"]:
		theme.set_font("font", type_name, font)
	theme.default_font = font
