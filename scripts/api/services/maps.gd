extends Node
class_name MapService

const BASE_PATH := "/api/v1/maps/"

static func list_maps(page: int, size: int, filters: Dictionary = {}) -> Dictionary:
	var params := {}
	params["size"] = size
	params["offset"] = max(0, (page - 1) * size)
	for key in filters.keys():
		var value = filters.get(key, null)
		if value == null:
			continue
		if typeof(value) == TYPE_STRING and str(value).strip_edges() == "":
			continue
		params[key] = value
	var query := _build_query(params)
	var url := BASE_PATH
	if query != "":
		url = "%s?%s" % [BASE_PATH, query]
	return await ApiClient.GET(url)

static func _build_query(params: Dictionary) -> String:
	var parts: Array[String] = []
	for key in params.keys():
		var value = params[key]
		var text := ""
		match typeof(value):
			TYPE_BOOL:
				text = "true" if value else "false"
			_:
				text = str(value)
		parts.append("%s=%s" % [str(key).uri_encode(), text.uri_encode()])
	return "&".join(parts)

static func increment_play(map_id: int) -> Dictionary:
	return await ApiClient.POST("%s%d/play" % [BASE_PATH, map_id], {})

static func fetch_detail(map_id: String) -> Dictionary:
	return await ApiClient.GET("%s%s" % [BASE_PATH, map_id])

static func download_map(map_id: String) -> Dictionary:
	return await ApiClient.GET_RAW("%s%s/download" % [BASE_PATH, map_id])

static func download_preview(map_id: String) -> Dictionary:
	return await ApiClient.GET_RAW("%s%s/preview" % [BASE_PATH, map_id])

static func fetch_leaderboard(map_id: String) -> Dictionary:
	return await ApiClient.GET("%s%s/leaderboard" % [BASE_PATH, map_id])

static func toggle_loved(map_id: String) -> Dictionary:
	return await ApiClient.POST("%s%s/loved" % [BASE_PATH, map_id], {})

static func upload_map(map_data: MapData, map_bytes: PackedByteArray, preview_bytes: PackedByteArray, map_id: int = -1) -> Dictionary:
	if map_data == null:
		return {"ok": false, "code": -1, "data": null, "raw_text": "", "headers": PackedStringArray(), "error": "map_data is null"}
	var meta := map_data.metadata
	var fields := {
		"title": str(meta.get("title", "")),
		"detail": str(meta.get("detail", "")),
		"rating": float(meta.get("rating", 1)),
	}
	var files := [
		{"name": "map_file", "filename": "map.kittymap", "bytes": map_bytes},
		{"name": "preview_file", "filename": "preview.kittymap", "bytes": preview_bytes},
	]
	print(fields)
	var method := HTTPClient.METHOD_POST
	var path := BASE_PATH
	if map_id > 0:
		method = HTTPClient.METHOD_PUT
		path = "%s%s" % [BASE_PATH, str(map_id)]
	return await _request_multipart(method, path, fields, files)

static func _append_str(body, value: String) -> void:
	body.append_array(value.to_utf8_buffer())

static func _request_multipart(method: int, path: String, fields: Dictionary, files: Array) -> Dictionary:
	var boundary := "----smallkitty-" + str(Time.get_unix_time_from_system())
	var body := PackedByteArray()
	
	for key in fields.keys():
		_append_str(body,"--%s\r\n" % boundary)
		_append_str(body,"Content-Disposition: form-data; name=\"%s\"\r\n\r\n" % str(key))
		_append_str(body,"%s\r\n" % str(fields[key]))
	for file in files:
		var name := str(file.get("name", "file"))
		var filename := str(file.get("filename", "file.bin"))
		var bytes: PackedByteArray = file.get("bytes", PackedByteArray())
		_append_str(body,"--%s\r\n" % boundary)
		_append_str(body,"Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n" % [name, filename])
		_append_str(body,"Content-Type: application/octet-stream\r\n\r\n")
		body.append_array(bytes)
		_append_str(body,"\r\n")
	_append_str(body,"--%s--\r\n" % boundary)

	var headers := PackedStringArray()
	headers.append("Content-Type: multipart/form-data; boundary=%s" % boundary)
	headers.append("Accept: application/json")
	var all_headers := ApiClient._build_headers(headers)
	var url := ApiClient._make_url(path)

	var req := HTTPRequest.new()
	ApiClient.add_child(req)
	req.timeout = 20.0
	var err = req.request_raw(url, all_headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": -1, "data": null, "raw_text": "", "headers": PackedStringArray(), "error": "request() failed: %s" % error_string(err)}

	var sig_args: Array = await req.request_completed
	var result: int = sig_args[0]
	var response_code: int = sig_args[1]
	var resp_headers: PackedStringArray = sig_args[2]
	var resp_body: PackedByteArray = sig_args[3]
	req.queue_free()

	var raw_text := resp_body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": response_code, "data": null, "raw_text": raw_text, "headers": resp_headers, "error": "network result failed: %s" % str(result)}
	var ok := response_code >= 200 and response_code < 300
	var parsed: Variant = null
	if raw_text.strip_edges() != "":
		parsed = JSON.parse_string(raw_text)
	return {"ok": ok, "code": response_code, "data": parsed, "raw_text": raw_text, "headers": resp_headers, "error": "" if ok else "http error: %d" % response_code}
