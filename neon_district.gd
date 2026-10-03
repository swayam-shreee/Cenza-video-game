extends ParallaxBackdrop
class_name NeonDistrictBackdrop
## Neon District stage art: a rain-soaked cyberpunk megacity at night. Two skyline
## layers with lit windows and neon signs, a holographic billboard, an elevated
## rail line, flying traffic, fog and rain, and the tower the fight happens on.
## Drawn in parallax layers (see backdrop.gd). draw_platform() styles the stage.

const SKY_TOP := Color(0.02, 0.02, 0.06)
const SKY_MID := Color(0.08, 0.04, 0.14)
const SMOG := Color(0.36, 0.11, 0.27)
const SMOG_LOW := Color(0.52, 0.22, 0.24)
const FAR_BLD := Color(0.09, 0.07, 0.15)
const MID_BLD := Color(0.045, 0.04, 0.08)
const NEAR_BLD := Color(0.03, 0.03, 0.05)
const CYAN := Color(0.20, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.20, 0.70)
const AMBER := Color(1.0, 0.70, 0.25)
const NEONS := [CYAN, MAGENTA, AMBER]

const DECK := Color(0.19, 0.20, 0.24)
const DECK_DARK := Color(0.10, 0.10, 0.13)
const DECK_EDGE := Color(0.40, 0.42, 0.48)
const HAZARD := Color(0.85, 0.68, 0.12)

var _far: Array = []    # {r: Rect2, windows: Array[Vector2], antenna: bool}
var _mid: Array = []    # {r: Rect2, sign: Dictionary or {}}
var _rain: Array = []
var _cars: Array = []


func _ready() -> void:
	super._ready()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	var x := -900.0
	while x < 2200.0:
		var w := rng.randf_range(34.0, 90.0)
		var h := rng.randf_range(110.0, 330.0)
		var r := Rect2(x, 560.0 - h, w, h + 1200.0)
		var wins: Array = []
		for i in int(h / 9.0):
			if rng.randf() < 0.35:
				wins.append(Vector2(x + rng.randf_range(4.0, w - 6.0), 560.0 - h + 8.0 + i * 9.0))
		_far.append({"r": r, "windows": wins, "antenna": h > 260.0})
		x += w + rng.randf_range(0.0, 14.0)
	x = -1100.0
	while x < 2500.0:
		var w := rng.randf_range(80.0, 170.0)
		var h := rng.randf_range(220.0, 520.0)
		var r := Rect2(x, 700.0 - h, w, h + 1200.0)
		var sign := {}
		if rng.randf() < 0.55:
			sign = {"x": x + rng.randf_range(10.0, w - 26.0), "y": 700.0 - h + rng.randf_range(30.0, 110.0),
					"h": rng.randf_range(60.0, 150.0), "col": NEONS[rng.randi() % NEONS.size()],
					"phase": rng.randf() * 10.0}
		var lit: Array = []
		for i in 26:
			if rng.randf() < 0.3:
				lit.append(Vector2(x + rng.randf_range(6.0, w - 10.0), 700.0 - h + rng.randf_range(20.0, h)))
		_mid.append({"r": r, "sign": sign, "lit": lit})
		x += w + rng.randf_range(20.0, 70.0)
	for i in 140:
		_rain.append(Vector3(rng.randf_range(0.0, 1500.0), rng.randf_range(0.0, 900.0), rng.randf_range(0.7, 1.3)))
	for i in 6:
		_cars.append({"lane": rng.randf_range(160.0, 360.0), "speed": rng.randf_range(90.0, 220.0) * (1 if i % 2 == 0 else -1),
				"x": rng.randf_range(0.0, 3200.0)})


