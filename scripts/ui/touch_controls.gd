extends Control
## Touch Controls - Virtual Joystick and Action Buttons for Mobile
## Handles all touch input for player movement

signal movement_changed(direction: Vector2)
signal run_toggled(is_running: bool)
signal action_pressed(action_name: String)

# Joystick settings
@export var joystick_radius: float = 80.0
@export var joystick_deadzone: float = 0.15
@export var joystick_color: Color = Color(1, 1, 1, 0.25)
@export var joystick_knob_color: Color = Color(1, 1, 1, 0.55)

# Joystick state
var joystick_touch_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_current: Vector2 = Vector2.ZERO
var joystick_output: Vector2 = Vector2.ZERO

# Run button state
var is_running: bool = false

# Player reference
var player: CharacterBody3D = null

# UI elements
var joystick_base: Control = null
var joystick_knob: Control = null
var run_button: Button = null
var action_button: Button = null
var jump_button: Button = null


func _ready() -> void:
	_create_ui_elements()

	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/Main/Player")


func _create_ui_elements() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Joystick base (bottom-left)
	joystick_base = _create_circle_control(joystick_radius, joystick_color)
	joystick_base.position = Vector2(150, -150)
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_base)

	# Joystick knob
	joystick_knob = _create_circle_control(joystick_radius * 0.5, joystick_knob_color)
	joystick_knob.position = joystick_base.position
	joystick_knob.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_knob)

	# Run button (bottom-right)
	run_button = Button.new()
	run_button.text = "RUN"
	run_button.custom_minimum_size = Vector2(100, 60)
	run_button.position = Vector2(-120, -230)
	run_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	run_button.toggle_mode = true
	run_button.toggled.connect(_on_run_toggled)
	add_child(run_button)

	# Jump button (bottom-right, left of run)
	jump_button = Button.new()
	jump_button.text = "JUMP"
	jump_button.custom_minimum_size = Vector2(100, 60)
	jump_button.position = Vector2(-240, -230)
	jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_button.pressed.connect(_on_jump_pressed)
	add_child(jump_button)

	# Action button (bottom-right, lower)
	action_button = Button.new()
	action_button.text = "ACTION"
	action_button.custom_minimum_size = Vector2(100, 60)
	action_button.position = Vector2(-120, -150)
	action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.pressed.connect(_on_action_pressed)
	add_child(action_button)

	# Crosshair (center of screen)
	var crosshair = Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.modulate = Color(1, 1, 1, 0.75)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)


func _create_circle_control(radius: float, color: Color) -> Control:
	var circle = Control.new()
	circle.custom_minimum_size = Vector2(radius * 2, radius * 2)
	circle.size = Vector2(radius * 2, radius * 2)
	circle.pivot_offset = Vector2(radius, radius)

	var panel = Panel.new()
	panel.size = Vector2(radius * 2, radius * 2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = color
	var r = int(radius)
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r
	panel.add_theme_stylebox_override("panel", style)

	circle.add_child(panel)
	return circle


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var screen_half = get_viewport().get_visible_rect().size.x * 0.5

		if event.position.x < screen_half:
			if event.pressed and joystick_touch_index == -1:
				_start_joystick(event.index, event.position)
			elif not event.pressed and event.index == joystick_touch_index:
				_end_joystick()

	if event is InputEventScreenDrag:
		if event.index == joystick_touch_index:
			_update_joystick(event.position)


func _start_joystick(index: int, position: Vector2) -> void:
	joystick_touch_index = index
	joystick_center = position
	joystick_base.global_position = position - Vector2(joystick_radius, joystick_radius)
	joystick_knob.global_position = position - Vector2(joystick_radius * 0.5, joystick_radius * 0.5)


func _update_joystick(position: Vector2) -> void:
	var delta = position - joystick_center
	var distance = delta.length()

	if distance > joystick_radius:
		delta = delta.normalized() * joystick_radius
		distance = joystick_radius

	var knob_pos = joystick_center + delta - Vector2(joystick_radius * 0.5, joystick_radius * 0.5)
	joystick_knob.global_position = knob_pos

	var normalized_distance = distance / joystick_radius
	if normalized_distance < joystick_deadzone:
		joystick_output = Vector2.ZERO
	else:
		var remapped = (normalized_distance - joystick_deadzone) / (1.0 - joystick_deadzone)
		joystick_output = delta.normalized() * remapped

	_update_player_movement()
	movement_changed.emit(joystick_output)


func _end_joystick() -> void:
	joystick_touch_index = -1
	joystick_output = Vector2.ZERO
	joystick_knob.global_position = joystick_base.global_position + Vector2(joystick_radius * 0.5, joystick_radius * 0.5)
	_update_player_movement()
	movement_changed.emit(Vector2.ZERO)


func _update_player_movement() -> void:
	if player and player.has_method("set_touch_movement"):
		# joystick up = negative screen Y delta = negative output Y = forward — pass directly
		player.set_touch_movement(joystick_output)


func _on_run_toggled(pressed: bool) -> void:
	is_running = pressed
	run_button.text = "WALK" if pressed else "RUN"
	if player and player.has_method("set_running"):
		player.set_running(pressed)
	run_toggled.emit(pressed)


func _on_jump_pressed() -> void:
	if player and player.has_method("do_jump"):
		player.do_jump()


func _on_action_pressed() -> void:
	action_pressed.emit("interact")


func set_visible_controls(show: bool) -> void:
	joystick_base.visible = show
	joystick_knob.visible = show
	run_button.visible = show
	jump_button.visible = show
	action_button.visible = show


func get_movement() -> Vector2:
	return joystick_output
