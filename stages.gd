extends Node
class_name Stages
## Map data. Adding a new map means adding one entry to get_all() -- no other
## script changes. Units are pixels; the camera follows the fighters and zooms
## out to fit them, so a stage can be much wider than the 1280x720 window.
##
## FIELDS
##   name          shown on the stage select screen
##   blurb         one line of description
##   bg            background color
##   blast_zone    leave this rectangle and you lose a stock
##   main_bounds   the big platform the CPU treats as "safe ground" when recovering
##   spawns        four start positions
##   platforms     list of {pos, size, one_way, color}
##                 one_way platforms can be jumped up through and dropped down from
##   camera_limits optional; the camera never shows outside this rectangle.
##                 Defaults to the blast zone shrunk by 150 on every side.
##   theme         optional art set: "air_temple" (air_temple.gd) or
##                 "neon_district" (neon_district.gd). No theme = plain colored blocks

const SOLID := Color(0.35, 0.40, 0.55)
const THIN := Color(0.50, 0.60, 0.75)
const AIR_TEMPLE := 4  # index in get_all(); the default map on the setup page


static func plat(pos: Vector2, size: Vector2, one_way: bool = false, color: Color = SOLID) -> Dictionary:
	return {"pos": pos, "size": size, "one_way": one_way, "color": color}


static func get_all() -> Array:
	return [battlefield(), flat_zone(), twin_towers(), skyline(), air_temple(), neon_district()]


static func get_by_index(i: int) -> Dictionary:
	var all := get_all()
	return all[clampi(i, 0, all.size() - 1)]


static func count() -> int:
	return get_all().size()


static func camera_limits(stage: Dictionary) -> Rect2:
	var bz: Rect2 = stage.get("blast_zone", Rect2(-600, -480, 2480, 1500))
	return stage.get("camera_limits", bz.grow(-150.0))


# ---------------------------------------------------------------------------
static func battlefield() -> Dictionary:
	## The original layout, widened. Big middle platform, three thin ones above.
	return {
		"name": "Battlefield",
		"blurb": "Big center stage with three float platforms. Good all-rounder.",
		"bg": Color(0.09, 0.10, 0.16),
		"blast_zone": Rect2(-620, -480, 2520, 1500),
		"main_bounds": Rect2(80, 500, 1120, 40),
		"spawns": [Vector2(380, 300), Vector2(900, 300), Vector2(560, 160), Vector2(720, 160)],
		"platforms": [
			plat(Vector2(640, 520), Vector2(1120, 40)),
			plat(Vector2(320, 385), Vector2(320, 16), true, THIN),
			plat(Vector2(960, 385), Vector2(320, 16), true, THIN),
			plat(Vector2(640, 255), Vector2(260, 16), true, THIN),
		],
	}


# ---------------------------------------------------------------------------
static func flat_zone() -> Dictionary:
	## One long platform, nothing to hide behind. Pure fighting.
	return {
		"name": "Flat Zone",
		"blurb": "One long platform, nowhere to run. Favors heavy hitters.",
		"bg": Color(0.13, 0.11, 0.14),
		"blast_zone": Rect2(-720, -480, 2720, 1500),
		"main_bounds": Rect2(-15, 520, 1310, 44),
		"spawns": [Vector2(220, 380), Vector2(1060, 380), Vector2(480, 380), Vector2(800, 380)],
		"platforms": [
			plat(Vector2(640, 542), Vector2(1310, 44), false, Color(0.42, 0.34, 0.40)),
		],
	}


# ---------------------------------------------------------------------------
static func twin_towers() -> Dictionary:
	## Two raised platforms with a gap in the middle. Fall in and you have to climb out.
	return {
		"name": "Twin Towers",
		"blurb": "Two towers over a gap. Miss the ledge and you're in trouble.",
		"bg": Color(0.10, 0.13, 0.18),
		"blast_zone": Rect2(-800, -480, 2880, 1550),
		"main_bounds": Rect2(-100, 470, 480, 36),
		"spawns": [Vector2(140, 320), Vector2(1140, 320), Vector2(640, 300), Vector2(640, 180)],
		"platforms": [
			plat(Vector2(140, 488), Vector2(480, 36), false, Color(0.33, 0.42, 0.52)),
			plat(Vector2(1140, 488), Vector2(480, 36), false, Color(0.33, 0.42, 0.52)),
			plat(Vector2(640, 560), Vector2(350, 20), true, THIN),
			plat(Vector2(640, 360), Vector2(290, 16), true, THIN),
			plat(Vector2(140, 300), Vector2(240, 16), true, THIN),
			plat(Vector2(1140, 300), Vector2(240, 16), true, THIN),
		],
	}