func _draw() -> void:
	layer(0.0)
	gradient(Rect2(-40, -40, 1360, 380), SKY_TOP, SKY_MID)
	gradient(Rect2(-40, 340, 1360, 460), SKY_MID, SMOG)

	# Far skyline.
	layer(0.12)
	for b in _far:
		draw_rect(b["r"], FAR_BLD)
		for w in b["windows"]:
			draw_rect(Rect2(w, Vector2(2, 3)), Color(1.0, 0.78, 0.5, 0.45))
		if b["antenna"]:
			var r: Rect2 = b["r"]
			var top := Vector2(r.position.x + r.size.x * 0.5, r.position.y)
			draw_line(top, top - Vector2(0, 26), FAR_BLD, 2.0)
			if fmod(t + r.position.x * 0.01, 2.0) < 1.0:
				draw_circle(top - Vector2(0, 27), 2.0, Color(1, 0.15, 0.1))
	_fog(560.0, 140.0, SMOG, 0.55)

	# Mid skyline with neon signs, the billboard and the rail line.
	layer(0.38)
	for b in _mid:
		draw_rect(b["r"], MID_BLD)
		for w in b["lit"]:
			draw_rect(Rect2(w, Vector2(3, 4)), Color(0.55, 0.85, 1.0, 0.35))
	_billboard(Vector2(470, 300), Vector2(240, 130))
	for b in _mid:
		if not b["sign"].is_empty():
			_neon_sign(b["sign"])
	_rail(0.38)
	_fog(700.0, 160.0, SMOG_LOW, 0.4)

	# Flying traffic.
	layer(0.55)
	for c in _cars:
		var cx := fmod(c["x"] + t * c["speed"], 3600.0) - 1200.0
		var going_right: bool = c["speed"] > 0.0
		var head := Color(1, 0.95, 0.85) if going_right else Color(1, 0.2, 0.15)
		draw_rect(Rect2(cx - 14, c["lane"] - 3, 28, 7), Color(0.05, 0.05, 0.08))
		draw_circle(Vector2(cx + (14 if going_right else -14), c["lane"]), 2.2, head)
		draw_circle(Vector2(cx + (14 if going_right else -14), c["lane"]), 7.0, Color(head, 0.15))

	# The building under the rooftop, and the clutter on the roof.
	layer(1.0)
	_tower_below()
	_roof_clutter()
	_fog(820.0, 220.0, Color(0.20, 0.08, 0.20), 0.6)

	# Rain over everything behind the fighters.
	layer(0.0)
	_draw_rain()
	draw_set_transform(Vector2.ZERO)


# ===========================================================================
# PIECES
# ===========================================================================
func _fog(y: float, h: float, col: Color, alpha: float) -> void:
	gradient(Rect2(-1400, y - h, 4200, h), Color(col, 0.0), Color(col, alpha))
	gradient(Rect2(-1400, y, 4200, h * 2.0), Color(col, alpha), Color(col, 0.0))


func _flicker(phase: float) -> float:
	## Mostly on, with the occasional stutter that real neon has.
	var k := fmod(t * 1.3 + phase, 7.0)
	if k > 6.55 and fmod(t * 23.0, 1.0) < 0.5:
		return 0.25
	return 1.0


func _neon_sign(s: Dictionary) -> void:
	var col: Color = s["col"]
	var on := _flicker(s["phase"])
	var r := Rect2(s["x"], s["y"], 16.0, s["h"])
	draw_rect(r.grow(8.0), Color(col, 0.08 * on))
	draw_rect(r.grow(3.0), Color(col, 0.18 * on))
	draw_rect(r, Color(0.04, 0.03, 0.06))
	draw_rect(r, Color(col, 0.9 * on), false, 2.0)
	# Glyph strokes suggesting lettering.
	var y := r.position.y + 8.0
	var i := 0
	while y < r.end.y - 10.0:
		var w := 8.0 if i % 2 == 0 else 5.0
		draw_line(Vector2(r.position.x + 8.0 - w * 0.5, y), Vector2(r.position.x + 8.0 + w * 0.5, y), Color(col, on), 2.0)
		draw_line(Vector2(r.position.x + 8.0, y), Vector2(r.position.x + 8.0, y + 6.0), Color(col, on * 0.8), 1.5)
		y += 14.0
		i += 1


func _billboard(pos: Vector2, size: Vector2) -> void:
	## A holographic ad: translucent gradient panel, scanlines, occasional glitch.
	var glitch := fmod(t, 4.3) > 4.1
	var r := Rect2(pos, size)
	draw_rect(Rect2(pos.x + size.x * 0.5 - 4, pos.y + size.y, 8, 400), MID_BLD)
	draw_rect(r.grow(10.0), Color(CYAN, 0.05))
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([Color(CYAN, 0.32), Color(MAGENTA, 0.32), Color(MAGENTA, 0.22), Color(CYAN, 0.22)]))
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var shift := 0.0
		if glitch and row % 5 == 2:
			shift = sin(t * 90.0 + row) * 14.0
		draw_line(Vector2(r.position.x + shift, y), Vector2(r.end.x + shift, y), Color(1, 1, 1, 0.06), 1.0)
		y += 4.0
		row += 1
	# Abstract ad: a logo ring and text bars.
	var c := r.position + Vector2(size.x * 0.27, size.y * 0.5)
	var off := Vector2(10, 0) if glitch else Vector2.ZERO
	draw_arc(c + off, 28.0, 0.0, TAU, 32, Color(CYAN, 0.85), 3.0, true)
	draw_arc(c + off, 16.0, t * 1.5, t * 1.5 + 4.0, 24, Color(MAGENTA, 0.85), 3.0, true)
	for i in 3:
		var bw: float = [96.0, 70.0, 84.0][i]
		draw_rect(Rect2(r.position.x + size.x * 0.5 + off.x, r.position.y + 34.0 + i * 22.0, bw, 8.0),
				Color(1.0, 0.85, 0.95, 0.55))
	draw_rect(r, Color(CYAN, 0.6), false, 1.5)


