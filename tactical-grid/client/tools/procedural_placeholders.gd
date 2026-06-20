extends SceneTree

## 程序化生成占位美术资源
## 这些资源用于占位，后续应被 AI 生成图替换

const OUT_DIR := "res://../assets/store_assets/placeholders/"

const PALETTE := {
	"bg_dark": Color(0.06, 0.08, 0.12),
	"bg_mid": Color(0.10, 0.14, 0.20),
	"accent_teal": Color(0.24, 0.73, 0.45),
	"accent_orange": Color(1.0, 0.55, 0.18),
	"grid": Color(0.18, 0.26, 0.36, 0.5),
	"text": Color(0.9, 0.92, 0.95),
}

func _init() -> void:
	_ensure_dir(OUT_DIR)

	_generate_icon(OUT_DIR + "icon_placeholder.png", 512)
	_generate_capsule(OUT_DIR + "capsule_main_placeholder.png", 460, 215)
	_generate_capsule(OUT_DIR + "capsule_vertical_placeholder.png", 600, 900)
	_generate_screenshot(OUT_DIR + "screenshot_01_placeholder.png", "MAIN MENU")
	_generate_screenshot(OUT_DIR + "screenshot_02_placeholder.png", "TACTICAL BATTLE")
	_generate_screenshot(OUT_DIR + "screenshot_03_placeholder.png", "BASE OF OPERATIONS")
	_generate_screenshot(OUT_DIR + "screenshot_04_placeholder.png", "ROGUELIKE MAP")
	_generate_screenshot(OUT_DIR + "screenshot_05_placeholder.png", "SKILL EFFECTS")

	_generate_effect_frames(OUT_DIR + "explosion_frames/", 128, 8, _draw_explosion)
	_generate_effect_frames(OUT_DIR + "muzzle_flash_frames/", 64, 4, _draw_muzzle_flash)
	_generate_effect_frames(OUT_DIR + "heal_frames/", 128, 8, _draw_heal)
	_generate_effect_frames(OUT_DIR + "shield_frames/", 128, 8, _draw_shield)
	_generate_effect_frames(OUT_DIR + "smoke_frames/", 128, 8, _draw_smoke)
	_generate_effect_frames(OUT_DIR + "teleport_frames/", 128, 8, _draw_teleport)
	_generate_effect_frames(OUT_DIR + "buff_frames/", 128, 8, _draw_buff)
	_generate_effect_frames(OUT_DIR + "debuff_frames/", 128, 8, _draw_debuff)
	_generate_effect_frames(OUT_DIR + "electro_frames/", 128, 8, _draw_electro)
	_generate_effect_frames(OUT_DIR + "burn_frames/", 128, 8, _draw_burn)
	_generate_effect_frames(OUT_DIR + "freeze_frames/", 128, 8, _draw_freeze)

	_generate_unit_frames(OUT_DIR + "unit_frames/")

	print("Procedural placeholders generated in: ", OUT_DIR)
	quit()

func _ensure_dir(path: String) -> void:
	var base = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base):
		DirAccess.make_dir_recursive_absolute(base)

func _create_image(width: int, height: int) -> Image:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(PALETTE.bg_dark)
	return img

