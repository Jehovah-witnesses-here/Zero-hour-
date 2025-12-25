extends Control
## Main Menu - Game mode selection and updates
## Privacy: Only checks public GitHub API, no personal data sent

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var version_label: Label = $VBoxContainer/VersionLabel
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var update_button: Button = $VBoxContainer/UpdateButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Current version - update this with each release
const CURRENT_VERSION: String = "0.4.0"

# GitHub repo info (public, no auth needed)
const GITHUB_REPO: String = "Jehovah-witnesses-here/Zero-hour-"
const RELEASES_URL: String = "https://github.com/Jehovah-witnesses-here/Zero-hour-/releases"


func _ready() -> void:
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if update_button:
		update_button.pressed.connect(_on_update_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	if version_label:
		version_label.text = "v" + CURRENT_VERSION

	_set_status("Ready")


func _on_play_pressed() -> void:
	_set_status("Loading...")
	play_button.disabled = true
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_settings_pressed() -> void:
	# TODO: Implement settings screen
	var dialog = AcceptDialog.new()
	dialog.title = "Settings"
	dialog.dialog_text = "Settings coming soon!\n\n• Graphics options\n• Audio controls\n• Control sensitivity\n• Privacy settings"
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_update_pressed() -> void:
	_set_status("Checking for updates...")
	update_button.disabled = true

	# Create HTTP request to check GitHub releases
	# This ONLY sends: GET request to public GitHub API
	# GitHub sees: Your IP address (like visiting any website)
	# NO personal data, device info, or location is sent
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_update_check_done)

	var url = "https://api.github.com/repos/" + GITHUB_REPO + "/releases/latest"
	var error = http.request(url, ["User-Agent: ZERO-HOUR-Game"])

	if error != OK:
		_set_status("Connection failed")
		update_button.disabled = false


func _on_update_check_done(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	update_button.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_set_status("Connection failed")
		return

	if code == 404:
		_set_status("No releases yet")
		return

	if code != 200:
		_set_status("GitHub error: " + str(code))
		return

	# Parse response
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_status("Invalid response")
		return

	var data = json.get_data()
	var latest = str(data.get("tag_name", "v0.0.0")).replace("v", "")

	if _is_newer(latest, CURRENT_VERSION):
		_set_status("Update v" + latest + " available!")
		# Show dialog to open browser
		_show_update_dialog(latest)
	else:
		_set_status("You have the latest version!")


func _is_newer(latest: String, current: String) -> bool:
	var l_parts = latest.split(".")
	var c_parts = current.split(".")

	for i in range(3):
		var l = int(l_parts[i]) if i < l_parts.size() else 0
		var c = int(c_parts[i]) if i < c_parts.size() else 0
		if l > c:
			return true
		if l < c:
			return false
	return false


func _show_update_dialog(version: String) -> void:
	# Create simple confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Update Available"
	dialog.dialog_text = "Version " + version + " is available!\n\nOpen download page?"
	dialog.ok_button_text = "Download"
	dialog.add_cancel_button("Later")

	dialog.confirmed.connect(_open_releases_page)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered()


func _open_releases_page() -> void:
	# Opens GitHub releases in browser - user downloads APK there
	# This is the safest and most reliable method
	OS.shell_open(RELEASES_URL)
	_set_status("Opening browser...")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