func _rail(_d: float) -> void:
	## Elevated rail with a train that passes now and then.
	var y := 460.0
	draw_rect(Rect2(-1400, y, 4200, 10), Color(0.06, 0.06, 0.09))
	var x := -1400.0
	while x < 2800.0:
		draw_rect(Rect2(x, y + 10, 10, 600), Color(0.05, 0.05, 0.08))
		x += 220.0
	var tx := fmod(t * 520.0, 9000.0) - 2500.0
	if tx < 2600.0:
		draw_rect(Rect2(tx, y - 22, 420, 22), Color(0.12, 0.12, 0.17))
		var wx := tx + 10.0
		while wx < tx + 410.0:
			draw_rect(Rect2(wx, y - 17, 14, 7), Color(1.0, 0.85, 0.55, 0.8))
			wx += 22.0
		draw_line(Vector2(tx, y - 1), Vector2(tx + 420, y - 1), Color(CYAN, 0.7), 1.5)


func _tower_below() -> void:
	## The skyscraper whose roof is the main platform.
	var mb: Rect2 = stage.get("main_bounds", Rect2(65, 508, 1150, 44))
	var r := Rect2(mb.position.x + 30.0, mb.end.y - 2.0, mb.size.x - 60.0, 1400.0)
	draw_rect(r, NEAR_BLD)
	# Window grid, a few lit.
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var y := r.position.y + 26.0
	while y < r.position.y + 700.0:
		var x := r.position.x + 18.0
		while x < r.end.x - 24.0:
			var lit := rng.randf() < 0.18
			draw_rect(Rect2(x, y, 16, 10), Color(1.0, 0.8, 0.55, 0.55) if lit else Color(0.08, 0.09, 0.13))
			x += 30.0
		y += 26.0
	# Vertical neon strips on the corners.
	for sx in [r.position.x + 6.0, r.end.x - 9.0]:
		draw_rect(Rect2(sx - 6, r.position.y, 15, 900), Color(MAGENTA, 0.08))
		draw_rect(Rect2(sx, r.position.y, 3, 900), Color(MAGENTA, 0.85 * _flicker(sx)))


func _roof_clutter() -> void:
	## AC units, vents, a water tank and an antenna mast sitting on the roof.
	var mb: Rect2 = stage.get("main_bounds", Rect2(65, 508, 1150, 44))
	var roof := mb.position.y
	var unit := Color(0.14, 0.15, 0.18)
	var edge := Color(0.28, 0.30, 0.35)
	for u in [[mb.position.x + 70.0, 46.0, 30.0], [mb.position.x + 130.0, 34.0, 24.0], [mb.end.x - 210.0, 52.0, 34.0]]:
		var r := Rect2(u[0], roof - u[2], u[1], u[2])
		draw_rect(r, unit)
		draw_rect(r, edge, false, 1.0)
		draw_circle(r.get_center(), u[2] * 0.32, Color(0.08, 0.08, 0.1))
		draw_line(r.get_center() + Vector2.from_angle(t * 6.0) * u[2] * 0.3,
				r.get_center() - Vector2.from_angle(t * 6.0) * u[2] * 0.3, edge, 1.5)
	# Water tank on legs.
	var tx := mb.end.x - 110.0
	draw_rect(Rect2(tx, roof - 92, 54, 62), Color(0.16, 0.13, 0.12))
	draw_rect(Rect2(tx - 3, roof - 96, 60, 6), Color(0.22, 0.18, 0.16))
	for lx in [tx + 6.0, tx + 44.0]:
		draw_line(Vector2(lx, roof - 30), Vector2(lx, roof), Color(0.12, 0.12, 0.14), 3.0)
	# Antenna mast with a blinking light.
	var ax := mb.position.x + 260.0
	draw_line(Vector2(ax, roof), Vector2(ax, roof - 150), Color(0.20, 0.21, 0.25), 3.0)
	for k in 5:
		var yy := roof - 20.0 - k * 26.0
		draw_line(Vector2(ax - 8 + k, yy), Vector2(ax + 8 - k, yy), Color(0.20, 0.21, 0.25), 1.5)
	if fmod(t, 1.4) < 0.7:
		draw_circle(Vector2(ax, roof - 152), 3.0, Color(1, 0.15, 0.1))
		draw_circle(Vector2(ax, roof - 152), 9.0, Color(1, 0.15, 0.1, 0.18))


