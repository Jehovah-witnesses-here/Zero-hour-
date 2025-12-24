extends CanvasLayer
## HUD Controller - Updates all HUD elements
## Shows GPS, FPS, loading state, and debug info

# UI element references
@onready var gps_label: Label = $TopBar/GPSLabel
@onready var fps_label: Label = $TopBar/FPSLabel
@onready var loading_panel: Panel = $LoadingPanel
@onready var loading_label: Label = $LoadingPanel/LoadingLabel
@onready var building_count_label: Label = $DebugPanel/BuildingCountLabel
@onready var position_label: Label = $DebugPanel/PositionLabel

# References
var gps_manager: Node = null
var game_manager: Node = null
var player: CharacterBody3D = null
var building_generator: Node3D = null

# Update intervals
var gps_update_timer: float = 0.0
var fps_update_timer: float = 0.0

# Settings
@export var show_debug: bool = true
@export var gps_update_interval: float = 0.5
@export var fps_update_interval: float = 0.25


func _ready() -> void:
	# Get autoload singletons
	gps_manager = get_node_or_null("/root/GPSManager")
	game_manager = get_node_or_null("/root/GameManager")

	# Wait for scene to load then find references
	await get_tree().process_frame
	_find_references()
	_connect_signals()

	# Show loading initially
	_show_loading("Initializing...")


func _find_references() -> void:
	player = get_tree().get_first_node_in_group("player")
	building_generator = get_tree().get_first_node_in_group("building_generator")

	# Toggle debug panel
	if has_node("DebugPanel"):
		$DebugPanel.visible = show_debug


func _connect_signals() -> void:
	if game_manager:
		game_manager.loading_started.connect(_show_loading)
		game_manager.loading_complete.connect(_hide_loading)
		game_manager.buildings_ready.connect(_on_buildings_ready)

	if gps_manager:
		gps_manager.location_updated.connect(_on_gps_updated)
		gps_manager.location_error.connect(_on_gps_error)


func _process(delta: float) -> void:
	# Update FPS display
	fps_update_timer += delta
	if fps_update_timer >= fps_update_interval:
		fps_update_timer = 0.0
		_update_fps()

	# Update position display
	if show_debug and player:
		var pos = player.global_position
		if position_label:
			position_label.text = "Pos: %.1f, %.1f, %.1f" % [pos.x, pos.y, pos.z]


func _update_fps() -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_gps_updated(latitude: float, longitude: float) -> void:
	if gps_label:
		gps_label.text = "GPS: %.5f, %.5f" % [latitude, longitude]


func _on_gps_error(message: String) -> void:
	if gps_label:
		gps_label.text = "GPS: " + message


func _show_loading(message: String) -> void:
	if loading_panel:
		loading_panel.visible = true
	if loading_label:
		loading_label.text = message


func _hide_loading() -> void:
	if loading_panel:
		loading_panel.visible = false


func _on_buildings_ready() -> void:
	_hide_loading()
	_update_building_count()


func _update_building_count() -> void:
	if building_count_label and building_generator:
		var count = building_generator.get_building_count() if building_generator.has_method("get_building_count") else 0
		building_count_label.text = "Buildings: %d" % count


## Toggle debug panel visibility
func toggle_debug() -> void:
	show_debug = !show_debug
	if has_node("DebugPanel"):
		$DebugPanel.visible = show_debug


## Update GPS label with custom message
func set_gps_status(message: String) -> void:
	if gps_label:
		gps_label.text = message
