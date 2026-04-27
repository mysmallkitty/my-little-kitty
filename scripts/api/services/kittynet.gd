class_name KittynetService
extends Node

const USER_PATH := "/api/v1/user"
const LEADERBOARD_PATH := "/api/v1/records/leaderboard"

static func list_online_users(limit: int = 20, offset: int = 0) -> Dictionary:
	var url := "%s/online?limit=%d&offset=%d" % [USER_PATH, limit, offset]
	var result: Dictionary = await ApiClient.GET(url)
	if result.get("ok", false):
		result["source"] = "online"
		return result

	url = "%s?online_only=true&size=%d&offset=%d" % [USER_PATH, limit, offset]
	result = await ApiClient.GET(url)
	if result.get("ok", false):
		result["source"] = "filter"
		return result

	url = "%s?size=%d&offset=%d" % [USER_PATH, limit, offset]
	result = await ApiClient.GET(url)
	result["source"] = "fallback"
	return result

static func search_users(query: String, limit: int = 20, offset: int = 0) -> Dictionary:
	var q := query.strip_edges().uri_encode()
	var url := "%s?username=%s&size=%d&offset=%d" % [USER_PATH, q, limit, offset]
	return await ApiClient.GET(url)

static func fetch_user_detail(user_id: int) -> Dictionary:
	var url := "%s/%d" % [USER_PATH, user_id]
	return await ApiClient.GET(url)

static func fetch_leaderboard(page: int = 1, limit: int = 20) -> Dictionary:
	var url := "%s?page=%d&limit=%d" % [LEADERBOARD_PATH, page, limit]
	return await ApiClient.GET(url)

static func fetch_user_records(user_id: int, limit: int = 50) -> Dictionary:
	var paths := [
		"/api/v1/records/user/%d?limit=%d" % [user_id, limit],
		"/api/v1/user/%d/records?limit=%d" % [user_id, limit],
		"/api/v1/records/%d?limit=%d" % [user_id, limit],
	]
	var last: Dictionary = {}
	for path in paths:
		var result: Dictionary = await ApiClient.GET(path)
		last = result
		if result.get("ok", false):
			return result
	return last