func _draw_rain() -> void:
	for d in _rain:
		var x := fmod(d.x - t * 140.0 * d.z, 1500.0) - 100.0
		var y := fmod(d.y + t * 900.0 * d.z, 900.0) - 90.0
		draw_line(Vector2(x, y), Vector2(x - 4.0 * d.z, y + 18.0 * d.z), Color(0.65, 0.75, 1.0, 0.22), 1.0)


# ===========================================================================
# PLATFORMS
# ===========================================================================
static func draw_platform(ci: CanvasItem, size: Vector2, one_way: bool) -> void:
	## Draws one platform centered on the origin of `ci`.
	var h := size / 2.0
	if one_way:
		_catwalk(ci, h, NEONS[int(size.x) % NEONS.size()])
	else:
		_rooftop(ci, h)


static func _rooftop(ci: CanvasItem, h: Vector2) -> void:
	ci.draw_polygon(PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y),
	]), PackedColorArray([DECK, DECK, DECK_DARK, DECK_DARK]))
	ci.draw_rect(Rect2(-h.x, -h.y, h.x * 2.0, 2.0), DECK_EDGE)
	# Panel seams.
	var x := -h.x + 64.0
	while x < h.x:
		ci.draw_line(Vector2(x, -h.y + 2.0), Vector2(x, h.y), Color(0.05, 0.05, 0.07, 0.8), 1.0)
		x += 64.0
	# Hazard stripes at both ends.
	for sx in [-1.0, 1.0]:
		var x0: float = -h.x if sx < 0 else h.x - 48.0
		ci.draw_rect(Rect2(x0, -h.y + 2.0, 48.0, 8.0), Color(0.08, 0.08, 0.08))
		for k in 6:
			var px := x0 + k * 9.0
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(px, -h.y + 10.0), Vector2(px + 4.0, -h.y + 2.0),
				Vector2(px + 8.0, -h.y + 2.0), Vector2(px + 4.0, -h.y + 10.0),
			]), HAZARD)
	# Cyan underglow strip.
	ci.draw_rect(Rect2(-h.x, h.y - 4.0, h.x * 2.0, 2.0), CYAN)
	for k in 4:
		ci.draw_rect(Rect2(-h.x, h.y - 2.0 + k * 3.0, h.x * 2.0, 3.0), Color(CYAN, 0.16 - k * 0.035))


static func _catwalk(ci: CanvasItem, h: Vector2, neon: Color) -> void:
	ci.draw_rect(Rect2(-h.x, -h.y, h.x * 2.0, h.y * 2.0), Color(0.13, 0.14, 0.17))
	# Grating.
	var x := -h.x + 4.0
	while x < h.x - 4.0:
		ci.draw_line(Vector2(x, -h.y + 3.0), Vector2(x + 6.0, h.y - 2.0), Color(0.06, 0.06, 0.08), 1.0)
		x += 7.0
	ci.draw_rect(Rect2(-h.x, -h.y, h.x * 2.0, 2.0), Color(0.36, 0.38, 0.44))
	# Neon edge with a soft glow.
	ci.draw_rect(Rect2(-h.x, h.y - 2.0, h.x * 2.0, 2.0), neon)
	ci.draw_rect(Rect2(-h.x, h.y, h.x * 2.0, 6.0), Color(neon, 0.14))
	# Struts.
	for sx in [-1.0, 1.0]:
		var bx: float = sx * (h.x - 14.0)
		ci.draw_line(Vector2(bx, h.y), Vector2(bx - sx * 18.0, h.y + 22.0), Color(0.10, 0.10, 0.13), 3.0)
