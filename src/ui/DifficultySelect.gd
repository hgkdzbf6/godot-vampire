class_name DifficultySelect
extends Control
## 标题 / 难度选择界面。游戏进入的第一个画面。
## 选择预设档或自定义参数后，点「开始游戏」进入战斗。

signal start_requested()
signal leaderboard_requested()
signal bestiary_requested()

const PRESETS := [
	Difficulty.Preset.EASY,
	Difficulty.Preset.NORMAL,
	Difficulty.Preset.HARD,
	Difficulty.Preset.NIGHTMARE,
]

# 滑块定义：[name, label, desc, min, max, step, default]
const SLIDER_DEFS := [
	["p_dmg", "剑伤害", "玩家剑的伤害倍率", 0.3, 3.0, 0.05, 1.0],
	["p_hp", "最大生命", "玩家最大生命值倍率", 0.3, 3.0, 0.05, 1.0],
	["xp", "经验获取", "击杀获得经验值倍率", 0.3, 3.0, 0.05, 1.0],
	["e_hp", "怪物血量", "普通敌人生命值倍率", 0.3, 3.0, 0.05, 1.0],
	["e_dmg", "怪物伤害", "敌人攻击伤害倍率", 0.3, 3.0, 0.05, 1.0],
	["e_spd", "怪物速度", "敌人移动速度倍率", 0.3, 2.0, 0.05, 1.0],
	["spawn", "刷怪频率", "敌人刷新频率倍率", 0.3, 2.5, 0.05, 1.0],
	["b_hp", "Boss血量", "Boss生命值倍率", 0.3, 3.0, 0.05, 1.0],
	["b_early", "Boss提前", "Boss提前登场秒数", 0.0, 120.0, 5.0, 0.0],
]

var _selected: int = Difficulty.Preset.NORMAL
var _custom_panel_visible := false
var _has_custom_changes := false

@onready var _preset_buttons: HBoxContainer = %PresetButtons
@onready var _desc_label: RichTextLabel = %DescLabel
@onready var _start_btn: Button = %StartButton
@onready var _lb_btn: Button = %LeaderboardButton
@onready var _custom_btn: Button = %CustomButton
@onready var _custom_panel: Control = %CustomPanel
@onready var _custom_overlay: ColorRect = %CustomOverlay


func _ready() -> void:
	# 连接预设按钮
	for i in PRESETS.size():
		var btn: Button = _preset_buttons.get_child(i)
		var preset: int = PRESETS[i]
		btn.pressed.connect(_on_preset_pressed.bind(preset))
	# 默认选中普通
	_select_preset(Difficulty.Preset.NORMAL)
	_start_btn.pressed.connect(func():
		_apply_selection()
		start_requested.emit()
	)
	_lb_btn.pressed.connect(func(): leaderboard_requested.emit())
	%BestiaryButton.pressed.connect(func(): bestiary_requested.emit())
	_custom_btn.pressed.connect(_on_custom_button_pressed)
	# 自定义面板按钮
	%CustomStart.pressed.connect(func():
		_apply_custom()
		start_requested.emit()
	)
	%CustomBack.pressed.connect(_close_custom_panel)
	_custom_overlay.gui_input.connect(_on_overlay_input)
	%CloseBtn.pressed.connect(_close_custom_panel)
	# 初始化滑块
	_setup_sliders()


func _setup_sliders() -> void:
	# 设置自定义面板样式
	_setup_panel_style()
	# 初始化滑块
	for def in SLIDER_DEFS:
		var sname: String = def[0]
		var slider: HSlider = get_node_or_null("%S_" + sname)
		var label: Label = get_node_or_null("%L_" + sname)
		var desc: Label = get_node_or_null("%D_" + sname)
		if slider:
			slider.value_changed.connect(_on_custom_slider_changed.bind(sname))
			_update_slider_label(sname)
		if desc:
			desc.text = def[2]


func _setup_panel_style() -> void:
	var panel: PanelContainer = %CustomPanelBG
	if panel:
		var style := StyleBoxFlat.new()
		style.content_margin_left = 24.0
		style.content_margin_top = 20.0
		style.content_margin_right = 24.0
		style.content_margin_bottom = 20.0
		style.bg_color = Color(0.1, 0.12, 0.18, 0.98)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.35, 0.45, 0.9)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		panel.add_theme_stylebox_override("panel", style)


func _on_preset_pressed(preset: int) -> void:
	_select_preset(preset)
	_has_custom_changes = false
	_update_custom_button_text()


func _select_preset(p: int) -> void:
	_selected = p
	# 更新按钮高亮
	for i in PRESETS.size():
		var btn: Button = _preset_buttons.get_child(i)
		btn.add_theme_stylebox_override("normal", _preset_style(i == p))
	# 描述
	var p_col := _preset_color(p)
	var name := Difficulty.preset_name(p)
	var desc := Difficulty.preset_desc(p)
	var params := Difficulty.make_preset(p)
	_desc_label.text = "[center][b][color=#%s]%s[/color][/b][/center]\n[center]%s[/center]\n\n" % [_col_hex(p_col), name, desc]
	_desc_label.text += "[center]" + _params_summary(params) + "[/center]"