# ---------------------------------------------------------------------------
static func skyline() -> Dictionary:
	## Scattered small platforms, no safe ground. Rewards good recovery.
	return {
		"name": "Skyline",
		"blurb": "Scattered platforms, no safe ground. Recovery tools matter here.",
		"bg": Color(0.08, 0.12, 0.15),
		"blast_zone": Rect2(-780, -500, 2840, 1560),
		"main_bounds": Rect2(415, 540, 450, 24),
		"spawns": [Vector2(256, 330), Vector2(1024, 330), Vector2(640, 420), Vector2(640, 200)],
		"platforms": [
			plat(Vector2(640, 552), Vector2(450, 24), false, Color(0.30, 0.44, 0.48)),
			plat(Vector2(144, 440), Vector2(270, 16), true, THIN),
			plat(Vector2(1136, 440), Vector2(270, 16), true, THIN),
			plat(Vector2(400, 320), Vector2(240, 16), true, THIN),
			plat(Vector2(880, 320), Vector2(240, 16), true, THIN),
			plat(Vector2(640, 210), Vector2(220, 16), true, THIN),
			plat(Vector2(-112, 330), Vector2(190, 16), true, THIN),
			plat(Vector2(1392, 330), Vector2(190, 16), true, THIN),
		],
	}


# ---------------------------------------------------------------------------
static func air_temple() -> Dictionary:
	## A temple courtyard high in the mountains: three timber balconies, two
	## stone ledges and a lookout at the top.
	return {
		"name": "Air Temple",
		"blurb": "A mountain courtyard above the clouds. Balconies, ledges and a lookout.",
		"theme": "air_temple",
		"bg": Color(0.16, 0.20, 0.30),
		"blast_zone": Rect2(-660, -520, 2600, 1560),
		"main_bounds": Rect2(40, 500, 1200, 40),
		"spawns": [Vector2(330, 300), Vector2(950, 300), Vector2(520, 160), Vector2(760, 160)],
		"platforms": [
			plat(Vector2(640, 520), Vector2(1200, 40)),
			plat(Vector2(250, 390), Vector2(220, 16), true, THIN),
			plat(Vector2(640, 390), Vector2(200, 16), true, THIN),
			plat(Vector2(1030, 390), Vector2(220, 16), true, THIN),
			plat(Vector2(445, 265), Vector2(200, 16), true, THIN),
			plat(Vector2(835, 265), Vector2(200, 16), true, THIN),
			plat(Vector2(640, 140), Vector2(160, 16), true, THIN),
		],
	}


# ---------------------------------------------------------------------------
static func neon_district() -> Dictionary:
	## A rain-soaked rooftop in a cyberpunk megacity, with catwalks and billboard
	## ledges stepping up unevenly above it.
	return {
		"name": "Neon District",
		"blurb": "A rooftop in a rain-soaked megacity. Catwalks and billboard ledges.",
		"theme": "neon_district",
		"bg": Color(0.04, 0.03, 0.08),
		"blast_zone": Rect2(-640, -520, 2560, 1580),
		"main_bounds": Rect2(65, 508, 1150, 44),
		"spawns": [Vector2(300, 320), Vector2(930, 300), Vector2(560, 180), Vector2(1060, 160)],
		"platforms": [
			plat(Vector2(640, 530), Vector2(1150, 44)),
			plat(Vector2(300, 400), Vector2(240, 16), true, THIN),
			plat(Vector2(930, 385), Vector2(260, 16), true, THIN),
			plat(Vector2(180, 255), Vector2(170, 16), true, THIN),
			plat(Vector2(560, 270), Vector2(200, 16), true, THIN),
			plat(Vector2(1060, 250), Vector2(180, 16), true, THIN),
			plat(Vector2(800, 140), Vector2(170, 16), true, THIN),
		],
	}
