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

var _selected: int = Difficulty.Preset.NORMAL
var _custom_panel_visible := false

@onready var _preset_buttons: HBoxContainer = %PresetButtons
@onready var _desc_label: RichTextLabel = %DescLabel
@onready var _start_btn: Button = %StartButton
@onready var _lb_btn: Button = %LeaderboardButton
@onready var _custom_btn: Button = %CustomButton
@onready var _custom_panel: Control = %CustomPanel


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
	_custom_btn.toggled.connect(_on_custom_toggled)
	# 自定义滑块
	%CustomStart.pressed.connect(func():
		_apply_custom()
		start_requested.emit()
	)
	%CustomBack.pressed.connect(func():
		_custom_panel_visible = false
		_custom_panel.visible = false
		_custom_btn.set_pressed_no_signal(false)
	)
	# 初始化滑块标签
	for sname in ["p_dmg", "p_hp", "xp", "e_hp", "e_dmg", "e_spd", "spawn", "b_hp", "b_early"]:
		var slider: HSlider = get_node_or_null("%S_" + sname)
		if slider:
			slider.value_changed.connect(_on_custom_slider_changed.bind(sname))
			_update_slider_label(sname)


func _on_preset_pressed(preset: int) -> void:
	# 如果自定义面板开着，点预设时关闭它
	if _custom_panel_visible:
		_custom_panel_visible = false
		_custom_panel.visible = false
		_custom_btn.set_pressed_no_signal(false)
	_select_preset(preset)


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
	if _custom_panel_visible:
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


func _on_custom_toggled(toggled: bool) -> void:
	_custom_panel_visible = toggled
	_custom_panel.visible = toggled
	if toggled:
		# 隐藏预设选中态
		_selected = Difficulty.Preset.CUSTOM


func _on_custom_slider_changed(_val: float, sname: String) -> void:
	_update_slider_label(sname)


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
