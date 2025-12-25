extends Control
## Title Screen - Splash screen with tap to continue
## Fades in, shows logo, pulses "TAP TO START"

@onready var tap_prompt: Label = $TapPrompt
@onready var blink_timer: Timer = $BlinkTimer
@onready var fade_rect: ColorRect = $FadeRect

var can_proceed: bool = false
var prompt_visible: bool = true


func _ready() -> void:
	# Start with black screen, fade in
	fade_rect.color.a = 1.0
	can_proceed = false

	# Connect blink timer for tap prompt
	blink_timer.timeout.connect(_on_blink)

	# Fade in sequence
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 1.5)
	tween.tween_callback(_enable_input)


func _enable_input() -> void:
	can_proceed = true


func _on_blink() -> void:
	prompt_visible = not prompt_visible
	if tap_prompt:
		tap_prompt.modulate.a = 1.0 if prompt_visible else 0.3


func _input(event: InputEvent) -> void:
	if not can_proceed:
		return

	# Any touch or click proceeds
	if event is InputEventScreenTouch and event.pressed:
		_go_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_menu()
	elif event is InputEventKey and event.pressed:
		_go_to_menu()


func _go_to_menu() -> void:
	if not can_proceed:
		return

	can_proceed = false

	# Fade out then change scene
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(_load_menu)


func _load_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