func _draw_grid(img: Image, spacing: int, color: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	for x in range(0, w, spacing):
		for y in range(0, h):
			img.set_pixel(x, y, color)
	for y in range(0, h, spacing):
		for x in range(0, w):
			img.set_pixel(x, y, color)

func _draw_hexagon(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = []
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	for i in range(6):
		_draw_line(img, points[i], points[(i + 1) % 6], color, 2)

func _draw_line(img: Image, a: Vector2, b: Vector2, color: Color, width: int) -> void:
	var d = b - a
	var steps = int(d.length())
	if steps == 0:
		return
	for i in range(steps + 1):
		var p = a + d * (float(i) / steps)
		for ox in range(-width / 2, width / 2 + 1):
			for oy in range(-width / 2, width / 2 + 1):
				var px = int(p.x + ox)
				var py = int(p.y + oy)
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)

func _draw_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var r2 = radius * radius
	for x in range(int(center.x - radius), int(center.x + radius) + 1):
		for y in range(int(center.y - radius), int(center.y + radius) + 1):
			if Vector2(x, y).distance_squared_to(center) <= r2:
				if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
					img.set_pixel(x, y, color)

func _draw_text_label(img: Image, label: String, color: Color) -> void:
	# 用像素点拼出简单文字（无法加载字体时的兜底）
	# 这里只画文字区域块作为占位
	var w = img.get_width()
	var h = img.get_height()
	var bar_w = min(w * 0.7, 600)
	var bar_h = max(h * 0.12, 40)
	var x0 = int((w - bar_w) / 2)
	var y0 = int(h * 0.75)
	for x in range(x0, int(x0 + bar_w)):
		for y in range(y0, int(y0 + bar_h)):
			img.set_pixel(x, y, color)

func _generate_icon(path: String, size: int) -> void:
	var img = _create_image(size, size)
	# 渐变背景
	for y in range(size):
		for x in range(size):
			var t = float(y) / size
			img.set_pixel(x, y, PALETTE.bg_dark.lerp(PALETTE.bg_mid, t))

	# 网格
	_draw_grid(img, size / 16, PALETTE.grid)

	# 外圈
	var center = Vector2(size / 2, size / 2)
	for r in range(size * 0.42, size * 0.45):
		_draw_circle(img, center, r, PALETTE.accent_teal)

	# 内圆
	_draw_circle(img, center, size * 0.18, PALETTE.accent_teal)

	# 十字准星
	var arm = size * 0.32
	_draw_line(img, center + Vector2(-arm, 0), center + Vector2(-size * 0.12, 0), PALETTE.accent_orange, 6)
	_draw_line(img, center + Vector2(arm, 0), center + Vector2(size * 0.12, 0), PALETTE.accent_orange, 6)
	_draw_line(img, center + Vector2(0, -arm), center + Vector2(0, -size * 0.12), PALETTE.accent_orange, 6)
	_draw_line(img, center + Vector2(0, arm), center + Vector2(0, size * 0.12), PALETTE.accent_orange, 6)

	img.save_png(path)

func _generate_capsule(path: String, width: int, height: int) -> void:
	var img = _create_image(width, height)
	for y in range(height):
		for x in range(width):
			var t = float(x + y) / (width + height)
			img.set_pixel(x, y, PALETTE.bg_dark.lerp(PALETTE.bg_mid, t))

	_draw_grid(img, max(width, height) / 12, PALETTE.grid)

	var center = Vector2(width / 2, height / 2)
	_draw_hexagon(img, center, min(width, height) * 0.25, PALETTE.accent_teal)
	_draw_circle(img, center, min(width, height) * 0.08, PALETTE.accent_orange)

	_draw_text_label(img, "TACTICAL GRID", PALETTE.text)
	img.save_png(path)

func _generate_screenshot(path: String, label: String) -> void:
	var img = _create_image(1920, 1080)
	for y in range(1080):
		for x in range(1920):
			var t = float(y) / 1080
			img.set_pixel(x, y, PALETTE.bg_dark.lerp(PALETTE.bg_mid, t))

	_draw_grid(img, 80, PALETTE.grid)

	var center = Vector2(960, 540)
	_draw_hexagon(img, center, 180, PALETTE.accent_teal)
	_draw_circle(img, center, 70, PALETTE.accent_orange)

	_draw_text_label(img, label, PALETTE.text)
	img.save_png(path)

func _generate_effect_frames(dir_path: String, size: int, count: int, drawer: Callable) -> void:
	_ensure_dir(dir_path)
	for i in range(count):
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		drawer.call(img, i, count)
		img.save_png(dir_path + "frame_%02d.png" % (i + 1))

func _draw_explosion(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var max_r = img.get_width() * 0.45
	var r = lerp(max_r * 0.2, max_r, t)
	var color = PALETTE.accent_orange
	color.a = 1.0 - t * 0.5
	_draw_circle(img, center, r, color)
	# 火花
	for j in range(8):
		var angle = deg_to_rad(45 * j + frame * 10)
		var d = r * (0.6 + 0.4 * sin(t * PI))
		var p = center + Vector2(cos(angle), sin(angle)) * d
		_draw_circle(img, p, r * 0.15, PALETTE.accent_teal)

func _draw_muzzle_flash(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() * 0.3, img.get_height() / 2)
	var length = lerp(img.get_width() * 0.3, img.get_width() * 0.7, 1.0 - t)
	var target = center + Vector2(length, 0)
	var color = PALETTE.accent_orange
	color.a = 1.0 - t * 0.7
	_draw_line(img, center, target, color, max(4, int(img.get_height() * 0.25 * (1.0 - t))))

func _draw_heal(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var color = PALETTE.accent_teal
	color.a = 0.8
	_draw_circle(img, center, img.get_width() * (0.2 + 0.15 * sin(t * PI)), color)
	for j in range(6):
		var angle = deg_to_rad(60 * j + frame * 15)
		var p = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.3
		_draw_circle(img, p, img.get_width() * 0.06, color)

func _draw_shield(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var r = img.get_width() * 0.4
	var color = PALETTE.accent_teal
	color.a = 0.3 + 0.4 * sin(t * PI)
	_draw_hexagon(img, center, r, color)
	_draw_hexagon(img, center, r * 0.7, color)

func _draw_smoke(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	for i in range(6):
		var angle = deg_to_rad(60 * i + frame * 8)
		var dist = img.get_width() * 0.15 * (1.0 + t * 1.5)
		var p = center + Vector2(cos(angle), sin(angle)) * dist
		var r = img.get_width() * (0.1 + 0.15 * t)
		var color = Color(0.5, 0.5, 0.55)
		color.a = 0.6 - t * 0.5
		_draw_circle(img, p, r, color)

func _draw_teleport(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var color = PALETTE.accent_teal
	color.a = 0.7 - t * 0.4
	for r in range(3):
		var rr = img.get_width() * (0.1 + 0.12 * r + 0.2 * t)
		_draw_circle(img, center, rr, color)
	for i in range(8):
		var angle = deg_to_rad(45 * i - frame * 20)
		var p = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.35
		_draw_circle(img, p, img.get_width() * 0.04, color)

func _draw_buff(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var color = PALETTE.accent_teal
	color.a = 0.5
	_draw_circle(img, center, img.get_width() * 0.25, color)
	for i in range(4):
		var angle = deg_to_rad(90 * i + frame * 15)
		var start = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.2
		var end = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.4
		_draw_line(img, start, end, color, 4)
	var arrow = center - Vector2(0, img.get_width() * 0.1 * sin(t * PI))
	_draw_circle(img, arrow, img.get_width() * 0.08, Color(1, 1, 1, 0.8))

func _draw_debuff(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var color = Color(0.8, 0.2, 0.2)
	color.a = 0.5
	_draw_circle(img, center, img.get_width() * 0.25, color)
	for i in range(4):
		var angle = deg_to_rad(90 * i - frame * 15)
		var start = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.2
		var end = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.4
		_draw_line(img, start, end, color, 4)
	var arrow = center + Vector2(0, img.get_width() * 0.1 * sin(t * PI))
	_draw_circle(img, arrow, img.get_width() * 0.08, Color(0.9, 0.1, 0.1, 0.8))

func _draw_electro(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var color = Color(0.3, 0.7, 1.0)
	color.a = 0.8
	_draw_circle(img, center, img.get_width() * 0.2, color)
	# 闪电分支
	var rng = RandomNumberGenerator.new()
	rng.seed = frame * 12345
	for _i in range(4):
		var angle = rng.randf() * PI * 2
		var length = img.get_width() * (0.2 + 0.25 * rng.randf())
		var start = center
		var segments = 4
		for s in range(segments):
			var offset = Vector2(cos(angle + rng.randf() * 0.8 - 0.4), sin(angle + rng.randf() * 0.8 - 0.4)) * (length / segments)
			var end = start + offset
			_draw_line(img, start, end, color, 3)
			start = end

func _draw_burn(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	for i in range(5):
		var angle = deg_to_rad(72 * i + frame * 12)
		var h = img.get_height() * (0.2 + 0.25 * sin(t * PI + i))
		var base = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.15
		var tip = base - Vector2(0, h)
		var color = Color(1.0, 0.3 + 0.4 * t, 0.0)
		color.a = 0.7
		_draw_line(img, base, tip, color, 6)

func _draw_freeze(img: Image, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var center = Vector2(img.get_width() / 2, img.get_height() / 2)
	var color = Color(0.5, 0.8, 1.0)
	color.a = 0.6
	for i in range(6):
		var angle = deg_to_rad(60 * i + frame * 10)
		var inner = center + Vector2(cos(angle), sin(angle)) * img.get_width() * 0.15
		var outer = center + Vector2(cos(angle), sin(angle)) * img.get_width() * (0.35 + 0.1 * sin(t * PI))
		_draw_line(img, inner, outer, color, 4)
		_draw_circle(img, outer, img.get_width() * 0.05, color)
	_draw_hexagon(img, center, img.get_width() * 0.25, color)

# === 单位序列帧占位 ===

const UNIT_JOBS := {
	"assault": {"primary": Color(0.2, 0.55, 0.85), "secondary": Color(0.1, 0.2, 0.3), "weapon": "rifle", "scale": 1.0},
	"sniper": {"primary": Color(0.25, 0.5, 0.75), "secondary": Color(0.08, 0.15, 0.25), "weapon": "long", "scale": 0.95},
	"medic": {"primary": Color(0.85, 0.9, 0.95), "secondary": Color(0.2, 0.55, 0.75), "weapon": "medgun", "scale": 0.95},
	"scout": {"primary": Color(0.15, 0.2, 0.28), "secondary": Color(0.2, 0.65, 0.85), "weapon": "smg", "scale": 0.88},
	"heavy": {"primary": Color(0.45, 0.55, 0.65), "secondary": Color(0.2, 0.35, 0.5), "weapon": "heavy", "scale": 1.15},
	"sentry_basic": {"primary": Color(0.85, 0.2, 0.2), "secondary": Color(0.2, 0.05, 0.05), "weapon": "rifle", "scale": 0.95, "robot": true},
}

func _generate_unit_frames(base_dir: String) -> void:
	var size = Vector2i(64, 88)
	var states = ["idle", "move", "attack", "hit"]
	for job in UNIT_JOBS:
		var cfg = UNIT_JOBS[job]
		for state in states:
			var dir_path = base_dir + "%s/%s/" % [job, state]
			_ensure_dir(dir_path)
			for frame in range(4):
				var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
				img.fill(Color(0, 0, 0, 0))
				_draw_unit_frame(img, job, cfg, state, frame, 4)
				img.save_png(dir_path + "frame_%02d.png" % (frame + 1))

func _draw_unit_frame(img: Image, job: String, cfg: Dictionary, state: String, frame: int, total: int) -> void:
	var t = float(frame) / (total - 1)
	var w = img.get_width()
	var h = img.get_height()
	var cx = w / 2.0
	var base_y = h * 0.72
	var scale = cfg.get("scale", 1.0)
	var is_robot = cfg.get("robot", false)
	var primary: Color = cfg.primary
	var secondary: Color = cfg.secondary

	# 待机动画：轻微上下浮动
	var float_y = 0.0
	if state == "idle":
		float_y = sin(t * PI * 2) * 2.0
	elif state == "move":
		float_y = sin(t * PI * 4) * 3.0

	# 身体中心
	var body_cx = cx
	var body_cy = base_y - 28 * scale + float_y

	# 腿部
	var leg_color = secondary.darkened(0.2)
	var leg_w = 8 * scale
	var leg_h = 22 * scale
	var leg_offset = 0.0
	if state == "move":
		leg_offset = sin(t * PI * 2) * 6 * scale
	_draw_rect_centered(img, Vector2(body_cx - 10 * scale + leg_offset, base_y - leg_h / 2), Vector2(leg_w, leg_h), leg_color)
	_draw_rect_centered(img, Vector2(body_cx + 10 * scale - leg_offset, base_y - leg_h / 2), Vector2(leg_w, leg_h), leg_color)

	# 躯干
	var body_w = 26 * scale
	var body_h = 30 * scale
	_draw_rect_centered(img, Vector2(body_cx, body_cy), Vector2(body_w, body_h), primary)
	_draw_rect_centered(img, Vector2(body_cx, body_cy), Vector2(body_w - 4 * scale, body_h - 4 * scale), secondary)

	# 头部
	var head_r = 8 * scale
	var head_cy = body_cy - body_h / 2 - head_r + 2 * scale
	_draw_circle(img, Vector2(body_cx, head_cy), head_r, primary.lightened(0.15))
	if is_robot:
		_draw_circle(img, Vector2(body_cx + 2 * scale, head_cy - 1 * scale), head_r * 0.3, Color(1, 0.2, 0.2))

	# 武器
	var weapon_color = Color(0.25, 0.27, 0.3)
	var weapon_tip = Vector2(body_cx + 26 * scale, head_cy + 4 * scale)
	var weapon_base = Vector2(body_cx + 10 * scale, body_cy)
	match cfg.weapon:
		"rifle":
			_draw_line(img, weapon_base, weapon_tip, weapon_color, int(3 * scale))
		"long":
			weapon_tip = Vector2(body_cx + 32 * scale, head_cy + 2 * scale)
			_draw_line(img, weapon_base, weapon_tip, weapon_color, int(2 * scale))
		"smg":
			weapon_tip = Vector2(body_cx + 22 * scale, head_cy + 8 * scale)
			_draw_line(img, weapon_base, weapon_tip, weapon_color, int(3 * scale))
		"medgun":
			weapon_color = Color(0.2, 0.8, 0.55)
			_draw_line(img, weapon_base, weapon_tip, weapon_color, int(3 * scale))
			_draw_circle(img, weapon_tip, 3 * scale, Color(0.4, 1.0, 0.7))
		"heavy":
			weapon_tip = Vector2(body_cx + 28 * scale, head_cy + 8 * scale)
			_draw_rect_centered(img, (weapon_base + weapon_tip) / 2, Vector2((weapon_tip - weapon_base).length(), 6 * scale), weapon_color)

	# 攻击状态：武器上抬
	if state == "attack":
		var muzzle = weapon_tip + Vector2(6 * scale, -2 * scale)
		_draw_circle(img, muzzle, 3 * scale, PALETTE.accent_orange)

	# 受击状态：红色闪烁
	if state == "hit":
		for x in range(w):
			for y in range(h):
				var c = img.get_pixel(x, y)
				if c.a > 0:
					img.set_pixel(x, y, c.lerp(Color(1, 0.3, 0.3), 0.4))

func _draw_rect_centered(img: Image, center: Vector2, size: Vector2, color: Color) -> void:
	var x0 = int(center.x - size.x / 2)
	var y0 = int(center.y - size.y / 2)
	for x in range(x0, int(center.x + size.x / 2)):
		for y in range(y0, int(center.y + size.y / 2)):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, color)
