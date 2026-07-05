class_name GameOverPanel
extends Control
## 死亡 / 胜利结算面板。
## 流程：显示结果统计 → 输入名称 → 提交 → 显示排行榜 → 再玩 / 返回菜单。

signal play_again_requested()
signal back_to_menu_requested()

var _last_score: int = 0
var _last_rank: int = -1
var _result_is_win: bool = false
var _result_data: Dictionary = {}


func _ready() -> void:
	# 应用 UI 缩放（递归缩放所有子控件的字号）
	UIScale.apply_font_scale(self)
	UIScale.scale_changed.connect(func(_s): UIScale.apply_font_scale(self))
	# 结算面板在游戏流程中始终可交互（即使树被暂停）
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_panel()
	%SubmitButton.pressed.connect(_on_submit)
	%PlayAgainButton.pressed.connect(func():
		hide_panel()
		play_again_requested.emit()
	)
	%BackMenuButton.pressed.connect(func():
		hide_panel()
		back_to_menu_requested.emit()
	)
	%LeaderboardAgainButton.pressed.connect(func():
		hide_panel()
		play_again_requested.emit()
	)
	%LeaderboardMenuButton.pressed.connect(func():
		hide_panel()
		back_to_menu_requested.emit()
	)
	# 名称输入：回车提交
	%NameEdit.text_submitted.connect(func(_s): _on_submit())
	# 移动端软键盘：获焦时显式唤起，失焦时隐藏
	%NameEdit.focus_entered.connect(func():
		DisplayServer.virtual_keyboard_show(%NameEdit.text)
	)
	%NameEdit.focus_exited.connect(func():
		DisplayServer.virtual_keyboard_hide()
	)


func show_defeat(time: float, kills: int, level: int) -> void:
	_result_is_win = false
	_result_data = {"time": time, "kills": kills, "level": level}
	_last_rank = -1
	var score := Leaderboard.compute_score(time, kills, level, false, Difficulty.current_preset)
	_last_score = score
	_setup_result(false, time, kills, level, score)
	_show()


func show_victory(time: float, kills: int, level: int) -> void:
	_result_is_win = true
	_result_data = {"time": time, "kills": kills, "level": level}
	_last_rank = -1
	var score := Leaderboard.compute_score(time, kills, level, true, Difficulty.current_preset)
	_last_score = score
	_setup_result(true, time, kills, level, score)
	_show()


func _setup_result(win: bool, time: float, kills: int, level: int, score: int) -> void:
	# 切到结算视图
	%ResultView.visible = true
	%LeaderboardView.visible = false
	# 标题
	if win:
		%TitleLabel.text = "胜利！"
		%TitleLabel.add_theme_color_override("font_color", Color("ffe34a"))
		%SubtitleLabel.text = "深渊领主已陨落"
	else:
		%TitleLabel.text = "你倒下了"
		%TitleLabel.add_theme_color_override("font_color", Color("ff6a6a"))
		%SubtitleLabel.text = "黑暗吞噬了你"
	# 统计
	var m := int(time) / 60
	var s := int(time) % 60
	%StatsLabel.text = "存活  %02d:%02d      击杀  %d      等级  %d      难度  %s" % [m, s, kills, level, Difficulty.preset_name()]
	%ScoreLabel.text = "得分  %d" % score
	# 重置输入
	%NameEdit.text = ""
	%SubmitButton.disabled = false
	%SubmitHint.text = "输入你的名字，提交到排行榜"
	# 让输入框获得焦点，玩家可直接打字
	%NameEdit.call_deferred("grab_focus")


func _on_submit() -> void:
	if %LeaderboardView.visible:
		return
	var name_str: String = %NameEdit.text.strip_edges()
	_last_rank = Leaderboard.submit(
		name_str, _last_score, Difficulty.current_preset,
		_result_data.get("time", 0.0), _result_data.get("kills", 0),
		_result_data.get("level", 1), _result_is_win
	)
	# 切到排行榜视图
	%ResultView.visible = false
	%LeaderboardView.visible = true
	%Leaderboard.hide_native_buttons()   # GameOver 自己提供底部按钮
	%Leaderboard.refresh(_last_rank)


func _show() -> void:
	visible = true


func hide_panel() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	# 屏蔽游戏内的快捷键（如 R 重启），防止穿透
	if visible and event.is_action("restart"):
		# 结算面板下不响应重启，由按钮处理
		pass