func _params_summary(p: Difficulty.Params) -> String:
	var lines := []
	lines.append("剑伤害 ×%.2f   最大生命 ×%.2f" % [p.player_damage_mult, p.player_hp_mult])
	lines.append("经验 ×%.2f   刷怪频率 ×%.2f" % [p.xp_mult, p.spawn_rate_mult])
	lines.append("怪物血量 ×%.2f   伤害 ×%.2f   速度 ×%.2f" % [p.enemy_hp_mult, p.enemy_damage_mult, p.enemy_speed_mult])
	lines.append("Boss 血量 ×%.2f%s" % [p.boss_hp_mult, ("（提前%.0fs登场）" % p.boss_early_time) if p.boss_early_time > 0 else ""])
	return "\n".join(lines)


func _apply_selection() -> void:
	if _has_custom_changes:
		_apply_custom()
	else:
		Difficulty.set_preset(_selected)


func _apply_custom() -> void:
	var p := Difficulty.Params.new()
	p.player_damage_mult = %S_p_dmg.value
	p.player_hp_mult = %S_p_hp.value
	p.xp_mult = %S_xp.value
	p.enemy_hp_mult = %S_e_hp.value
	p.enemy_damage_mult = %S_e_dmg.value
	p.enemy_speed_mult = %S_e_spd.value
	p.spawn_rate_mult = %S_spawn.value
	p.boss_hp_mult = %S_b_hp.value
	p.boss_early_time = %S_b_early.value
	Difficulty.set_custom(p)


func _on_custom_button_pressed() -> void:
	_open_custom_panel()


func _open_custom_panel() -> void:
	_custom_panel_visible = true
	_custom_panel.visible = true
	_custom_overlay.visible = true
	# 重置滑块到当前预设值
	_reset_sliders_to_preset()


func _close_custom_panel() -> void:
	_custom_panel_visible = false
	_custom_panel.visible = false
	_custom_overlay.visible = false


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_custom_panel()


func _reset_sliders_to_preset() -> void:
	var params := Difficulty.make_preset(_selected)
	%S_p_dmg.value = params.player_damage_mult
	%S_p_hp.value = params.player_hp_mult
	%S_xp.value = params.xp_mult
	%S_e_hp.value = params.enemy_hp_mult
	%S_e_dmg.value = params.enemy_damage_mult
	%S_e_spd.value = params.enemy_speed_mult
	%S_spawn.value = params.spawn_rate_mult
	%S_b_hp.value = params.boss_hp_mult
	%S_b_early.value = params.boss_early_time
	_has_custom_changes = false
	_update_custom_button_text()
	# 更新所有标签
	for def in SLIDER_DEFS:
		_update_slider_label(def[0])


func _on_custom_slider_changed(_val: float, sname: String) -> void:
	_update_slider_label(sname)
	# 检测是否有变化
	_check_custom_changes()


func _check_custom_changes() -> void:
	var preset_params := Difficulty.make_preset(_selected)
	var has_change := false
	if absf(%S_p_dmg.value - preset_params.player_damage_mult) > 0.01:
		has_change = true
	elif absf(%S_p_hp.value - preset_params.player_hp_mult) > 0.01:
		has_change = true
	elif absf(%S_xp.value - preset_params.xp_mult) > 0.01:
		has_change = true
	elif absf(%S_e_hp.value - preset_params.enemy_hp_mult) > 0.01:
		has_change = true
	elif absf(%S_e_dmg.value - preset_params.enemy_damage_mult) > 0.01:
		has_change = true
	elif absf(%S_e_spd.value - preset_params.enemy_speed_mult) > 0.01:
		has_change = true
	elif absf(%S_spawn.value - preset_params.spawn_rate_mult) > 0.01:
		has_change = true
	elif absf(%S_b_hp.value - preset_params.boss_hp_mult) > 0.01:
		has_change = true
	elif absf(%S_b_early.value - preset_params.boss_early_time) > 0.1:
		has_change = true
	_has_custom_changes = has_change
	_update_custom_button_text()


func _update_custom_button_text() -> void:
	if _has_custom_changes:
		_custom_btn.text = "⚙ 自定义 *"
	else:
		_custom_btn.text = "⚙ 自定义"


func _update_slider_label(sname: String) -> void:
	var slider: HSlider = get_node_or_null("%S_" + sname)
	var label: Label = get_node_or_null("%L_" + sname)
	if slider and label:
		if sname == "b_early":
			label.text = "%.0f 秒" % slider.value
		else:
			label.text = "×%.2f" % slider.value


func _preset_style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	if selected:
		sb.bg_color = Color(0.2, 0.28, 0.45, 0.95)
		sb.border_color = Color("ffe34a")
		sb.border_width_bottom = 3
		sb.border_width_top = 3
		sb.border_width_left = 3
		sb.border_width_right = 3
	else:
		sb.bg_color = Color(0.12, 0.14, 0.2, 0.9)
		sb.border_color = Color(0.3, 0.34, 0.42, 0.8)
		sb.border_width_bottom = 1
		sb.border_width_top = 1
		sb.border_width_left = 1
		sb.border_width_right = 1
	return sb


func _preset_color(p: int) -> Color:
	match p:
		Difficulty.Preset.EASY: return Color("8fffae")
		Difficulty.Preset.NORMAL: return Color("7be0ff")
		Difficulty.Preset.HARD: return Color("ffa14a")
		Difficulty.Preset.NIGHTMARE: return Color("ff5a5a")
		_: return Color.WHITE


func _col_hex(c: Color) -> String:
	return "%02x%02x%02x" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
