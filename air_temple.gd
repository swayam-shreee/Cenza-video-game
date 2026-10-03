extends ParallaxBackdrop
class_name AirTempleBackdrop
## Air Temple stage art: a dusk mountain range, a temple on a distant peak and a
## sea of mist below the courtyard. Drawn in parallax layers (see backdrop.gd).
## draw_platform() styles the stage's platforms to match.

const SKY_TOP := Color(0.12, 0.16, 0.26)
const SKY_MID := Color(0.33, 0.37, 0.48)
const HORIZON := Color(0.84, 0.60, 0.42)
const HAZE := Color(0.72, 0.58, 0.52)
const SUN := Color(1.0, 0.82, 0.60)

const RIDGES := [
	# seed, depth, base y, amplitude, color
	[11, 0.06, 420.0, 120.0, Color(0.55, 0.53, 0.60)],
	[23, 0.14, 470.0, 150.0, Color(0.42, 0.42, 0.51)],
	[37, 0.26, 540.0, 160.0, Color(0.31, 0.32, 0.41)],
]

const STONE := Color(0.55, 0.52, 0.50)
const STONE_LIT := Color(0.68, 0.61, 0.54)
const STONE_SHADE := Color(0.39, 0.38, 0.41)
const ROOF := Color(0.21, 0.28, 0.39)
const ROOF_LIT := Color(0.33, 0.38, 0.48)
const RUST := Color(0.50, 0.31, 0.21)
const WINDOW_GLOW := Color(1.0, 0.72, 0.40)
const RIM := Color(0.95, 0.76, 0.56, 0.5)

const PLAT_STONE := Color(0.56, 0.53, 0.49)
const PLAT_STONE_DARK := Color(0.33, 0.31, 0.31)
const PLAT_CAP := Color(0.68, 0.64, 0.58)
const BRONZE := Color(0.52, 0.40, 0.25)
const TIMBER := Color(0.29, 0.21, 0.15)
const TIMBER_TOP := Color(0.42, 0.31, 0.22)
const IRON := Color(0.17, 0.17, 0.19)
const BANNER := Color(0.20, 0.27, 0.38)

var _ridges: Array = []  # [PackedVector2Array, depth, color, base, amp]
var _motes: Array = []


