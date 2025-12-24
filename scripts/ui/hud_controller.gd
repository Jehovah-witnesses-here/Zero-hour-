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
