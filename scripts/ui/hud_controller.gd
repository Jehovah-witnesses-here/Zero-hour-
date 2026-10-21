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
var health_bar: ProgressBar = null
var wave_label: Label = null
var score_label: Label = null
var ammo_label: Label = null
var ammo_reserve_label: Label = null
var crosshair_label: Label = null
var kill_feed: Label = null
var kill_feed_lines: Array = ["", "", ""]
var kill_feed_timers: Array = [0.0, 0.0, 0.0]


func _ready() -> void:
	game_manager = get_node_or_null("/root/GameManager")

	# Connect loading signals immediately — GameManager is an autoload
	# so it exists now. Waiting causes loading_complete to fire before
	# we connect, leaving the panel visible and blocking all touch input.
	if loading_panel:
		loading_panel.visible = false
	_connect_signals()

	await get_tree().create_timer(0.5).timeout
	_find_references()

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
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.08, 0.08, 0.75)
	bar_bg.corner_radius_top_left = 5; bar_bg.corner_radius_top_right = 5
	bar_bg.corner_radius_bottom_left = 5; bar_bg.corner_radius_bottom_right = 5

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.15, 0.85, 0.25)
	fill_style.corner_radius_top_left = 4; fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4; fill_style.corner_radius_bottom_right = 4

	# Health bar
	health_bar = ProgressBar.new()
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(220, 22)
	health_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_bar.position = Vector2(20, -54)
	health_bar.add_theme_stylebox_override("fill", fill_style)
	health_bar.add_theme_stylebox_override("background", bar_bg)
	add_child(health_bar)

	health_label = Label.new()
	health_label.text = "HP 100"
	health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_label.position = Vector2(20, -28)
	health_label.add_theme_font_size_override("font_size", 15)
	health_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_label)

	# Ammo — large current / small reserve
	ammo_label = Label.new()
	ammo_label.text = "30"
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_label.position = Vector2(-310, -72)
	ammo_label.add_theme_font_size_override("font_size", 48)
	ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ammo_label)

	ammo_reserve_label = Label.new()
	ammo_reserve_label.text = "/ 90"
	ammo_reserve_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_reserve_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_reserve_label.position = Vector2(-310, -34)
	ammo_reserve_label.add_theme_font_size_override("font_size", 18)
	ammo_reserve_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.9))
	ammo_reserve_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ammo_reserve_label)

	# Score — top-left, yellow
	score_label = Label.new()
	score_label.text = "0"
	score_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	score_label.position = Vector2(20, 56)
	score_label.add_theme_font_size_override("font_size", 30)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_label)

	# Wave banner — centered top
	wave_label = Label.new()
	wave_label.text = ""
	wave_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wave_label.position = Vector2(0, 8)
	wave_label.add_theme_font_size_override("font_size", 22)
	wave_label.add_theme_color_override("font_color", Color(1, 0.8, 0.1))
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wave_label)

	# Hit marker X — invisible normally, flashes on hit
	crosshair_label = Label.new()
	crosshair_label.text = "X"
	crosshair_label.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_label.position = Vector2(-8, -14)
	crosshair_label.add_theme_font_size_override("font_size", 32)
	crosshair_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.0))
	crosshair_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair_label)

	# Kill feed — top-right
	kill_feed = Label.new()
	kill_feed.text = ""
	kill_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kill_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kill_feed.position = Vector2(-260, 56)
	kill_feed.add_theme_font_size_override("font_size", 16)
	kill_feed.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	kill_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(kill_feed)


func _connect_gameplay_signals() -> void:
	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	if player and player.has_signal("shot_hit"):
		player.shot_hit.connect(_on_shot_hit)
	if player and player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_on_ammo_changed)
	if game_manager:
		if game_manager.has_signal("wave_started"):
			game_manager.wave_started.connect(_on_wave_started)
		if game_manager.has_signal("wave_complete"):
			game_manager.wave_complete.connect(_on_wave_complete)
		if game_manager.has_signal("score_changed"):
			game_manager.score_changed.connect(_on_score_changed)


func _connect_signals() -> void:
	if game_manager:
		if game_manager.has_signal("loading_started"):
			game_manager.loading_started.connect(_on_loading)
		if game_manager.has_signal("loading_complete"):
			game_manager.loading_complete.connect(_on_loaded)
		if game_manager.has_signal("buildings_ready"):
			game_manager.buildings_ready.connect(_on_buildings_ready)


func _process(delta: float) -> void:
	fps_timer += delta
	if fps_timer >= 0.25:
		fps_timer = 0.0
		if fps_label:
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if player and position_label:
		var pos = player.global_position
		position_label.text = "Pos: %.1f, %.1f, %.1f" % [pos.x, pos.y, pos.z]

	# Kill feed decay
	var changed := false
	for i in 3:
		if kill_feed_timers[i] > 0.0:
			kill_feed_timers[i] -= delta
			if kill_feed_timers[i] <= 0.0:
				kill_feed_timers[i] = 0.0
				kill_feed_lines[i] = ""
				changed = true
	if changed:
		_update_kill_feed()


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
		health_label.text = "HP %d" % int(current)
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
		var pct = current / maximum
		var fill = StyleBoxFlat.new()
		fill.corner_radius_top_left = 4; fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = 4; fill.corner_radius_bottom_right = 4
		if pct > 0.6:
			fill.bg_color = Color(0.15, 0.85, 0.25)
		elif pct > 0.3:
			fill.bg_color = Color(0.95, 0.75, 0.1)
		else:
			fill.bg_color = Color(0.9, 0.15, 0.15)
		health_bar.add_theme_stylebox_override("fill", fill)


func _on_player_died() -> void:
	if health_label:
		health_label.text = "YOU DIED"
		health_label.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	if health_bar:
		health_bar.value = 0


func _on_wave_started(wave_number: int, zombie_count: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d  [%d zombies]" % [wave_number, zombie_count]


func _on_wave_complete(wave_number: int) -> void:
	if wave_label:
		wave_label.text = "WAVE %d CLEAR!" % wave_number


func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = "%d" % new_score


func _on_ammo_changed(current: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d" % current
		var low = current <= 5
		ammo_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if low else Color(1, 1, 1, 0.95))
	if ammo_reserve_label:
		ammo_reserve_label.text = "/ %d" % reserve


func _on_shot_hit(is_kill: bool) -> void:
	if crosshair_label:
		var hit_color = Color(1.0, 0.1, 0.1, 1.0) if is_kill else Color(1.0, 1.0, 1.0, 1.0)
		crosshair_label.add_theme_color_override("font_color", hit_color)
		var tween = create_tween()
		tween.tween_interval(0.12)
		tween.tween_callback(func(): crosshair_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.0)))
	if is_kill and kill_feed:
		kill_feed_lines.push_front("+ KILL")
		kill_feed_lines.resize(3)
		kill_feed_timers.push_front(3.0)
		kill_feed_timers.resize(3)
		_update_kill_feed()


func _update_kill_feed() -> void:
	if not kill_feed:
		return
	var lines: Array = []
	for i in 3:
		if kill_feed_lines[i] != "":
			lines.append(kill_feed_lines[i])
	kill_feed.text = "\n".join(lines)


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