func _ready() -> void:
	super._ready()
	for r in RIDGES:
		_ridges.append([ridge(r[0], -900.0, 2200.0, r[2], r[3]), r[1], r[4], r[2], r[3]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 45:
		_motes.append(Vector3(rng.randf_range(0, 2800), rng.randf_range(-200, 900), rng.randf_range(0.5, 1.5)))


func _draw() -> void:
	# Sky, fixed to the screen.
	layer(0.0)
	gradient(Rect2(-40, -40, 1360, 420), SKY_TOP, SKY_MID)
	gradient(Rect2(-40, 380, 1360, 420), SKY_MID, HORIZON)
	# Low sun: many faint layers so the glow falls off smoothly instead of banding.
	var sun := Vector2(985, 395)
	for i in 24:
		var f := float(i) / 23.0
		draw_circle(sun, lerpf(320.0, 34.0, f), Color(SUN, 0.022 + 0.01 * f))
	draw_circle(sun, 30.0, Color(1.0, 0.9, 0.75, 0.85))

	# Mountain ridges, far to near, each with haze settling over the one behind.
	for i in _ridges.size():
		var r: Array = _ridges[i]
		layer(r[1])
		draw_colored_polygon(filled_below(r[0], 1700.0), r[2])
		_snow(r[0], r[3], r[4])
		_mist_band(float(r[3]) + 40.0, 160.0, 0.28)

	# The temple on its peak.
	layer(0.45)
	_temple()
	_mist_band(470.0, 200.0, 0.35)
	_wisps(0.55, 380.0, 6.0, 0.08)

	# The rock column under the courtyard, then the sea of mist below it.
	layer(1.0)
	_pillar()
	layer(0.9)
	gradient(Rect2(-1200, 600, 3700, 220), Color(HAZE, 0.0), Color(HAZE, 0.75))
	gradient(Rect2(-1200, 820, 3700, 900), Color(HAZE, 0.75), Color(0.62, 0.52, 0.50, 0.95))
	_wisps(0.9, 640.0, 10.0, 0.12)
	_drift_motes()
	draw_set_transform(Vector2.ZERO)


# ===========================================================================
# PIECES
# ===========================================================================
func _snow(line: PackedVector2Array, base: float, amp: float) -> void:
	## Pale highlights on the highest peaks of a ridge.
	for k in range(1, line.size() - 1):
		var p := line[k]
		if p.y < line[k - 1].y and p.y < line[k + 1].y and p.y < base - amp * 0.35:
			# Upper edge follows the ridge; lower edge sits below it, tapering to the sides.
			var lo := maxi(k - 3, 0)
			var hi := mini(k + 3, line.size() - 1)
			var cap := PackedVector2Array()
			for j in range(lo, hi + 1):
				cap.append(line[j])
			for j in range(hi, lo - 1, -1):
				var depth := 16.0 * (1.0 - absf(j - k) / 3.5)
				cap.append(line[j] + Vector2(0, depth))
			draw_colored_polygon(cap, Color(0.86, 0.82, 0.80, 0.5))


func _mist_band(y: float, h: float, alpha: float) -> void:
	gradient(Rect2(-1200, y - h, 3700, h), Color(HAZE, 0.0), Color(HAZE, alpha))
	gradient(Rect2(-1200, y, 3700, h), Color(HAZE, alpha), Color(HAZE, 0.0))


func _wisps(seed_scale: float, y: float, speed: float, alpha: float) -> void:
	## Long, thin, slow-moving streaks of cloud.
	for i in 7:
		var x := fmod(i * 520.0 * seed_scale + t * speed * (1.0 + i * 0.15), 3400.0) - 1200.0
		var yy := y + sin(i * 1.9) * 70.0
		draw_colored_polygon(ellipse(Vector2(x, yy), Vector2(260.0 + i * 25.0, 14.0 + (i % 3) * 5.0), 24),
				Color(0.92, 0.84, 0.80, alpha))


func _drift_motes() -> void:
	for m in _motes:
		var x := fmod(m.x + t * 14.0 * m.z, 2800.0) - 800.0
		var y: float = m.y + sin(t * 0.6 + m.x) * 12.0
		draw_circle(Vector2(x, y), m.z, Color(1.0, 0.93, 0.85, 0.28))


func _temple() -> void:
	# Its peak, lit from the right by the setting sun.
	var peak := PackedVector2Array([
		Vector2(250, 1700), Vector2(430, 520), Vector2(505, 410), Vector2(548, 372),
		Vector2(566, 338), Vector2(716, 338), Vector2(744, 380), Vector2(800, 440),
		Vector2(890, 600), Vector2(1050, 1700),
	])
	_shaded(peak, Color(0.25, 0.26, 0.34), Color(0.52, 0.45, 0.47), 340.0, 900.0)
	_shaded(PackedVector2Array([
		Vector2(716, 338), Vector2(744, 380), Vector2(800, 440), Vector2(890, 600),
		Vector2(1050, 1700), Vector2(760, 1700), Vector2(720, 450),
	]), Color(0.38, 0.34, 0.38), Color(0.60, 0.50, 0.49), 340.0, 900.0)
	# Terraces stepping down the slope.
	for i in 4:
		var y := 352.0 + i * 16.0
		draw_line(Vector2(548 - i * 12, y), Vector2(730 + i * 10, y), Color(0.20, 0.21, 0.27), 2.0)

	# Curtain wall.
	draw_rect(Rect2(572, 300, 140, 38), STONE)
	draw_rect(Rect2(660, 300, 52, 38), STONE_LIT)
	draw_rect(Rect2(572, 298, 140, 3), RUST)

	# Towers: far pair, near pair, then the tall central one.
	_tower(570.0, 262.0, 300.0, 16.0, 34.0)
	_tower(714.0, 262.0, 300.0, 16.0, 34.0)
	_tower(600.0, 238.0, 300.0, 24.0, 48.0)
	_tower(684.0, 238.0, 300.0, 24.0, 48.0)
	_tower(642.0, 188.0, 300.0, 36.0, 76.0)
	draw_line(Vector2(642, 112), Vector2(642, 98), Color(0.70, 0.58, 0.36), 1.5)
	draw_circle(Vector2(642, 97), 2.0, Color(0.75, 0.62, 0.38))


func _tower(cx: float, top: float, bottom: float, width: float, roof_h: float) -> void:
	var half := width * 0.5
	draw_rect(Rect2(cx - half, top, width, bottom - top), STONE_SHADE)
	draw_rect(Rect2(cx, top, half, bottom - top), STONE_LIT)
	draw_line(Vector2(cx + half, top), Vector2(cx + half, bottom), RIM, 1.0)
	# A couple of warm-lit windows.
	var y := top + 14.0
	while y < bottom - 12.0:
		draw_circle(Vector2(cx, y + 2.0), width * 0.22, Color(WINDOW_GLOW, 0.12))
		draw_rect(Rect2(cx - 1.5, y, 3.0, 5.0), WINDOW_GLOW)
		y += 30.0
	# Steep roof with slightly concave sides; the right face catches the sun.
	var eave := half + 6.0
	var apex := Vector2(cx, top - roof_h)
	var left_side := PackedVector2Array()
	var right_side := PackedVector2Array()
	for i in 9:
		var s := float(i) / 8.0
		left_side.append(_quad(Vector2(cx - eave, top + 2.0), Vector2(cx - eave * 0.3, top - roof_h * 0.3), apex, s))
		right_side.append(_quad(apex, Vector2(cx + eave * 0.3, top - roof_h * 0.3), Vector2(cx + eave, top + 2.0), s))
	var left_face := left_side.duplicate()
	left_face.append(Vector2(cx, top + 2.0))
	var right_face := right_side.duplicate()
	right_face.append(Vector2(cx, top + 2.0))
	draw_colored_polygon(left_face, ROOF)
	draw_colored_polygon(right_face, ROOF_LIT)
	draw_polyline(right_side, RIM, 1.0, true)
	draw_rect(Rect2(cx - eave, top, eave * 2.0, 2.5), RUST)


func _pillar() -> void:
	## Weathered rock column under the main courtyard, fading into the mist.
	var mb: Rect2 = stage.get("main_bounds", Rect2(40, 500, 1200, 40))
	var x0 := mb.position.x
	var x1 := mb.end.x
	var y0 := mb.end.y - 2.0
	var w := x1 - x0
	var rock := PackedVector2Array([
		Vector2(x0 + 14, y0), Vector2(x1 - 14, y0), Vector2(x1 - w * 0.06, y0 + 70),
		Vector2(x1 - w * 0.13, y0 + 170), Vector2(x1 - w * 0.2, y0 + 900),
		Vector2(x0 + w * 0.22, y0 + 900), Vector2(x0 + w * 0.12, y0 + 170), Vector2(x0 + w * 0.05, y0 + 70),
	])
	draw_colored_polygon(rock, Color(0.25, 0.24, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x1 - w * 0.3, y0), Vector2(x1 - 14, y0), Vector2(x1 - w * 0.06, y0 + 70),
		Vector2(x1 - w * 0.13, y0 + 170), Vector2(x1 - w * 0.2, y0 + 900), Vector2(x1 - w * 0.36, y0 + 900),
	]), Color(0.33, 0.30, 0.31))
	# Strata.
	for i in 6:
		var yy := y0 + 30.0 + i * 34.0
		var inset := w * (0.05 + i * 0.02)
		draw_line(Vector2(x0 + inset, yy), Vector2(x1 - inset, yy + (i % 2) * 6.0), Color(0.18, 0.17, 0.21, 0.7), 2.0)


