extends Control
## Main Menu - Game mode selection and updates

signal play_pressed
signal update_pressed
signal quit_pressed

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var version_label: Label = $VBoxContainer/VersionLabel
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var update_button: Button = $VBoxContainer/UpdateButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Update system
var updater: Node = null
var current_version: String = "0.1.0"


func _ready() -> void:
	# Connect buttons
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if update_button:
		update_button.pressed.connect(_on_update_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	# Set version
	if version_label:
		version_label.text = "Version " + current_version

	# Get updater
	updater = get_node_or_null("/root/AppUpdater")
	if not updater:
		updater = get_node_or_null("../AppUpdater")

	_set_status("Ready to play")


func _on_play_pressed() -> void:
	_set_status("Loading demo map...")
	play_pressed.emit()

	# Change to main game scene
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_update_pressed() -> void:
	_set_status("Checking for updates...")

	if updater and updater.has_method("check_for_update"):
		updater.check_for_update()
	else:
		# Create updater if not exists
		_check_update_manually()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _set_status(message: String) -> void:
	if status_label:
		status_label.text = message


func _check_update_manually() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_update_check_complete)

	# Check GitHub releases
	var url = "https://api.github.com/repos/Jehovah-witnesses-here/Zero-hour-/releases/latest"
	var error = http.request(url)

	if error != OK:
		_set_status("Failed to check for updates")


func _on_update_check_complete(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_status("No updates found (or no releases yet)")
		return

	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		_set_status("Failed to parse update info")
		return

	var data = json.get_data()
	var latest_version = data.get("tag_name", "v0.0.0").replace("v", "")

	if _is_newer_version(latest_version, current_version):
		_set_status("Update available: v" + latest_version)

		# Find APK asset
		var assets = data.get("assets", [])
		for asset in assets:
			if asset.get("name", "").ends_with(".apk"):
				var download_url = asset.get("browser_download_url", "")
				if download_url:
					_download_update(download_url, latest_version)
					return

		_set_status("Update found but no APK available")
	else:
		_set_status("You have the latest version!")


func _is_newer_version(latest: String, current: String) -> bool:
	var latest_parts = latest.split(".")
	var current_parts = current.split(".")

	for i in range(min(latest_parts.size(), current_parts.size())):
		var l = int(latest_parts[i]) if i < latest_parts.size() else 0
		var c = int(current_parts[i]) if i < current_parts.size() else 0
		if l > c:
			return true
		elif l < c:
			return false

	return false


func _download_update(url: String, version: String) -> void:
	_set_status("Downloading update...")

	var http = HTTPRequest.new()
	http.download_file = "user://zero-hour-update.apk"
	add_child(http)
	http.request_completed.connect(_on_download_complete)

	var error = http.request(url)
	if error != OK:
		_set_status("Download failed to start")


func _on_download_complete(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_status("Download failed")
		return

	_set_status("Download complete! Installing...")

	# Get the actual file path
	var apk_path = OS.get_user_data_dir() + "/zero-hour-update.apk"

	# On Android, open the APK with the package installer
	if OS.get_name() == "Android":
		# Use Android intent to install
		OS.shell_open(apk_path)
		_set_status("Please tap Install when prompted")
	else:
		_set_status("Update downloaded to: " + apk_path)
