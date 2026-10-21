extends Node
## OpenStreetMap Data Fetcher
## Downloads building footprints from Overpass API and parses them

signal buildings_loaded(buildings: Array)
signal streets_loaded(streets: Array)
signal fetch_error(message: String)
signal fetch_started
signal fetch_complete

# Overpass API endpoint
## Tried in order. Godot 4.2's TLS is 1.2-only, and overpass-api.de is TLS 1.3-only
## (handshake -30592), so it can't be used. The OSM main API returns the same JSON
## shape for a bbox and is the backup when the mail.ru Overpass mirror is busy (504).
const OVERPASS_URLS := [
	"https://maps.mail.ru/osm/tools/overpass/api/interpreter",
	OSM_API_URL,
]
const OSM_API_URL := "https://api.openstreetmap.org/api/0.6/map.json"
const USER_AGENT := "User-Agent: ZeroHour/0.4 (zombie game)"  # OSM usage policy
var _server_idx: int = 0
var _last_query: String = ""

# Cache for downloaded data
var _building_cache: Dictionary = {}
var _street_cache: Dictionary = {}
var _http_request: HTTPRequest = null

# Current fetch state
var is_fetching: bool = false
var last_fetch_lat: float = 0.0
var last_fetch_lon: float = 0.0
var fetch_radius: float = 200.0  # meters


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 20.0  # per server; next one is tried on failure
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)


## Fetch buildings around a GPS coordinate
func fetch_buildings(latitude: float, longitude: float, radius: float = 200.0) -> void:
	if is_fetching:
		print("[OSM] Already fetching, please wait...")
		return

	# Check cache first
	var cache_key = _get_cache_key(latitude, longitude)
	if _building_cache.has(cache_key):
		print("[OSM] Using cached data for: ", cache_key)
		buildings_loaded.emit(_building_cache[cache_key])
		return

	fetch_radius = radius
	last_fetch_lat = latitude
	last_fetch_lon = longitude

	var query = _build_overpass_query(latitude, longitude, radius)
	_execute_query(query)


## Build Overpass API query for buildings and streets
func _build_overpass_query(lat: float, lon: float, radius: float) -> String:
	# Query for buildings and streets within radius
	var query = """
[out:json][timeout:25];
(
  way["building"](around:{radius},{lat},{lon});
  way["highway"](around:{radius},{lat},{lon});
);
out body;
>;
out skel qt;
""".format({
		"radius": radius,
		"lat": lat,
		"lon": lon
	})
	return query


func _execute_query(query: String) -> void:
	is_fetching = true
	fetch_started.emit()

	_last_query = query
	var url: String = OVERPASS_URLS[_server_idx]
	var headers = ["Content-Type: application/x-www-form-urlencoded", USER_AGENT]
	var body = "data=" + query.uri_encode()
	var method := HTTPClient.METHOD_POST
	if url == OSM_API_URL:
		# Main API takes a bbox (lon/lat order), not an Overpass query
		var dlat := fetch_radius / 111320.0
		var dlon := fetch_radius / (111320.0 * cos(deg_to_rad(last_fetch_lat)))
		url += "?bbox=%f,%f,%f,%f" % [last_fetch_lon - dlon, last_fetch_lat - dlat,
			last_fetch_lon + dlon, last_fetch_lat + dlat]
		headers = [USER_AGENT]
		body = ""
		method = HTTPClient.METHOD_GET

	print("[OSM] Fetching data from ", url)
	var error = _http_request.request(url, headers, method, body)

	if error != OK:
		is_fetching = false
		fetch_error.emit("Failed to send request: " + str(error))


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	is_fetching = false
	fetch_complete.emit()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[OSM] ", OVERPASS_URLS[_server_idx], " failed: result ", result, " code ", response_code)
		_server_idx += 1
		if _server_idx < OVERPASS_URLS.size():
			_execute_query(_last_query)
			return
		_server_idx = 0
		if result != HTTPRequest.RESULT_SUCCESS:
			fetch_error.emit("Request failed with result: " + str(result))
		else:
			fetch_error.emit("Server returned code: " + str(response_code))
		return
	_server_idx = 0

	var json_string = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		fetch_error.emit("Failed to parse JSON response")
		return

	var data = json.get_data()
	_parse_osm_data(data)


