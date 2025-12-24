extends Control
## Touch Controls - Virtual Joystick and Action Buttons for Mobile
## Handles all touch input for player movement

signal movement_changed(direction: Vector2)
signal run_toggled(is_running: bool)
signal action_pressed(action_name: String)

# Joystick settings
@export var joystick_radius: float = 80.0
@export var joystick_deadzone: float = 0.15
@export var joystick_color: Color = Color(1, 1, 1, 0.3)
@export var joystick_knob_color: Color = Color(1, 1, 1, 0.6)

# Joystick state
var joystick_touch_index: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_current: Vector2 = Vector2.ZERO
var joystick_output: Vector2 = Vector2.ZERO

# Run button state
var is_running: bool = false

# Player reference
var player: CharacterBody3D = null

# UI elements (created dynamically)
var joystick_base: Control = null
var joystick_knob: Control = null
var run_button: Button = null
var action_button: Button = null


func _ready() -> void:
	_create_ui_elements()

	# Find player in scene
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/Main/Player")


func _create_ui_elements() -> void:
	# Set this control to fill screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create joystick base (left side of screen)
	joystick_base = _create_circle_control(joystick_radius, joystick_color)
	joystick_base.position = Vector2(150, -150)  # Bottom-left
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_base)

	# Create joystick knob
	joystick_knob = _create_circle_control(joystick_radius * 0.5, joystick_knob_color)
	joystick_knob.position = joystick_base.position
	joystick_knob.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_knob)

	# Create run button (bottom-right, above action)
	run_button = Button.new()
	run_button.text = "RUN"
	run_button.custom_minimum_size = Vector2(100, 60)
	run_button.position = Vector2(-120, -230)
	run_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	run_button.toggle_mode = true
	run_button.toggled.connect(_on_run_toggled)
	add_child(run_button)

	# Create action button (bottom-right)
	action_button = Button.new()
	action_button.text = "ACTION"
	action_button.custom_minimum_size = Vector2(100, 60)
	action_button.position = Vector2(-120, -150)
	action_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.pressed.connect(_on_action_pressed)
	add_child(action_button)


func _create_circle_control(radius: float, color: Color) -> Control:
	var circle = Control.new()
	circle.custom_minimum_size = Vector2(radius * 2, radius * 2)
	circle.size = Vector2(radius * 2, radius * 2)
	circle.pivot_offset = Vector2(radius, radius)

	# Draw circle using _draw override
	var circle_drawer = ColorRect.new()
	circle_drawer.color = color
	circle_drawer.size = Vector2(radius * 2, radius * 2)
	circle_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(circle_drawer)

	return circle


func _input(event: InputEvent) -> void:
	# Handle joystick touch (left half of screen)
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

	# Move joystick base to touch position
	joystick_base.global_position = position - Vector2(joystick_radius, joystick_radius)
	joystick_knob.global_position = position - Vector2(joystick_radius * 0.5, joystick_radius * 0.5)


func _update_joystick(position: Vector2) -> void:
	var delta = position - joystick_center
	var distance = delta.length()

	# Clamp to joystick radius
	if distance > joystick_radius:
		delta = delta.normalized() * joystick_radius
		distance = joystick_radius

	# Update knob position
	var knob_pos = joystick_center + delta - Vector2(joystick_radius * 0.5, joystick_radius * 0.5)
	joystick_knob.global_position = knob_pos

	# Calculate output (normalized, with deadzone)
	var normalized_distance = distance / joystick_radius
	if normalized_distance < joystick_deadzone:
		joystick_output = Vector2.ZERO
	else:
		# Remap from deadzone to full range
		var remapped = (normalized_distance - joystick_deadzone) / (1.0 - joystick_deadzone)
		joystick_output = delta.normalized() * remapped

	# Send to player
	_update_player_movement()
	movement_changed.emit(joystick_output)


func _end_joystick() -> void:
	joystick_touch_index = -1
	joystick_output = Vector2.ZERO

	# Reset knob position
	joystick_knob.global_position = joystick_base.global_position + Vector2(joystick_radius * 0.5, joystick_radius * 0.5)

	_update_player_movement()
	movement_changed.emit(Vector2.ZERO)


func _update_player_movement() -> void:
	if player and player.has_method("set_touch_movement"):
		# Convert joystick to movement (forward is -Y in joystick, -Z in 3D)
		var movement = Vector2(joystick_output.x, -joystick_output.y)
		player.set_touch_movement(movement)


func _on_run_toggled(pressed: bool) -> void:
	is_running = pressed
	run_button.text = "WALK" if pressed else "RUN"

	if player and player.has_method("set_running"):
		player.set_running(pressed)

	run_toggled.emit(pressed)


func _on_action_pressed() -> void:
	action_pressed.emit("interact")


## Show/hide controls
func set_visible_controls(visible: bool) -> void:
	joystick_base.visible = visible
	joystick_knob.visible = visible
	run_button.visible = visible
	action_button.visible = visible


## Get current joystick output
func get_movement() -> Vector2:
	return joystick_output
