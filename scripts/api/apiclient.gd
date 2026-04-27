extends Node

const client_version: String = "0.0.1"

var base_url := "https://smallkitty.p-e.kr"
var debug_log := false
var access_token: String = ""
var refresh_token: String = ""
var me: Dictionary
var is_server_down = false
var _paused_before_focus_loss := false
var _inflight_requests: Array[HTTPRequest] = []
var _presence_timer: Timer
const PRESENCE_POLL_INTERVAL := 10.0
const TOKEN_STORE_PATH := "user://auth_tokens.json"
signal auth_state_changed(is_logged_in: bool, reason: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	base_url = _resolve_base_url()
	print(base_url)
	_check_server_health()
	_setup_presence_keepalive()
	call_deferred("_auto_login")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_paused_before_focus_loss = get_tree().paused
		call_deferred("_send_presence_ping_once")
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if not _paused_before_focus_loss and get_tree().paused:
			get_tree().paused = false
		_on_focus_in()

func _on_focus_in() -> void:
	_cancel_inflight_requests()
	call_deferred("_resume_session")
	call_deferred("_ping_server")
	_resume_presence_keepalive()
	call_deferred("_send_presence_ping_once")

func set_base_url(url: String) -> void:
	var trimmed := url.strip_edges()
	if trimmed == "":
		return
	base_url = trimmed

func set_access_token(token: String) -> void:
	access_token = token
func set_refresh_token(token: String) -> void:
	refresh_token = token
func clear_access_token() -> void:
	access_token = ""

func clear_tokens() -> void:
	access_token = ""
	refresh_token = ""
	var path := TOKEN_STORE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	auth_state_changed.emit(false, "cleared")

func save_tokens() -> void:
	if refresh_token == "":
		return
	var file := FileAccess.open(TOKEN_STORE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var payload := {
		"refresh_token": refresh_token,
	}
	file.store_string(JSON.stringify(payload, ""))
	file.close()

func _load_tokens() -> void:
	if not FileAccess.file_exists(TOKEN_STORE_PATH):
		return
	var file := FileAccess.open(TOKEN_STORE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		refresh_token = str(data.get("refresh_token", ""))

func _auto_login() -> void:
	_load_tokens()
	if refresh_token == "":
		return
	var res := await POST("/api/v1/user/refresh", {"refresh_token": refresh_token})
	if res.get("ok", false) and typeof(res.get("data", null)) == TYPE_DICTIONARY:
		var data: Dictionary = res.get("data", {})
		if data.has("access_token"):
			set_access_token(str(data.get("access_token", "")))
		if data.has("refresh_token"):
			set_refresh_token(str(data.get("refresh_token", "")))
		save_tokens()
		var me_res := await GET("/api/v1/user/me")
		if me_res.get("ok", false) and typeof(me_res.get("data", null)) == TYPE_DICTIONARY:
			me = me_res["data"]
			auth_state_changed.emit(true, "auto_login")
		else:
			me = {}
			auth_state_changed.emit(false, "auto_login_failed")
	else:
		var code := int(res.get("code", -1))
		if code == 400 or code == 401:
			clear_tokens()
			auth_state_changed.emit(false, "auto_login_failed")
		# transient failure: keep tokens and retry on focus-in

func handle_auth_failure() -> void:
	clear_tokens()
	me = {}
	auth_state_changed.emit(false, "auth_failed")

func _build_headers(extra_headers: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var headers := PackedStringArray()
	headers.append("Accept: application/json")
	var has_content_type := false
	for h in extra_headers:
		if h.to_lower().begins_with("content-type:"):
			has_content_type = true
			break
	if not has_content_type:
		headers.append("Content-Type: application/json")
	headers.append("User-Agent: SmallKitty-Godot/" + client_version)
	headers.append("X-Client-Version: " + client_version)

	if access_token != "":
		headers.append("Authorization: Bearer " + access_token)

	for h in extra_headers:
		headers.append(h)

	return headers

func _check_server_health() -> void:
	var result: Dictionary = await ApiClient.GET("/health")
	if not result.get("ok", false):
		Alert.push("can't connect to server", true)
		is_server_down = true
		return
	var data = result.get("data", null)
	if typeof(data) == TYPE_DICTIONARY:
		#var status := str(data.get("status", ""))
		#Alert.push("server status: %s" % status, status != "ok")
		is_server_down = false

func _make_url(path: String) -> String:
	if path.begins_with("http://") or path.begins_with("https://"):
		return path
	if not path.begins_with("/"):
		path = "/" + path
	return base_url.trim_suffix("/") + path

func _resolve_base_url() -> String:
	var env_url := OS.get_environment("SMALLKITTY_API_URL")
	if env_url != "":
		print("env:" + env_url)
		return env_url
	var setting = ProjectSettings.get_setting("network/api_base_url", "")
	if typeof(setting) == TYPE_STRING:
		var trimmed := str(setting).strip_edges()
		if trimmed != "":
			return trimmed
	return base_url



func request_json(method: int, path: String, body: Variant = null, extra_headers: PackedStringArray = PackedStringArray(), allow_refresh: bool = true, suppress_auth_failure: bool = false) -> Dictionary:
	var url := _make_url(path)
	var req := HTTPRequest.new()
	req.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(req)
	_track_request(req)

	req.timeout = 3.0

	var headers := _build_headers(extra_headers)

	var payload := ""
	if body != null:
		payload = JSON.stringify(body)

	var err := req.request(url, headers, method, payload)
	if err != OK:
		_untrack_request(req)
		req.queue_free()
		return {
			"ok": false,
			"code": -1,
			"data": null,
			"raw_text": "",
			"headers": PackedStringArray(),
			"error": "request() failed: %s" % error_string(err),
		}

	var sig_args: Array = await req.request_completed
	var result: int = sig_args[0]
	var response_code: int = sig_args[1]
	var resp_headers: PackedStringArray = sig_args[2]
	var resp_body: PackedByteArray = sig_args[3]

	_untrack_request(req)
	req.queue_free()

	var raw_text := resp_body.get_string_from_utf8()
	if debug_log:
		print("HTTP ", method, " ", url, " -> ", response_code, " ", raw_text.left(200))

	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"code": response_code,
			"data": null,
			"raw_text": raw_text,
			"headers": resp_headers,
			"error": "cant connect to server",
		}

	var ok := response_code >= 200 and response_code < 300
	if response_code == 401:
		if allow_refresh and refresh_token != "":
			var refreshed := await _try_refresh_token()
			if refreshed:
				return await request_json(method, path, body, extra_headers, false, suppress_auth_failure)
		if not suppress_auth_failure:
			handle_auth_failure()

	var parsed: Variant = null
	if raw_text.strip_edges() != "":
		parsed = JSON.parse_string(raw_text)

	return {
		"ok": ok,
		"code": response_code,
		"data": parsed,
		"raw_text": raw_text,
		"headers": resp_headers,
		"error": "" if ok else "http error: %d" % response_code,
	}

func request_raw(method: int, path: String, body: Variant = null, extra_headers: PackedStringArray = PackedStringArray(), allow_refresh: bool = true, suppress_auth_failure: bool = false) -> Dictionary:
	var url := _make_url(path)
	var req := HTTPRequest.new()
	req.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(req)
	_track_request(req)

	req.timeout = 15.0
	var headers := _build_headers(extra_headers)
	var payload := ""
	if body != null:
		payload = JSON.stringify(body)

	var err := req.request(url, headers, method, payload)
	if err != OK:
		_untrack_request(req)
		req.queue_free()
		return {
			"ok": false,
			"code": -1,
			"bytes": PackedByteArray(),
			"raw_text": "",
			"headers": PackedStringArray(),
			"error": "request() failed: %s" % error_string(err),
		}

	var sig_args: Array = await req.request_completed
	var result: int = sig_args[0]
	var response_code: int = sig_args[1]
	var resp_headers: PackedStringArray = sig_args[2]
	var resp_body: PackedByteArray = sig_args[3]

	_untrack_request(req)
	req.queue_free()

	var raw_text := resp_body.get_string_from_utf8()
	if debug_log:
		print("HTTP ", method, " ", url, " -> ", response_code, " ", raw_text.left(200))

	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"code": response_code,
			"bytes": resp_body,
			"raw_text": raw_text,
			"headers": resp_headers,
			"error": "network result failed: %s" % str(result),
		}

	var ok := response_code >= 200 and response_code < 300
	if response_code == 401:
		if allow_refresh and refresh_token != "":
			var refreshed := await _try_refresh_token()
			if refreshed:
				return await request_raw(method, path, body, extra_headers, false, suppress_auth_failure)
		if not suppress_auth_failure:
			handle_auth_failure()
	return {
		"ok": ok,
		"code": response_code,
		"bytes": resp_body,
		"raw_text": raw_text,
		"headers": resp_headers,
		"error": "" if ok else "http error: %d" % response_code,
	}

func _encode_form(data: Dictionary) -> String:
	var parts: Array[String] = []
	for key in data.keys():
		var value := str(data[key])
		parts.append("%s=%s" % [str(key).uri_encode(), value.uri_encode()])
	return "&".join(parts)

func GET(path: String, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	return await request_json(HTTPClient.METHOD_GET, path, null, extra_headers)

func POST(path: String, body: Variant, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	return await request_json(HTTPClient.METHOD_POST, path, body, extra_headers)

func PUT(path: String, body: Variant, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	return await request_json(HTTPClient.METHOD_PUT, path, body, extra_headers)

func DELETE(path: String, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	return await request_json(HTTPClient.METHOD_DELETE, path, null, extra_headers)

func PATCH(path: String, body: Variant, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	return await request_json(HTTPClient.METHOD_PATCH, path, body, extra_headers)

func POST_FORM(path: String, body: Dictionary, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var headers := PackedStringArray()
	headers.append("Content-Type: application/x-www-form-urlencoded")
	for h in extra_headers:
		headers.append(h)
	var url := _make_url(path)
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 15.0
	var payload := _encode_form(body)
	var all_headers := _build_headers(headers)
	var err := req.request(url, all_headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		req.queue_free()
		return {
			"ok": false,
			"code": -1,
			"data": null,
			"raw_text": "",
			"headers": PackedStringArray(),
			"error": "request() failed: %s" % error_string(err),
		}
	var sig_args: Array = await req.request_completed
	var result: int = sig_args[0]
	var response_code: int = sig_args[1]
	var resp_headers: PackedStringArray = sig_args[2]
	var resp_body: PackedByteArray = sig_args[3]
	req.queue_free()
	var raw_text := resp_body.get_string_from_utf8()
	if debug_log:
		print("HTTP FORM ", url, " -> ", response_code, " ", raw_text.left(200))
	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"code": response_code,
			"data": null,
			"raw_text": raw_text,
			"headers": resp_headers,
			"error": "network result failed: %s" % str(result),
		}
	var ok := response_code >= 200 and response_code < 300
	var parsed: Variant = null
	if raw_text.strip_edges() != "":
		parsed = JSON.parse_string(raw_text)
	return {
		"ok": ok,
		"code": response_code,
		"data": parsed,
		"raw_text": raw_text,
		"headers": resp_headers,
		"error": "" if ok else "http error: %d" % response_code,
	}

func GET_RAW(path: String, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	return await request_raw(HTTPClient.METHOD_GET, path, null, extra_headers)

func _try_refresh_token() -> bool:
	if refresh_token == "":
		return false
	var res := await request_json(HTTPClient.METHOD_POST, "/api/v1/user/refresh", {"refresh_token": refresh_token}, PackedStringArray(), false, true)
	if res.get("ok", false) and typeof(res.get("data", null)) == TYPE_DICTIONARY:
		var data: Dictionary = res.get("data", {})
		if data.has("access_token"):
			set_access_token(str(data.get("access_token", "")))
		if data.has("refresh_token"):
			set_refresh_token(str(data.get("refresh_token", "")))
		save_tokens()
		return true
	return false

func _resume_session() -> void:
	if refresh_token == "":
		return
	if access_token == "":
		var refreshed := await _try_refresh_token()
		if not refreshed:
			return
	if typeof(me) == TYPE_DICTIONARY and not me.is_empty():
		return
	var me_res := await GET("/api/v1/user/me")
	if me_res.get("ok", false) and typeof(me_res.get("data", null)) == TYPE_DICTIONARY:
		me = me_res["data"]
		auth_state_changed.emit(true, "resume")

func _ping_server() -> void:
	await GET("/health")

func _setup_presence_keepalive() -> void:
	if _presence_timer != null:
		return
	_presence_timer = Timer.new()
	_presence_timer.one_shot = false
	_presence_timer.wait_time = PRESENCE_POLL_INTERVAL
	add_child(_presence_timer)
	_presence_timer.timeout.connect(_on_presence_tick)
	_presence_timer.start()

func _resume_presence_keepalive() -> void:
	if _presence_timer == null:
		return
	if not _presence_timer.is_stopped():
		return
	_presence_timer.start()

func _on_presence_tick() -> void:
	var result: Dictionary = await POST("/api/v1/records/presence/ping", {})
	if not result.get("ok", false):
		return

func _send_presence_ping_once() -> void:
	await POST("/api/v1/records/presence/ping", {})

func _track_request(req: HTTPRequest) -> void:
	_inflight_requests.append(req)

func _untrack_request(req: HTTPRequest) -> void:
	var idx := _inflight_requests.find(req)
	if idx >= 0:
		_inflight_requests.remove_at(idx)

func _cancel_inflight_requests() -> void:
	if _inflight_requests.is_empty():
		return
	for req in _inflight_requests:
		if req != null and is_instance_valid(req):
			req.cancel_request()

func _error_message(result: Dictionary) -> String:
	var data = result.get("data", null)
	if typeof(data) == TYPE_DICTIONARY:
		var detail := str(data.get("detail", ""))
		if detail != "":
			return detail
	var raw := str(result.get("raw_text", ""))
	if raw != "":
		return raw
	var error := str(result.get("error", ""))
	return error if error != "" else "unkwon error"