func _parse_osm_data(data: Dictionary) -> void:
	if not data.has("elements"):
		fetch_error.emit("No elements in response")
		return

	var elements = data.elements
	var nodes: Dictionary = {}
	var buildings: Array = []
	var streets: Array = []

	# First pass: collect all nodes
	for element in elements:
		if element.type == "node":
			nodes[element.id] = {
				"lat": element.lat,
				"lon": element.lon
			}

	# Second pass: build polygons from ways
	for element in elements:
		if element.type != "way":
			continue

		if not element.has("nodes"):
			continue

		var polygon: Array = []
		for node_id in element.nodes:
			if nodes.has(node_id):
				polygon.append(nodes[node_id])

		if polygon.size() < 3:
			continue

		var tags = element.get("tags", {})

		if tags.has("building"):
			var building = {
				"id": element.id,
				"polygon": polygon,
				"tags": tags,
				"type": "building",
				"name": tags.get("name", ""),
				"building_type": tags.get("building", "yes"),
				"levels": _parse_levels(tags),
				"height": _parse_height(tags)
			}
			buildings.append(building)

		elif tags.has("highway"):
			var street = {
				"id": element.id,
				"points": polygon,
				"tags": tags,
				"name": tags.get("name", ""),
				"highway_type": tags.get("highway", "road")
			}
			streets.append(street)

	# Cache the results
	var cache_key = _get_cache_key(last_fetch_lat, last_fetch_lon)
	_building_cache[cache_key] = buildings
	_street_cache[cache_key] = streets

	print("[OSM] Loaded ", buildings.size(), " buildings and ", streets.size(), " streets")

	buildings_loaded.emit(buildings)
	streets_loaded.emit(streets)


func _parse_levels(tags: Dictionary) -> int:
	if tags.has("building:levels"):
		return int(tags["building:levels"])

	# Estimate based on building type
	var building_type = tags.get("building", "yes")
	match building_type:
		"house", "residential", "detached":
			return randi_range(1, 3)
		"apartments", "commercial":
			return randi_range(3, 8)
		"industrial", "warehouse":
			return randi_range(1, 2)
		"church", "cathedral":
			return randi_range(2, 4)
		_:
			return randi_range(1, 4)


func _parse_height(tags: Dictionary) -> float:
	if tags.has("height"):
		var height_str = tags["height"]
		# Remove "m" suffix if present
		height_str = height_str.replace(" m", "").replace("m", "")
		return float(height_str)

	# Estimate: ~3 meters per level
	var levels = _parse_levels(tags)
	return levels * 3.0


func _get_cache_key(lat: float, lon: float) -> String:
	# Round to 4 decimal places for cache key (~11 meter precision)
	return "%.4f,%.4f" % [lat, lon]


## Get cached buildings for a location (if available)
func get_cached_buildings(latitude: float, longitude: float) -> Array:
	var cache_key = _get_cache_key(latitude, longitude)
	if _building_cache.has(cache_key):
		return _building_cache[cache_key]
	return []


## Clear all cached data
func clear_cache() -> void:
	_building_cache.clear()
	_street_cache.clear()
	print("[OSM] Cache cleared")


## Save cache to disk for offline mode
func save_cache_to_disk(path: String = "user://osm_cache.json") -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var cache_data = {
			"buildings": _building_cache,
			"streets": _street_cache
		}
		file.store_string(JSON.stringify(cache_data))
		file.close()
		print("[OSM] Cache saved to disk")


## Load cache from disk for offline mode
func load_cache_from_disk(path: String = "user://osm_cache.json") -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()

		if parse_result == OK:
			var cache_data = json.get_data()
			_building_cache = cache_data.get("buildings", {})
			_street_cache = cache_data.get("streets", {})
			print("[OSM] Cache loaded from disk")
			return true

	return false
