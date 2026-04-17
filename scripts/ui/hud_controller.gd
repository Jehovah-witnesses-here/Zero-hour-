extends CanvasLayer
## HUD Controller - Shows game status, position, and controls
## Updated to show DEMO MODE properly

@onready var gps_label: Label = $TopBar/GPSLabel
@onready var fps_label: Label = $TopBar/FPSLabel
@onready var loading_panel: Panel = $LoadingPanel
@onready var loading_label: Label = $LoadingPanel/LoadingLabel
@onready var building_count_label: Label = $DebugPanel/BuildingCountLabel
@onready var position_label: Label = $DebugPanel/PositionLabel

var game_manager: Node = null
var player: CharacterBody3D = null
var building_generator: Node3D = null

var fps_timer: float = 0.0
var health_label: Label = null
var wave_label: Label = null


func _ready() -> void:
	game_manager = get_node_or_null("/root/GameManager")

	await get_tree().create_timer(0.5).timeout
	_find_references()
	_connect_signals()

	# Show demo mode immediately
	if gps_label:
		gps_label.text = "DEMO MODE"


func _find_references() -> void:
	player = get_tree().get_first_node_in_group("player")
	building_generator = get_tree().get_first_node_in_group("building_generator")

	if has_node("DebugPanel"):
		$DebugPanel.visible = true

	_create_health_ui()
	_connect_gameplay_signals()


func _create_health_ui() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_top = 4.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 4.0

	health_label = Label.new()
	health_label.text = "HP: 100"
	health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_label.position = Vector2(20, -70)
	health_label.add_theme_font_size_override("font_size", 22)
	health_label.add_theme_stylebox_override("normal", style)
	add_child(health_label)

	wave_label = Label.new()
	wave_label.text = ""
	wave_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wave_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	wave_label.position = Vector2(-160, 60)
	wave_label.add_theme_font_size_override("font_size", 18)
	wave_label.add_theme_stylebox_override("normal", style)
	add_child(wave_label)


func _connect_gameplay_signals() -> void:
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	if game_manager:
		if game_manager.has_signal("wave_started"):
			game_manager.wave_started.connect(_on_wave_started)
		if game_manager.has_signal("wave_complete"):
			game_manager.wave_complete.connect(_on_wave_complete)


func _connect_signals() -> void:
	if game_manager:
		if game_manager.has_signal("loading_started"):
			game_manager.loading_started.connect(_on_loading)
		if game_manager.has_signal("loading_complete"):
			game_manager.loading_complete.connect(_on_loaded)
		if game_manager.has_signal("buildings_ready"):
			game_manager.buildings_ready.connect(_on_buildings_ready)


func _process(delta: float) -> void:
	# Update FPS every 0.25 seconds
	fps_timer += delta
	if fps_timer >= 0.25:
		fps_timer = 0.0
		if fps_label:
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Update position
	if player and position_label:
		var pos = player.global_position
		position_label.text = "Pos: %.1f, %.1f" % [pos.x, pos.z]


func _on_loading(message: String) -> void:
	if loading_panel:
		loading_panel.visible = true
	if loading_label:
		loading_label.text = message


func _on_loaded() -> void:
	if loading_panel:
		loading_panel.visible = false
	if gps_label:
		gps_label.text = "DEMO MODE"


func _on_health_changed(current: float, maximum: float) -> void:
	if health_label:
		health_label.text = "HP: %d" % int(current)
		if current < maximum * 0.3:
			health_label.modulate = Color(1, 0.3, 0.3)
		elif current < maximum * 0.6:
			health_label.modulate = Color(1, 0.8, 0.2)
		else:
			health_label.modulate = Color(1, 1, 1)


func _on_player_died() -> void:
	if health_label:
		health_label.text = "YOU DIED"
		health_label.modulate = Color(1, 0.1, 0.1)


func _on_wave_started(wave_number: int, zombie_count: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d  [%d zombies]" % [wave_number, zombie_count]


func _on_wave_complete(wave_number: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d CLEAR!" % wave_number


func _on_buildings_ready() -> void:
	if loading_panel:
		loading_panel.visible = false

	# Update building count
	if building_count_label and building_generator:
		if building_generator.has_method("get_building_count"):
			building_count_label.text = "Buildings: %d" % building_generator.get_building_count()

	# Show demo mode
	if gps_label:
		gps_label.text = "DEMO MODE"
