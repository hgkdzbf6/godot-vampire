class_name StatsPanel
extends Control
## 游玩中的属性统计面板。
## 显示玩家当前所有关键数值：攻击力、剑数、转速、半径、暴击、元素、难度、关卡等。
## 按「i」键或点击右上角信息按钮切换显隐。

@onready var _content: VBoxContainer = %Content
@onready var _toggle_btn: Button = %ToggleButton
@onready var _hp: Label = %L_hp
@onready var _atk: Label = %L_atk
@onready var _swords: Label = %L_swords
@onready var _rot: Label = %L_rot
@onready var _radius: Label = %L_radius
@onready var _crit: Label = %L_crit
@onready var _pierce: Label = %L_pierce
@onready var _lifesteal: Label = %L_lifesteal
@onready var _element: Label = %L_element
@onready var _difficulty: Label = %L_difficulty
@onready var _stage: Label = %L_stage
@onready var _kills: Label = %L_kills
@onready var _regen: Label = %L_regen

var _player: Player = null
var _sword_mgr: SwordManager = null
var _stage_idx: int = 0
var _stage_total: int = 0
var _kills_n: int = 0


func set_stage(idx: int, total: int) -> void:
	_stage_idx = idx
	_stage_total = total


func set_kills(n: int) -> void:
	_kills_n = n


func _ready() -> void:
	# 应用 UI 缩放（递归缩放所有子控件的字号）
	UIScale.apply_font_scale(self)
	UIScale.scale_changed.connect(func(_s): UIScale.apply_font_scale(self))
	_toggle_btn.pressed.connect(toggle_visible)
	_content.visible = true
	# 注册 i 键切换（如果输入动作不存在则跳过）
	if not InputMap.has_action("toggle_stats"):
		InputMap.add_action("toggle_stats")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_I
		InputMap.action_add_event("toggle_stats", ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		toggle_visible()


func bind_player(player: Player) -> void:
	_player = player
	if player:
		_sword_mgr = player.get_node_or_null("SwordManager") as SwordManager


func toggle_visible() -> void:
	_content.visible = not _content.visible


func _process(_delta: float) -> void:
	if not _content.visible:
		return
	# 自动查找玩家（延迟绑定，避免时序问题）
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player and not _sword_mgr:
			_sword_mgr = _player.get_node_or_null("SwordManager") as SwordManager
	if not is_instance_valid(_player):
		return
	refresh()


func refresh() -> void:
	if not _player:
		return
	_hp.text = "生命  %d / %d" % [int(_player.hp), int(_player.max_hp)]
	if _sword_mgr:
		_atk.text = "攻击力  %.1f" % _sword_mgr.effective_damage()
		_swords.text = "剑数  %d" % _sword_mgr.base_count
		_rot.text = "转速  %.2f" % _sword_mgr.effective_rot_speed()
		_radius.text = "半径  %.0f" % _sword_mgr.radius
		_crit.text = "暴击  %d%% ×%.1f" % [int(_sword_mgr.crit_chance * 100), _sword_mgr.crit_mult]
		_pierce.text = "穿透  %d" % _sword_mgr.pierce
		_lifesteal.text = "吸血  %.1f" % _sword_mgr.lifesteal
		_element.text = "元素  " + GameData.element_name(_sword_mgr.element)
	_regen.text = "回复  %.1f/s" % _player.regen_per_sec
	_difficulty.text = "难度  " + Difficulty.preset_name()
	_stage.text = "关卡  第%d/%d关" % [_stage_idx + 1, _stage_total]
	_kills.text = "击杀  %d" % _kills_n
