## API 客户端
## 与后端服务器通信
extends Node
class_name ApiClient

var base_url: String = "http://localhost:3000/api"
var auth_token: String = ""

## 服务端是否启用（离线优先：默认不连接）
var server_enabled: bool = false

## 设置认证 token
func set_token(token: String) -> void:
	auth_token = token

## 设置是否使用服务端
func set_server_enabled(enabled: bool) -> void:
	server_enabled = enabled

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
	return await _http_get("/user/profile")

## 获取战役关卡列表
func get_campaign() -> Dictionary:
	return await _http_get("/maps/campaign")

## 获取关卡详情
func get_level(level_id: String) -> Dictionary:
	return await _http_get("/maps/" + level_id)

## 随机生成关卡
func generate_map(params: Dictionary) -> Dictionary:
	return await _post("/maps/generate", params)

## 上报关卡结果
func complete_level(level_id: String, result: Dictionary) -> Dictionary:
	return await _post("/maps/" + level_id + "/complete", result)

## 获取存档列表
func get_saves() -> Dictionary:
	return await _http_get("/saves")

## 上传存档
func upload_save(save_data: Dictionary) -> Dictionary:
	return await _post("/saves", save_data)

## 下载存档
func download_save(save_id: String) -> Dictionary:
	return await _http_get("/saves/" + save_id)

## 上报遥测
func report_telemetry(events: Array) -> Dictionary:
	return await _post("/telemetry", {"events": events})

## GET 请求
func _http_get(path: String) -> Dictionary:
	if not server_enabled:
		return {"code": -1, "message": "Server disabled (offline mode)"}

	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Content-Type: application/json"]
	if auth_token != "":
		headers.append("Authorization: Bearer " + auth_token)

	var err = http.request(base_url + path, headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		http.queue_free()
		return {"code": -1, "message": "Request failed"}

	var response = await http.request_completed
	http.queue_free()

	var result = response[0]
	var body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return {"code": -1, "message": "Request failed"}

	var json = JSON.parse_string(body.get_string_from_utf8())
	return json if json else {"code": -1, "message": "Parse error"}

## POST 请求
func _post(path: String, body: Dictionary, use_auth: bool = true) -> Dictionary:
	if not server_enabled:
		return {"code": -1, "message": "Server disabled (offline mode)"}

	var http = HTTPRequest.new()
	add_child(http)
	var headers = ["Content-Type: application/json"]
	if use_auth and auth_token != "":
		headers.append("Authorization: Bearer " + auth_token)

	var body_str = JSON.stringify(body)
	var err = http.request(base_url + path, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		http.queue_free()
		return {"code": -1, "message": "Request failed"}

	var response = await http.request_completed
	http.queue_free()

	var result = response[0]
	var resp_body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		return {"code": -1, "message": "Request failed"}

	var json = JSON.parse_string(resp_body.get_string_from_utf8())
	return json if json else {"code": -1, "message": "Parse error"}
