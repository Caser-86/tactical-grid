extends SceneTree

const Runner = preload("res://tests/v2/test_runner.gd")
const Recorder = preload("res://scripts/v2/mission/v2_playtest_recorder.gd")

var t := Runner.new()

func _initialize() -> void:
	var recorder := Recorder.new()
	var started := recorder.start("P01", "standard")
	t.check(bool(started.get("success", false)), "匿名试玩记录器启动成功")
	t.check(String(started.get("participant_id", "")) == "P01", "只保存匿名参与者编号")
	t.check(String(started.get("mission_id", "")) == "ch1_m1", "记录固定绑定 M1")

	var selected := recorder.record(&"unit_selected", {"unit_id": "player_assault"})
	var moved := recorder.record(&"move_committed", {"from": [3, 14], "to": [4, 13]})
	t.check(bool(selected.get("success", false)) and bool(moved.get("success", false)), "允许记录关键试玩事件")
	var rejected := recorder.record(&"unit_selected", {"player_name": "should-not-enter"})
	t.check(not bool(rejected.get("success", false)), "拒绝含隐私字段的事件")
	var unknown := recorder.record(&"unknown_event", {})
	t.check(not bool(unknown.get("success", false)), "拒绝未定义事件")
	var session := recorder.finish({"would_continue": true, "completed": false})
	t.check(String(session.get("participant_id", "")) == "P01", "完成后保留匿名编号")
	t.check((session.get("events", []) as Array).size() == 4, "事件按发生顺序保存")
	t.check(int((session.get("events", []) as Array)[0].get("elapsed_ms", -1)) >= 0, "事件保存相对时间")
	t.check(not session.has("player_name") and not session.has("machine_name"), "记录不含姓名或机器名")
	t.check(not session.has("account") and not session.has("username") and not session.has("ip_address"), "记录不含账号或网络隐私")
	t.check(bool(session.get("result", {}).get("would_continue", false)), "完成结果保存继续意愿")
	t.check((recorder.get_session().get("events", []) as Array).size() == 4, "拒绝事件不会进入记录")
	var save_result := recorder.get_last_save()
	t.check(bool(save_result.get("success", false)), "完成试玩后写入本地 JSON")
	var output_path := String(save_result.get("path", ""))
	t.check(output_path == "user://playtests/m1/P01.json" and FileAccess.file_exists(output_path), "本地输出路径固定且文件存在")
	var saved_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_path))
	t.check(saved_data is Dictionary and String((saved_data as Dictionary).get("participant_id", "")) == "P01", "写入文件可重新解析")

	var owner_recorder := Recorder.new()
	var owner_started := owner_recorder.start("OWNER", "story")
	t.check(bool(owner_started.get("success", false)), "OWNER 单人验收会话启动成功")
	var owner_session := owner_recorder.get_session()
	t.check(String(owner_session.get("mission_version", "")) == "v2_m1", "记录绑定 V2 M1 版本")
	t.check(not String(owner_session.get("started_at_utc", "")).is_empty(), "记录会话 UTC 开始时间")
	var production_events := [
		[&"move_committed", {"turn": 1, "from": [3, 14], "to": [4, 13]}],
		[&"attack_committed", {"turn": 1, "target_id": "m1_sentry_rescue"}],
		[&"invalid_click", {"turn": 1, "reason": "outside_board"}],
		[&"action_cancelled", {"turn": 1, "action": "attack"}],
		[&"camera_pan", {"turn": 1, "distance": 3}],
		[&"camera_focus_returned", {"turn": 1, "method": "F"}],
		[&"damage_resolved", {"turn": 1, "amount": 2}],
		[&"intent_resolved", {"turn": 2, "intent": "move"}],
		[&"inactivity_10s", {"turn": 2}],
		[&"unit_downed", {"turn": 2, "unit_role": "assault"}],
		[&"retry_started", {"turn": 3, "checkpoint_id": "cp_rescue"}],
		[&"soft_lock_detected", {"turn": 3, "reason": "no_valid_actions"}],
	]
	for event_data in production_events:
		var event_result: Dictionary = owner_recorder.record(event_data[0], event_data[1])
		t.check(bool(event_result.get("success", false)), "生产字段事件可追加：%s" % String(event_data[0]))
	var owner_finished := owner_recorder.finish({"completed": true, "result": "victory", "turns": 3, "human_result": "approved"})
	var counters: Dictionary = owner_finished.get("counters", {})
	t.check(String(owner_finished.get("human_result", "")) == "incomplete", "记录器拒绝 AI 写入 approved")
	t.check(int(owner_finished.get("turns", 0)) == 3, "会话保存最终回合数")
	t.check(int(owner_finished.get("first_move_elapsed_ms", -1)) >= 0 and int(owner_finished.get("first_attack_elapsed_ms", -1)) >= 0, "会话保存首次移动和攻击时间")
	t.check(int(counters.get("actions", 0)) == 2, "动作计数包含移动和攻击")
	t.check(int(counters.get("invalid_clicks", 0)) == 1 and int(counters.get("cancels", 0)) == 1, "记录无效点击和取消次数")
	t.check(int(counters.get("pans", 0)) == 1 and int(counters.get("focus_returns", 0)) == 1, "记录镜头平移和回到队员次数")
	t.check(int(counters.get("damage_events", 0)) == 1 and int(counters.get("intent_resolutions", 0)) == 1, "记录伤害和敌方意图结算次数")
	t.check(int(counters.get("inactivity_events", 0)) == 1 and int(counters.get("downed", 0)) == 1, "记录停滞和倒地次数")
	t.check(int(counters.get("retries", 0)) == 1 and int(counters.get("soft_locks", 0)) == 1, "记录重试和软锁次数")
	t.check(not owner_finished.has("screenshots") and not owner_finished.has("personal_identifiers"), "默认记录不包含截图或个人标识")
	var owner_save := owner_recorder.get_last_save()
	t.check(String(owner_save.get("path", "")) == "user://playtests/m1/OWNER.json" and FileAccess.file_exists("user://playtests/m1/OWNER.json"), "OWNER 会话写入独立本地 JSON")
	t.finish(self)