func _shaded(poly: PackedVector2Array, top: Color, bottom: Color, y0: float, y1: float) -> void:
	## Fill with a vertical fade into the haze, so distant rock doesn't look flat.
	var cols := PackedColorArray()
	for v in poly:
		cols.append(top.lerp(bottom, clampf((v.y - y0) / (y1 - y0), 0.0, 1.0)))
	draw_polygon(poly, cols)


static func _quad(a: Vector2, c: Vector2, b: Vector2, s: float) -> Vector2:
	return a.lerp(c, s).lerp(c.lerp(b, s), s)


# ===========================================================================
# PLATFORMS
# ===========================================================================
static func draw_platform(ci: CanvasItem, size: Vector2, one_way: bool) -> void:
	## Draws one platform centered on the origin of `ci`.
	var h := size / 2.0
	if one_way:
		_timber_platform(ci, h)
	else:
		_stone_platform(ci, h)


static func _stone_platform(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_polygon(PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y),
	]), PackedColorArray([PLAT_STONE, PLAT_STONE, PLAT_STONE_DARK, PLAT_STONE_DARK]))
	ci.draw_rect(Rect2(-h.x, -h.y, h.x * 2.0, 5.0), PLAT_CAP)
	ci.draw_rect(Rect2(-h.x, -h.y + 5.0, h.x * 2.0, 2.0), BRONZE)
	# Offset block seams.
	var seam := Color(0.22, 0.21, 0.22, 0.45)
	var mid := (-h.y + 7.0 + h.y) * 0.5
	ci.draw_line(Vector2(-h.x, mid), Vector2(h.x, mid), seam, 1.0)
	var x := -h.x + 56.0
	var row := 0
	while x < h.x:
		ci.draw_line(Vector2(x, -h.y + 7.0), Vector2(x, mid), seam, 1.0)
		ci.draw_line(Vector2(x - 28.0, mid), Vector2(x - 28.0, h.y), seam, 1.0)
		# Worn chips along the edge.
		if row % 3 == 1:
			ci.draw_rect(Rect2(x - 14.0, -h.y, 9.0, 2.0), Color(0.42, 0.40, 0.38))
		x += 56.0
		row += 1
	ci.draw_rect(Rect2(-h.x, h.y - 2.0, h.x * 2.0, 2.0), Color(0.15, 0.14, 0.16, 0.8))
	_engraving(ci, Vector2(0, (mid + h.y) * 0.5), 6.0, Color(0.20, 0.19, 0.21, 0.35))


