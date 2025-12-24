extends Control
## Pause Menu - In-game menu with resume and back to main menu

var is_paused: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # Work even when paused


func _input(event: InputEvent) -> void:
	# Android back button or Escape key
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause() -> void:
	is_paused = !is_paused
	visible = is_paused
	get_tree().paused = is_paused


func show_pause() -> void:
	is_paused = true
	visible = true
	get_tree().paused = true


func hide_pause() -> void:
	is_paused = false
	visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	hide_pause()


func _on_menu_pressed() -> void:
	hide_pause()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
