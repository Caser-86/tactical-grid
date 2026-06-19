## API 客户端
## 与后端服务器通信，支持重试和错误处理
extends Node
class_name ApiClient

var base_url: String = "http://localhost:3000/api"
var auth_token: String = ""
var max_retries: int = 3
var retry_delay: float = 1.0

## 设置认证 token
func set_token(token: String) -> void:
	auth_token = token

## 注册
func register(username: String, password: String, email: String = "") -> Dictionary:
	var body = {
		"username": username,
		"password": password,
	}
	if email != "":
		body["email"] = email
	return await _post("/auth/register", body, false)

## 登录
func login(username: String, password: String) -> Dictionary:
	var body = {
		"username": username,
		"password": password,
	}
	return await _post("/auth/login", body, false)

## 游客登录
func guest_login() -> Dictionary:
	return await _post("/auth/guest", {}, false)

## 获取用户信息
func get_profile() -> Dictionary:
	return await _api_get("/user/profile")

## 获取战役关卡列表
func get_campaign() -> Dictionary:
	return await _api_get("/maps/campaign")

## 获取关卡详情
func get_level(level_id: String) -> Dictionary:
	return await _api_get("/maps/" + level_id)

## 随机生成关卡
func generate_map(params: Dictionary) -> Dictionary:
	return await _post("/maps/generate", params)

## 上报关卡结果
func complete_level(level_id: String, result: Dictionary) -> Dictionary:
	return await _post("/maps/" + level_id + "/complete", result)

## 获取存档列表
func get_saves() -> Dictionary:
	return await _api_get("/saves")

## 上传存档
func upload_save(save_data: Dictionary) -> Dictionary:
	return await _post("/saves", save_data)

## 下载存档
func download_save(save_id: String) -> Dictionary:
	return await _api_get("/saves/" + save_id)

## 上报遥测
func report_telemetry(events: Array) -> Dictionary:
	return await _post("/telemetry", {"events": events})

## GET 请求（带重试）
func _api_get(path: String) -> Dictionary:
	for attempt in range(max_retries):
		var result = await _do_request(path, HTTPClient.METHOD_GET, "", true)
		if result.code != -1:
			return result
		if attempt < max_retries - 1:
			push_warning("API GET failed, retrying (%d/%d): %s" % [attempt + 1, max_retries, path])
			await get_tree().create_timer(retry_delay * (attempt + 1)).timeout
	push_error("API GET failed after %d retries: %s" % [max_retries, path])
	return {"code": -1, "message": "Connection failed after retries"}

## POST 请求（带重试）
func _post(path: String, body: Dictionary, use_auth: bool = true) -> Dictionary:
	var headers = _build_headers(use_auth)
	var body_str = JSON.stringify(body)

	for attempt in range(max_retries):
		var result = await _do_request(path, HTTPClient.METHOD_POST, body_str, use_auth)
		if result.code != -1:
			return result
		if attempt < max_retries - 1:
			push_warning("API POST failed, retrying (%d/%d): %s" % [attempt + 1, max_retries, path])
			await get_tree().create_timer(retry_delay * (attempt + 1)).timeout
	push_error("API POST failed after %d retries: %s" % [max_retries, path])
	return {"code": -1, "message": "Connection failed after retries"}

## 构建请求头
func _build_headers(use_auth: bool) -> PackedStringArray:
	var headers = PackedStringArray(["Content-Type: application/json"])
	if use_auth and auth_token != "":
		headers.append("Authorization: Bearer " + auth_token)
	return headers

## 执行单次请求
func _do_request(path: String, method: HTTPClient.Method, body: String, use_auth: bool) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	var headers = _build_headers(use_auth)

	var err = http.request(base_url + path, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"code": -1, "message": "Request init failed"}

	var response = await http.request_completed
	http.queue_free()

	var result = response[0]
	var status_code = response[1]
	var resp_body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return {"code": -1, "message": "Network error (code: %d)" % result}

	if status_code >= 500:
		return {"code": -1, "message": "Server error (HTTP %d)" % status_code}

	var json = JSON.parse_string(resp_body.get_string_from_utf8())
	if not json:
		return {"code": -1, "message": "Invalid JSON response"}

	return json
