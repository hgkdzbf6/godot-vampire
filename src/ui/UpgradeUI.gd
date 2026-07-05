class_name UpgradeUI
extends CanvasLayer
## 升级三选一面板。打开时暂停游戏，玩家用鼠标点击或按 1/2/3 选择。
## 关键：本界面 process_mode=ALWAYS，暂停期间仍能响应输入。

signal chosen(upgrade: Dictionary)

@onready var _bg: ColorRect = $BG
@onready var _title: Label = $Panel/VBox/Title
@onready var _cards_container: HBoxContainer = $Panel/VBox/Cards
@onready var _hint: Label = $Panel/VBox/Hint

const CARD_SCENE := preload("res://src/ui/UpgradeCard.tscn")
const CARD_GAP := 40.0

var _current_choices: Array = []
var _taken: Dictionary = {}    # id -> 已选择次数
var _cards: Array[UpgradeCard] = []


func _ready() -> void:
	# 应用 UI 缩放（递归缩放所有子控件的字号）
	UIScale.apply_font_scale(self)
	UIScale.scale_changed.connect(func(_s): UIScale.apply_font_scale(self))
	# 关键：暂停期间本界面必须继续响应输入，否则玩家无法选牌
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_panel()
	GameEvents.level_up_opened.connect(_on_opened)


func _process(delta: float) -> void:
	if visible:
		# 背景渐暗（整体降亮度，突出升级界面）
		_bg.modulate.a = lerp(_bg.modulate.a, 0.55, min(1.0, delta * 6.0))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("upgrade_1") and _cards.size() >= 1:
		_select(0)
	elif event.is_action_pressed("upgrade_2") and _cards.size() >= 2:
		_select(1)
	elif event.is_action_pressed("upgrade_3") and _cards.size() >= 3:
		_select(2)


func open(choices: Array) -> void:
	_current_choices = choices
	# 清理旧卡片
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	# 设置容器间距
	_cards_container.add_theme_constant_override("separation", int(CARD_GAP))
	# 依次创建卡片（带递增入场延迟，实现依次弹出）
	for i in choices.size():
		var card: UpgradeCard = CARD_SCENE.instantiate()
		_cards_container.add_child(card)
		card.setup(choices[i], i, i * 0.12)   # 每张延迟 0.12s
		card.selected.connect(_on_card_selected)
		_cards.append(card)
	# 开启暂停 + 显示
	get_tree().paused = true
	show_panel()


func show_panel() -> void:
	_bg.modulate.a = 0.0
	visible = true


func hide_panel() -> void:
	visible = false


func _on_opened(choices: Array) -> void:
	open(choices)


func _on_card_selected(idx: int) -> void:
	_select(idx)


func _select(idx: int) -> void:
	if idx < 0 or idx >= _current_choices.size():
		return
	var u: Dictionary = _current_choices[idx]
	var idd: String = u["id"]
	_taken[idd] = _taken.get(idd, 0) + 1
	hide_panel()
	get_tree().paused = false
	chosen.emit(u)
	GameEvents.upgrade_selected.emit(u)
	GameEvents.upgrade_applied.emit(u)