static func _timber_platform(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_rect(Rect2(-h.x, -h.y, h.x * 2.0, h.y * 2.0), TIMBER)
	ci.draw_rect(Rect2(-h.x, -h.y, h.x * 2.0, 2.0), TIMBER_TOP)
	var x := -h.x + 26.0
	while x < h.x:
		ci.draw_line(Vector2(x, -h.y + 2.0), Vector2(x, h.y), Color(0.16, 0.11, 0.08), 1.0)
		x += 26.0
	# Iron knee braces.
	for sx in [-1.0, 1.0]:
		var bx: float = sx * (h.x - 12.0)
		ci.draw_line(Vector2(bx, h.y), Vector2(bx - sx * 16.0, h.y + 16.0), IRON, 2.5)
		ci.draw_line(Vector2(bx - sx * 16.0, h.y), Vector2(bx - sx * 16.0, h.y + 16.0), IRON, 2.0)
	# A small faded banner.
	ci.draw_rect(Rect2(-6, h.y, 12, 20), BANNER)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-6, h.y + 20), Vector2(6, h.y + 20), Vector2(0, h.y + 25),
	]), BANNER)
	ci.draw_rect(Rect2(-6, h.y, 12, 2), RUST)


static func _engraving(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	## A faint carved Air Nomad mark: a ring with three curls.
	ci.draw_arc(c, r, 0.0, TAU, 24, col, 1.2, true)
	for k in 3:
		var a := k * TAU / 3.0 - PI * 0.5
		var pts := PackedVector2Array()
		for i in 8:
			var s := float(i) / 7.0
			pts.append(c + Vector2.from_angle(a + s * 2.2) * r * (0.15 + 0.65 * s))
		ci.draw_polyline(pts, col, 1.0, true)
