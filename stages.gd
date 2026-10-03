extends Node
class_name Stages
## Map data. Adding a new map means adding one entry to get_all() -- no other
## script changes. Everything is in screen pixels on a 1280x720 view.
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

const SOLID := Color(0.35, 0.40, 0.55)
const THIN := Color(0.50, 0.60, 0.75)


static func plat(pos: Vector2, size: Vector2, one_way: bool = false, color: Color = SOLID) -> Dictionary:
	return {"pos": pos, "size": size, "one_way": one_way, "color": color}


static func get_all() -> Array:
	return [battlefield(), flat_zone(), twin_towers(), skyline()]


static func get_by_index(i: int) -> Dictionary:
	var all := get_all()
	return all[clampi(i, 0, all.size() - 1)]


static func count() -> int:
	return get_all().size()


# ---------------------------------------------------------------------------
static func battlefield() -> Dictionary:
	## The original layout. Big middle platform, three thin ones above.
	return {
		"name": "Battlefield",
		"blurb": "Big center stage with three float platforms. Good all-rounder.",
		"bg": Color(0.09, 0.10, 0.16),
		"blast_zone": Rect2(-200, -250, 1680, 1170),
		"main_bounds": Rect2(290, 500, 700, 40),
		"spawns": [Vector2(430, 300), Vector2(850, 300), Vector2(560, 180), Vector2(720, 180)],
		"platforms": [
			plat(Vector2(640, 520), Vector2(700, 40)),
			plat(Vector2(440, 380), Vector2(200, 16), true, THIN),
			plat(Vector2(840, 380), Vector2(200, 16), true, THIN),
			plat(Vector2(640, 250), Vector2(160, 16), true, THIN),
		],
	}


# ---------------------------------------------------------------------------
static func flat_zone() -> Dictionary:
	## One long platform, nothing to hide behind. Pure fighting.
	return {
		"name": "Flat Zone",
		"blurb": "One long platform, nowhere to run. Favors heavy hitters.",
		"bg": Color(0.13, 0.11, 0.14),
		"blast_zone": Rect2(-240, -250, 1760, 1170),
		"main_bounds": Rect2(230, 520, 820, 44),
		"spawns": [Vector2(380, 380), Vector2(900, 380), Vector2(540, 380), Vector2(740, 380)],
		"platforms": [
			plat(Vector2(640, 542), Vector2(820, 44), false, Color(0.42, 0.34, 0.40)),
		],
	}


# ---------------------------------------------------------------------------
static func twin_towers() -> Dictionary:
	## Two raised platforms with a gap in the middle. Fall in and you have to climb out.
	return {
		"name": "Twin Towers",
		"blurb": "Two towers over a gap. Miss the ledge and you're in trouble.",
		"bg": Color(0.10, 0.13, 0.18),
		"blast_zone": Rect2(-200, -250, 1680, 1220),
		"main_bounds": Rect2(180, 470, 300, 36),
		"spawns": [Vector2(300, 320), Vector2(980, 320), Vector2(640, 300), Vector2(640, 180)],
		"platforms": [
			plat(Vector2(330, 488), Vector2(300, 36), false, Color(0.33, 0.42, 0.52)),
			plat(Vector2(950, 488), Vector2(300, 36), false, Color(0.33, 0.42, 0.52)),
			plat(Vector2(640, 560), Vector2(220, 20), true, THIN),
			plat(Vector2(640, 360), Vector2(180, 16), true, THIN),
			plat(Vector2(330, 300), Vector2(150, 16), true, THIN),
			plat(Vector2(950, 300), Vector2(150, 16), true, THIN),
		],
	}


# ---------------------------------------------------------------------------
static func skyline() -> Dictionary:
	## Scattered small platforms, no safe ground. Rewards good recovery.
	return {
		"name": "Skyline",
		"blurb": "Scattered platforms, no safe ground. Recovery tools matter here.",
		"bg": Color(0.08, 0.12, 0.15),
		"blast_zone": Rect2(-220, -280, 1720, 1240),
		"main_bounds": Rect2(500, 540, 280, 24),
		"spawns": [Vector2(400, 330), Vector2(880, 330), Vector2(640, 420), Vector2(640, 200)],
		"platforms": [
			plat(Vector2(640, 552), Vector2(280, 24), false, Color(0.30, 0.44, 0.48)),
			plat(Vector2(330, 440), Vector2(170, 16), true, THIN),
			plat(Vector2(950, 440), Vector2(170, 16), true, THIN),
			plat(Vector2(490, 320), Vector2(150, 16), true, THIN),
			plat(Vector2(790, 320), Vector2(150, 16), true, THIN),
			plat(Vector2(640, 210), Vector2(140, 16), true, THIN),
			plat(Vector2(170, 330), Vector2(120, 16), true, THIN),
			plat(Vector2(1110, 330), Vector2(120, 16), true, THIN),
		],
	}
