class_name PauseMenu
extends Control
## 暂停菜单。ESC 打开。
## 选项：继续 / 重打本关 / 重新开始游戏 / 查看图鉴 / 返回主菜单。

signal resume_requested()
signal retry_stage_requested()
signal restart_game_requested()
signal bestiary_requested()
signal back_to_menu_requested()


func _ready() -> void:
	# 暂停时本菜单仍要响应
	process_mode = Node.PROCESS_MODE_ALWAYS
	%ResumeButton.pressed.connect(func(): resume_requested.emit())
	%RetryStageButton.pressed.connect(func(): retry_stage_requested.emit())
	%RestartButton.pressed.connect(func(): restart_game_requested.emit())
	%BestiaryButton.pressed.connect(func(): bestiary_requested.emit())
	%BackMenuButton.pressed.connect(func(): back_to_menu_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	# 仅在暂停菜单可见时处理 ESC（恢复），否则不拦截，让 Main 处理暂停
	if visible and event.is_action_pressed("pause"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true


func close() -> void:
	visible = false
