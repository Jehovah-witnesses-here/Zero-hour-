extends Control
## Touch Controls - Virtual Joystick and Action Buttons for Mobile
## Handles all touch input for player movement

signal movement_changed(direction: Vector2)
signal run_toggled(is_running: bool)
signal action_pressed(action_name: String)

# Joystick settings
@export var joystick_radius: float = 90.0
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
var reload_button: Button = null


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
	joystick_base.position = Vector2(130, -140)
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_base)

	# Joystick knob
	joystick_knob = _create_circle_control(joystick_radius * 0.5, joystick_knob_color)
	joystick_knob.position = joystick_base.position
	joystick_knob.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_knob)

	# FIRE button — bottom-right, most reachable
	action_button = Button.new()
	action_button.text = "FIRE"
	action_button.custom_minimum_size = Vector2(110, 80)
	action_button.position = Vector2(-130, -100)
	action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.pressed.connect(_on_action_pressed)
	add_child(action_button)

	# JUMP button — above FIRE
	jump_button = Button.new()
	jump_button.text = "JUMP"
	jump_button.custom_minimum_size = Vector2(110, 80)
	jump_button.position = Vector2(-130, -200)
	jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_button.pressed.connect(_on_jump_pressed)
	add_child(jump_button)

	# RUN button — second column, lower
	run_button = Button.new()
	run_button.text = "RUN"
	run_button.custom_minimum_size = Vector2(110, 80)
	run_button.position = Vector2(-260, -100)
	run_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	run_button.toggle_mode = true
	run_button.toggled.connect(_on_run_toggled)
	add_child(run_button)

	# RELOAD button — second column, upper
	reload_button = Button.new()
	reload_button.text = "RELOAD"
	reload_button.custom_minimum_size = Vector2(110, 80)
	reload_button.position = Vector2(-260, -200)
	reload_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	reload_button.pressed.connect(_on_reload_pressed)
	add_child(reload_button)

	# Crosshair — dot + four lines
	var ch_root = Control.new()
	ch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ch_root)

	var ch = ColorRect.new()
	ch.color = Color(1, 1, 1, 0.85)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.set_anchors_preset(Control.PRESET_CENTER)

	# Center dot
	var dot = ColorRect.new()
	dot.color = Color(1, 1, 1, 0.9)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch_root.add_child(dot)

	# Top line
	var top = ColorRect.new(); top.color = Color(1,1,1,0.8); top.size = Vector2(2, 10)
	top.set_anchors_preset(Control.PRESET_CENTER); top.position = Vector2(-1, -22)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_root.add_child(top)
	# Bottom line
	var bot = ColorRect.new(); bot.color = Color(1,1,1,0.8); bot.size = Vector2(2, 10)
	bot.set_anchors_preset(Control.PRESET_CENTER); bot.position = Vector2(-1, 12)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_root.add_child(bot)
	# Left line
	var lft = ColorRect.new(); lft.color = Color(1,1,1,0.8); lft.size = Vector2(10, 2)
	lft.set_anchors_preset(Control.PRESET_CENTER); lft.position = Vector2(-22, -1)
	lft.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_root.add_child(lft)
	# Right line
	var rgt = ColorRect.new(); rgt.color = Color(1,1,1,0.8); rgt.size = Vector2(10, 2)
	rgt.set_anchors_preset(Control.PRESET_CENTER); rgt.position = Vector2(12, -1)
	rgt.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_root.add_child(rgt)
	# Outer ring
	var ring_panel = Panel.new()
	ring_panel.custom_minimum_size = Vector2(44, 44)
	ring_panel.size = Vector2(44, 44)
	ring_panel.set_anchors_preset(Control.PRESET_CENTER)
	ring_panel.position = Vector2(-22, -22)
	ring_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style = StyleBoxFlat.new()
	ring_style.bg_color = Color.TRANSPARENT
	ring_style.border_color = Color(1, 1, 1, 0.3)
	ring_style.border_width_top = 1; ring_style.border_width_bottom = 1
	ring_style.border_width_left = 1; ring_style.border_width_right = 1
	ring_style.corner_radius_top_left = 22; ring_style.corner_radius_top_right = 22
	ring_style.corner_radius_bottom_left = 22; ring_style.corner_radius_bottom_right = 22
	ring_panel.add_theme_stylebox_override("panel", ring_style)
	ch_root.add_child(ring_panel)


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
	if player and player.has_method("_shoot"):
		player._shoot()
	action_pressed.emit("interact")


func _on_reload_pressed() -> void:
	if player and player.has_method("_start_reload"):
		player._start_reload()


func set_visible_controls(show: bool) -> void:
	joystick_base.visible = show
	joystick_knob.visible = show
	run_button.visible = show
	jump_button.visible = show
	action_button.visible = show
	if reload_button:
		reload_button.visible = show


func get_movement() -> Vector2:
	return joystick_output
