extends Control
## Pre-Game Lobby - Mode selection, map selection, party management
## Handles game setup before launching into gameplay

# Node references
@onready var back_btn: Button = $HeaderBar/BackButton
@onready var survival_btn: Button = $MainContainer/ScrollContainer/VBoxContainer/ModeSection/ModeVBox/ModeButtons/HBoxContainer/SurvivalBtn
@onready var exclusion_btn: Button = $MainContainer/ScrollContainer/VBoxContainer/ModeSection/ModeVBox/ModeButtons/HBoxContainer/ExclusionBtn
@onready var rust_btn: Button = $MainContainer/ScrollContainer/VBoxContainer/MapSection/MapVBox/MapButtons/VBoxContainer/RustBtn
@onready var hometown_btn: Button = $MainContainer/ScrollContainer/VBoxContainer/MapSection/MapVBox/MapButtons/VBoxContainer/HometownBtn
@onready var invite_btn: Button = $MainContainer/ScrollContainer/VBoxContainer/FriendsSection/FriendsVBox/FriendsHeader/HBoxContainer/InviteBtn
@onready var start_btn: Button = $BottomBar/MarginContainer/StartButton
@onready var status_label: Label = $StatusLabel

# Style resources for selected/unselected buttons
var style_selected: StyleBoxFlat
var style_unselected: StyleBoxFlat

# Selected options
enum GameMode { SURVIVAL, EXCLUSION_ZONE }
enum MapType { RUST, HOMETOWN }

var selected_mode: GameMode = GameMode.SURVIVAL
var selected_map: MapType = MapType.RUST

# Reference to GameManager autoload
@onready var game_manager = get_node_or_null("/root/GameManager")


var place_edit: LineEdit = null  # postcode/address box, shown under the Hometown button


func _ready() -> void:
	_add_place_edit()
	_create_styles()
	_connect_buttons()
	_update_selection_visuals()
	_update_status()


func _add_place_edit() -> void:
	if not hometown_btn:
		return
	place_edit = LineEdit.new()
	place_edit.placeholder_text = "Postcode or address (blank = near you)"
	place_edit.custom_minimum_size = Vector2(0, 70)
	place_edit.add_theme_font_size_override("font_size", 28)
	place_edit.visible = false
	hometown_btn.add_sibling(place_edit)
	if game_manager:
		place_edit.text = game_manager.hometown_query


func _create_styles() -> void:
	# Selected style (red)
	style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(0.6, 0.15, 0.15, 1)
	style_selected.border_color = Color(0.9, 0.3, 0.3, 1)
	style_selected.set_border_width_all(3)
	style_selected.set_corner_radius_all(8)

	# Unselected style (gray)
	style_unselected = StyleBoxFlat.new()
	style_unselected.bg_color = Color(0.2, 0.2, 0.25, 1)
	style_unselected.border_color = Color(0.5, 0.5, 0.55, 1)
	style_unselected.set_border_width_all(2)
	style_unselected.set_corner_radius_all(8)


func _connect_buttons() -> void:
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)

	if survival_btn:
		survival_btn.pressed.connect(_on_survival_pressed)
	if exclusion_btn:
		exclusion_btn.pressed.connect(_on_exclusion_pressed)

	if rust_btn:
		rust_btn.pressed.connect(_on_rust_pressed)
	if hometown_btn:
		hometown_btn.pressed.connect(_on_hometown_pressed)

	if invite_btn:
		invite_btn.pressed.connect(_on_invite_pressed)

	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_survival_pressed() -> void:
	selected_mode = GameMode.SURVIVAL
	_update_selection_visuals()
	_update_status()


func _on_exclusion_pressed() -> void:
	selected_mode = GameMode.EXCLUSION_ZONE
	_update_selection_visuals()
	_update_status()


func _on_rust_pressed() -> void:
	selected_map = MapType.RUST
	_update_selection_visuals()
	_update_status()


func _on_hometown_pressed() -> void:
	selected_map = MapType.HOMETOWN
	_update_selection_visuals()
	_update_status()


func _on_invite_pressed() -> void:
	# TODO: Implement friend invite system
	# For now, show a placeholder message
	_show_coming_soon("Friend invites coming in a future update!")


func _on_start_pressed() -> void:
	start_btn.disabled = true
	_set_status("Loading...")

	# Configure game manager with selections
	if game_manager:
		match selected_mode:
			GameMode.SURVIVAL:
				game_manager.current_mode = game_manager.GameMode.SURVIVAL
			GameMode.EXCLUSION_ZONE:
				game_manager.current_mode = game_manager.GameMode.EXCLUSION_ZONE

		match selected_map:
			MapType.RUST:
				game_manager.current_map_type = game_manager.MapType.DEMO
			MapType.HOMETOWN:
				game_manager.current_map_type = game_manager.MapType.REAL_WORLD
				game_manager.hometown_query = place_edit.text if place_edit else ""

	# Small delay for feedback
	await get_tree().create_timer(0.3).timeout

	# Load the game; GameManager picks Rust or GPS mode from current_map_type
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_selection_visuals() -> void:
	# Update mode buttons
	if survival_btn:
		survival_btn.add_theme_stylebox_override("normal",
			style_selected if selected_mode == GameMode.SURVIVAL else style_unselected)
	if exclusion_btn:
		exclusion_btn.add_theme_stylebox_override("normal",
			style_selected if selected_mode == GameMode.EXCLUSION_ZONE else style_unselected)

	# Update map buttons
	if rust_btn:
		rust_btn.add_theme_stylebox_override("normal",
			style_selected if selected_map == MapType.RUST else style_unselected)
	if hometown_btn:
		hometown_btn.add_theme_stylebox_override("normal",
			style_selected if selected_map == MapType.HOMETOWN else style_unselected)
	if place_edit:
		place_edit.visible = selected_map == MapType.HOMETOWN


func _update_status() -> void:
	var mode_name = "Survival" if selected_mode == GameMode.SURVIVAL else "Exclusion Zone"
	var map_name = "Rust" if selected_map == MapType.RUST else "Your Hometown"
	_set_status(mode_name + " on " + map_name)


func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg


func _show_coming_soon(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Coming Soon"
	dialog.dialog_text = msg
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()
