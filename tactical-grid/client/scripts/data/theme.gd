## 游戏颜色主题
## 统一管理所有 UI 和游戏元素的颜色
class_name GameTheme

# 阵营颜色
const PLAYER_COLOR = Color(0.13, 0.59, 0.95)      # 蓝色
const ENEMY_COLOR = Color(0.96, 0.26, 0.21)        # 红色
const NEUTRAL_COLOR = Color(1.0, 0.75, 0.03)       # 黄色
const FRIENDLY_NPC_COLOR = Color(0.30, 0.69, 0.31) # 绿色

# 地形颜色
const TERRAIN_COLORS = {
	0: Color(0.30, 0.40, 0.30),  # plain - 暗绿
	1: Color(0.40, 0.35, 0.25),  # road - 棕色
	2: Color(0.10, 0.30, 0.10),  # forest - 深绿
	3: Color(0.60, 0.50, 0.30),  # sand - 沙色
	4: Color(0.40, 0.30, 0.20),  # highland - 棕红
	5: Color(0.10, 0.20, 0.50),  # water - 蓝
	6: Color(0.20, 0.20, 0.20),  # wall - 灰
	7: Color(0.50, 0.40, 0.20),  # crate - 木色
	8: Color(0.30, 0.50, 0.20),  # poison - 毒绿
	9: Color(0.40, 0.35, 0.25),  # bridge - 棕色
}

# 高亮颜色
const MOVE_RANGE_COLOR = Color(0.13, 0.59, 0.95, 0.35)
const ATTACK_RANGE_COLOR = Color(0.96, 0.26, 0.21, 0.35)
const DANGER_ZONE_COLOR = Color(1.0, 0.62, 0.0, 0.4)
const SELECTED_COLOR = Color(0.0, 1.0, 0.0, 0.3)
const OVERWATCH_COLOR = Color(0.50, 0.20, 0.80, 0.3)

# 掩体指示
const HALF_COVER_COLOR = Color(1.0, 0.98, 0.77, 0.6)
const FULL_COVER_COLOR = Color(0.98, 0.75, 0.10, 0.6)

# UI 颜色
const BG_DARK = Color(0.06, 0.07, 0.09, 1)
const BG_PANEL = Color(0.10, 0.11, 0.13, 0.95)
const TEXT_PRIMARY = Color(0.95, 0.95, 0.95)
const TEXT_SECONDARY = Color(0.65, 0.65, 0.65)
const ACCENT = Color(0.13, 0.59, 0.95)

# 状态颜色
const HP_FULL = Color(0.30, 0.85, 0.30)
const HP_HALF = Color(1.0, 0.75, 0.03)
const HP_LOW = Color(0.96, 0.26, 0.21)

# 稀有度颜色
const RARITY_COLORS = {
	"common": Color(0.80, 0.80, 0.80),
	"uncommon": Color(0.30, 0.85, 0.30),
	"rare": Color(0.13, 0.59, 0.95),
	"epic": Color(0.69, 0.35, 0.95),
	"legendary": Color(1.0, 0.75, 0.03),
}

## 获取地形颜色
static func get_terrain_color(terrain_id: int) -> Color:
	return TERRAIN_COLORS.get(terrain_id, Color.GRAY)

## 获取稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

## 获取 HP 颜色
static func get_hp_color(current: int, max_val: int) -> Color:
	var ratio = float(current) / float(max_val)
	if ratio > 0.5:
		return HP_FULL
	elif ratio > 0.25:
		return HP_HALF
	else:
		return HP_LOW
