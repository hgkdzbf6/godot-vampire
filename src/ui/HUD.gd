class_name HUD
extends CanvasLayer
## 顶层 HUD：HP/XP 条、计时器、击杀数、Boss 血条、消息提示。

@onready var _hp_bar: ProgressBar = $Margin/VBox/HPBar
@onready var _hp_label: Label = $Margin/VBox/HPLabel
@onready var _xp_bar: ProgressBar = $Margin/VBox/XPBar
@onready var _xp_label: Label = $Margin/VBox/XPLabel
@onready var _level_label: Label = $Margin/VBox/LevelLabel
@onready var _timer_label: Label = $TopRight/TimerLabel
@onready var _kills_label: Label = $TopRight/KillsLabel
@onready var _boss_bar: ProgressBar = $Boss/BossBar
@onready var _boss_label: Label = $Boss/BossLabel
@onready var _message_label: Label = $Center/Message
@onready var _message_tween: Tween


var _kills := 0
var _hp_bar_style: StyleBoxFlat
var _hp_bar_style_yellow: StyleBoxFlat
var _hp_bar_style_red: StyleBoxFlat


func _ready() -> void:
	GameEvents.player_damaged.connect(_on_hp_changed)
	GameEvents.player_healed.connect(_on_hp_changed)
	GameEvents.player_xp_changed.connect(_on_xp_changed)
	GameEvents.player_leveled_up.connect(_on_leveled_up)
	GameEvents.hud_timer_changed.connect(_on_timer)
	GameEvents.hud_kills_changed.connect(_on_kills)
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_health_changed.connect(_on_boss_hp)
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.hud_message.connect(_on_message)
	_boss_bar.visible = false
	_boss_label.visible = false
	# 初始化 HP 血条颜色样式
	_hp_bar_style = StyleBoxFlat.new()
	_hp_bar_style.bg_color = Color(0.2, 0.8, 0.2)  # 绿色
	_hp_bar_style.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("fill", _hp_bar_style)
	_hp_bar_style_yellow = StyleBoxFlat.new()
	_hp_bar_style_yellow.bg_color = Color(0.9, 0.8, 0.2)  # 黄色
	_hp_bar_style_yellow.set_corner_radius_all(3)
	_hp_bar_style_red = StyleBoxFlat.new()
	_hp_bar_style_red.bg_color = Color(0.9, 0.2, 0.2)  # 红色
	_hp_bar_style_red.set_corner_radius_all(3)


func _on_hp_changed(cur: float, mx: float) -> void:
	_hp_bar.max_value = mx
	_hp_bar.value = cur
	_hp_label.text = "HP %d / %d" % [int(cur), int(mx)]
	# 根据血量百分比改变颜色
	var ratio := cur / mx
	if ratio > 0.5:
		_hp_bar.add_theme_stylebox_override("fill", _hp_bar_style)
	elif ratio > 0.1:
		_hp_bar.add_theme_stylebox_override("fill", _hp_bar_style_yellow)
	else:
		_hp_bar.add_theme_stylebox_override("fill", _hp_bar_style_red)


func _on_xp_changed(xp: int, xp_next: int) -> void:
	_xp_bar.max_value = max(1, xp_next)
	_xp_bar.value = xp
	_xp_label.text = "XP %d / %d" % [xp, xp_next]


func _on_leveled_up(level: int) -> void:
	_level_label.text = "Lv. %d" % level
	_level_label.pivot_offset = _level_label.size * 0.5
	var t := create_tween()
	t.tween_property(_level_label, "scale", Vector2(1.4, 1.4), 0.12)
	t.tween_property(_level_label, "scale", Vector2.ONE, 0.18)


func _on_timer(seconds: float) -> void:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	_timer_label.text = "%02d:%02d" % [m, s]


func _on_kills(k: int) -> void:
	_kills = k
	_kills_label.text = "击杀 %d" % _kills


func _on_boss_spawned(_b: Node) -> void:
	_boss_bar.visible = true
	_boss_label.visible = true
	_boss_label.text = "深渊领主"


## 设置 Boss 名字（HUD 血条上方标签）。
func set_boss_name(name: String) -> void:
	_boss_label.text = name


func _on_boss_hp(cur: float, mx: float) -> void:
	_boss_bar.max_value = mx
	_boss_bar.value = cur


func _on_boss_defeated() -> void:
	var t := create_tween()
	t.tween_property(_boss_bar, "modulate:a", 0.0, 0.6)
	t.tween_callback(func(): _boss_bar.visible = false; _boss_label.visible = false)
	_boss_bar.modulate.a = 1.0


func _on_message(text: String, duration: float) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(duration * 0.6)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, duration * 0.4)


## 重置 HUD 状态（新游戏开始时调用）
func reset() -> void:
	_boss_bar.visible = false
	_boss_label.visible = false
	_boss_bar.modulate.a = 1.0
	_message_label.modulate.a = 0.0
