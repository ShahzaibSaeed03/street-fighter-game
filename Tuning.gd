class_name Tuning
extends RefCounted
## Tuning.gd - phone / tablet settings in one place.
## Phones get: a camera that follows the hero, a little zoom and the SPEED setting below.
## Desktop keeps the original room-by-room camera.
## Set FORCE_MOBILE to true to try the phone setup on a PC (also shows the touch controls).

const SaveScript := preload("res://Save.gd")

const FORCE_MOBILE := false

## Game speed the player picks on the main menu (index = Save.speed_pref).
## Multiplies hero AND guard movement, so the game keeps the same balance at any speed.
const SPEED_NAMES: Array[String] = ["SLOW", "NORMAL", "FAST"]
const SPEED_MOBILE: Array[float] = [0.62, 0.82, 1.0]
const SPEED_DESKTOP: Array[float] = [0.8, 1.0, 1.2]

## Camera zoom on phones (1.0 = same as desktop, higher = closer).
const MOBILE_ZOOM := 1.2


static func mobile() -> bool:
	return FORCE_MOBILE or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


static func move_scale() -> float:
	SaveScript.ensure()
	var i: int = clampi(SaveScript.speed_pref, 0, 2)
	return SPEED_MOBILE[i] if mobile() else SPEED_DESKTOP[i]


## The dodge roll is slowed only half as much so it still clears a guard's reach.
static func dodge_scale() -> float:
	return lerpf(1.0, move_scale(), 0.5)


static func follow_camera() -> bool:
	return mobile()


static func camera_zoom() -> float:
	return MOBILE_ZOOM if mobile() else 1.0
