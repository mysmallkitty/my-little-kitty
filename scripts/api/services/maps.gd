extends Node
class_name MapService

const BASE_PATH := "/api/v1/maps"

static func list_maps(page: int, size: int) -> Dictionary:
	var url := "%s?page=%d&size=%d" % [BASE_PATH, page, size]
	return await ApiClient.GET(url)

static func fetch_detail(map_id: String) -> Dictionary:
	return await ApiClient.GET("%s/%s" % [BASE_PATH, map_id])

static func download_map(map_id: String) -> Dictionary:
	return await ApiClient.GET_RAW("%s/%s/download" % [BASE_PATH, map_id])

static func fetch_leaderboard(map_id: String) -> Dictionary:
	return await ApiClient.GET("%s/%s/leaderboard" % [BASE_PATH, map_id])
