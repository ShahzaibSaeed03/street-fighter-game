extends CharacterBody2D
## Guard.gd — a dungeon guard with a vision cone, hearing, an awareness meter and melee chase.
##
## PATROL  -> walks its route (or scans left/right if it has no route)
## SUSPECT -> noticed something ("?"): walks to where it saw / heard you and looks around
## CHASE   -> spotted you ("!"): runs at you, alerts nearby guards, hits on contact
## Unaware guards can be killed instantly from behind (backstab). Walls and crates block sight.
## Created by Dungeon.gd: call configure() BEFORE add_child().

signal died(guard: Node2D, stealth: bool)

const Fx := preload("res://Fx.gd")
const ArtScript := preload("res://EnemyArt.gd")
const HEART_DROP_CHANCE := 0.25
const CreatureScript := preload("res://CreatureArt.gd")
const ProjScript := preload("res://Projectile.gd")
const LootScript := preload("res://Loot.gd")
const WALL_MASK := 4
const SIGHT_MASK := 12      # walls + props block sight

enum S { PATROL, SUSPECT, CHASE, DEAD }

var waypoints: Array[Vector2] = []
var tier: int = 0
var is_boss: bool = false
var kind: String = "grunt"          # grunt | archer | brute | flyer | boss
var species: String = "ghoul"
var flies: bool = false
var is_minion: bool = false
var coin_value: int = 5
var summon_kind: String = ""
var _summon_timer: float = 8.0
var _retreat: float = 0.0
var ranged: bool = false
var blind_time: float = 0.0         # blinder: seconds of blindness per bolt
var shot_damage: int = 10
var shoot_cd: float = 1.8
var keep_dist: float = 240.0
var burst_count: int = 0
var _shot_timer: float = 1.0
var _burst_timer: float = 2.5
var start_facing: float = 0.0

var max_health: int = 40
var health: int = 40
var contact_damage: int = 12
var contact_cooldown: float = 1.0
var patrol_speed: float = 70.0
var suspect_speed: float = 105.0
var chase_speed: float = 175.0
var view_range: float = 290.0
var view_half_angle: float = 0.62        # radians (~36 degrees each side)

var state: int = S.PATROL
var awareness: float = 0.0
var facing_angle: float = 0.0

var art: Node2D
var _player: Node2D
var _wp: int = 0
var _wait: float = 0.0
var _t: float = randf() * 10.0
var _last_known: Vector2 = Vector2.ZERO
var _lost_timer: float = 0.0
var _suspect_timer: float = 0.0
var _look_phase: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _contact_timer: float = 0.0
var _cone: PackedVector2Array = PackedVector2Array()
var _flash_tween: Tween
var _dying: bool = false


## Call before add_child().
func configure(points: Array[Vector2], new_tier: int, boss: bool = false, facing: float = 0.0) -> void:
	waypoints = points
	tier = new_tier
	is_boss = boss
	start_facing = facing
	facing_angle = facing
	if boss:
		max_health = 240
		contact_damage = 18
		chase_speed = 150.0
		view_range = 340.0
	health = max_health


## Call after configure(), before add_child(). mods: hp / dmg / view / spd multipliers, coin value,
## the level's species roster and boss stats.
func apply_kind(new_kind: String, mods: Dictionary) -> void:
	kind = new_kind
	var hp_m: float = float(mods.get("hp", 1.0))
	var dmg_m: float = float(mods.get("dmg", 1.0))
	var view_m: float = float(mods.get("view", 1.0))
	var spd_m: float = float(mods.get("spd", 1.0))
	coin_value = int(mods.get("coin", 5))
	var roster: Dictionary = mods.get("roster", {})
	var entry: Array = roster.get(kind, ["ghoul", 0])
	species = String(entry[0])
	tier = int(entry[1])
	if kind == "boss":
		var b: Dictionary = mods["boss"]
		max_health = int(b["hp"])
		contact_damage = int(b["dmg"])
		chase_speed = float(b["speed"])
		view_range = 340.0 * view_m
		burst_count = int(b["burst"])
		summon_kind = String(b.get("summon", ""))
		shot_damage = int(float(b["dmg"]) * 0.55)
		health = max_health
		return
	if kind == "archer":
		max_health = 28
		contact_damage = 8
		ranged = true
		view_range = 340.0
		patrol_speed = 65.0
		chase_speed = 150.0
		shot_damage = 10
	elif kind == "brute":
		max_health = 110
		contact_damage = 22
		patrol_speed = 55.0
		suspect_speed = 85.0
		chase_speed = 150.0
		view_range = 250.0
		view_half_angle = 0.8
		coin_value *= 3
	elif kind == "shield":
		max_health = 75
		contact_damage = 16
		patrol_speed = 48.0
		suspect_speed = 78.0
		chase_speed = 125.0
		view_range = 250.0
		view_half_angle = 0.75
		coin_value *= 2
	elif kind == "blinder":
		ranged = true
		max_health = 30
		contact_damage = 8
		patrol_speed = 60.0
		suspect_speed = 90.0
		chase_speed = 140.0
		view_range = 330.0
		view_half_angle = 0.6
		shot_damage = 6
		shoot_cd = 2.2
		blind_time = 2.5
		coin_value = int(round(float(coin_value) * 1.5))
	elif kind == "hound":
		max_health = 18
		contact_damage = 10
		patrol_speed = 130.0
		suspect_speed = 175.0
		chase_speed = 255.0
		view_range = 380.0
		view_half_angle = 0.7
		coin_value = int(round(float(coin_value) * 0.8))
	elif kind == "flyer":
		flies = true
		max_health = 14
		contact_damage = 8
		patrol_speed = 95.0
		suspect_speed = 140.0
		chase_speed = 215.0
		view_range = 300.0
		view_half_angle = 0.9
		coin_value = int(round(float(coin_value) * 1.2))
	max_health = int(round(float(max_health) * hp_m))
	health = max_health
	contact_damage = int(round(float(contact_damage) * dmg_m))
	shot_damage = int(round(float(shot_damage) * dmg_m))
	view_range *= view_m
	patrol_speed *= spd_m
	suspect_speed *= spd_m
	chase_speed *= spd_m


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = WALL_MASK if flies else 12
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 1
	material = Fx.unshaded_material()   # the vision cone stays visible in the dark

	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0 if is_boss else (24.0 if kind == "brute" else 20.0)
	cs.shape = circle
	cs.name = "CollisionShape2D"
	add_child(cs)

	art = Node2D.new()
	if species == "ghoul":
		art.set_script(ArtScript)
	else:
		art.set_script(CreatureScript)
		art.set("species", species)
	add_child(art)
	art.setup(tier)
	art.aim_angle = facing_angle
	if is_boss:
		art.scale = Vector2(1.5, 1.5)
	elif kind == "brute":
		art.scale = Vector2(1.3, 1.3)
	elif kind == "archer":
		art.scale = Vector2(0.92, 0.92)
	elif kind == "shield":
		art.scale = Vector2(1.15, 1.15)
	elif kind == "hound":
		art.scale = Vector2(0.9, 0.9)

	_player = get_tree().get_first_node_in_group("player") as Node2D
	if waypoints.size() > 0:
		_last_known = waypoints[0]


# ------------------------------------------------------------------ senses
func _player_alive() -> bool:
	return is_instance_valid(_player) and not bool(_player.is_dead)


func _ray_clear(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to, SIGHT_MASK)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _can_see_player() -> bool:
	if not _player_alive():
		return false
	var to: Vector2 = _player.global_position - global_position
	var dist: float = to.length()
	var rng: float = view_range
	if bool(_player.is_sneaking) and kind != "hound":   # hounds sniff out sneaking players
		rng *= 0.55
	var half: float = view_half_angle
	if state == S.CHASE:
		rng *= 1.5
		half = PI * 0.85
	if dist > rng:
		return false
	if absf(angle_difference(facing_angle, to.angle())) > half:
		return false
	return _ray_clear(_player.global_position)


func _update_awareness(delta: float) -> void:
	if not _player_alive():
		awareness = maxf(awareness - delta * 0.5, 0.0)
		return
	var dist: float = global_position.distance_to(_player.global_position)
	if _can_see_player():
		var closeness: float = 1.0 - clampf(dist / view_range, 0.0, 1.0)
		awareness += delta * (0.9 + closeness * 2.8)
		_last_known = _player.global_position
		_lost_timer = 0.0
	elif dist < float(_player.noise_radius()):
		# heard something: gets curious, but only seeing you can trigger a chase
		awareness = minf(awareness + delta * 0.9, 0.7)
		_last_known = _player.global_position
	else:
		awareness = maxf(awareness - delta * 0.3, 0.0)
	awareness = clampf(awareness, 0.0, 1.0)


# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	_t += delta
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	_update_awareness(delta)

	if awareness >= 1.0 and state != S.CHASE and _player_alive():
		_start_chase()
	elif state == S.PATROL and awareness >= 0.3:
		state = S.SUSPECT
		_suspect_timer = 4.0
		_look_phase = 0.0

	var desired_vel: Vector2 = Vector2.ZERO
	match state:
		S.PATROL:
			desired_vel = _do_patrol(delta)
		S.SUSPECT:
			desired_vel = _do_suspect(delta)
		S.CHASE:
			desired_vel = _do_chase(delta)

	velocity = desired_vel + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 1800.0 * delta)
	move_and_slide()

	art.aim_angle = facing_angle
	_build_cone()
	queue_redraw()


func _turn_toward(angle: float, delta: float, rate: float = 7.0) -> void:
	facing_angle = lerp_angle(facing_angle, angle, minf(1.0, delta * rate))


func _do_patrol(delta: float) -> Vector2:
	if waypoints.size() < 2:
		if flies and waypoints.size() == 1:
			var orbit: Vector2 = waypoints[0] + Vector2.from_angle(_t * 1.1) * 70.0 - global_position
			if orbit.length() > 4.0:
				_turn_toward(orbit.angle(), delta, 6.0)
			return orbit.limit_length(patrol_speed)
		facing_angle = start_facing + sin(_t * 0.7) * 0.95   # stationary: scan left and right
		return Vector2.ZERO
	if _wait > 0.0:
		_wait -= delta
		_turn_toward(facing_angle + sin(_t * 2.0) * 0.4, delta, 3.0)
		return Vector2.ZERO
	var target: Vector2 = waypoints[_wp]
	var to: Vector2 = target - global_position
	if to.length() < 10.0:
		_wp = (_wp + 1) % waypoints.size()
		_wait = 1.1
		return Vector2.ZERO
	_turn_toward(to.angle(), delta)
	return to.normalized() * patrol_speed


func _do_suspect(delta: float) -> Vector2:
	_suspect_timer -= delta
	if awareness < 0.08 or _suspect_timer <= 0.0:
		state = S.PATROL
		return Vector2.ZERO
	var to: Vector2 = _last_known - global_position
	if to.length() > 26.0:
		_turn_toward(to.angle(), delta, 9.0)
		return to.normalized() * suspect_speed
	_look_phase += delta
	facing_angle += sin(_look_phase * 3.0) * 1.8 * delta   # look around
	return Vector2.ZERO


func _do_chase(delta: float) -> Vector2:
	if not _player_alive():
		state = S.PATROL
		return Vector2.ZERO
	var seen: bool = _can_see_player()
	if seen:
		_lost_timer = 0.0
	else:
		_lost_timer += delta
		if _lost_timer > 3.0:
			state = S.SUSPECT
			awareness = 0.5
			_suspect_timer = 4.0
			return Vector2.ZERO
	var target: Vector2 = _player.global_position if seen else _last_known
	var to: Vector2 = target - global_position
	_turn_toward(to.angle(), delta, 10.0)
	var pdist: float = global_position.distance_to(_player.global_position)
	if flies:
		_retreat = maxf(_retreat - delta, 0.0)
		if _retreat > 0.0:
			return -to.normalized() * chase_speed * 0.8
		if pdist <= 42.0 and _contact_timer <= 0.0:
			if _player.take_damage(contact_damage):
				_contact_timer = contact_cooldown
				_retreat = 0.8
		var side: Vector2 = to.orthogonal().normalized() * sin(_t * 5.0) * 0.7
		return (to.normalized() + side).normalized() * chase_speed
	if seen:
		_shot_timer -= delta
		_burst_timer -= delta
		if ranged:
			return _do_ranged(to, pdist)
		if is_boss and burst_count > 0:
			_boss_attacks()
	# contact damage (dodging through = no damage and no cooldown)
	if _contact_timer <= 0.0 and global_position.distance_to(_player.global_position) <= (52.0 if is_boss else 44.0):
		if _player.take_damage(contact_damage):
			_contact_timer = contact_cooldown
	if to.length() < 6.0:
		return Vector2.ZERO
	return to.normalized() * chase_speed


func _do_ranged(to: Vector2, dist: float) -> Vector2:
	var move: Vector2 = Vector2.ZERO
	if dist > keep_dist + 40.0:
		move = to.normalized() * chase_speed
	elif dist < keep_dist - 70.0:
		move = -to.normalized() * chase_speed * 0.85
	if _shot_timer <= 0.0:
		_shot_timer = shoot_cd
		_fire(to.angle(), 370.0, shot_damage)
	if dist < 42.0 and _contact_timer <= 0.0:
		if _player.take_damage(contact_damage):
			_contact_timer = contact_cooldown
	return move


func _boss_attacks() -> void:
	_summon_timer -= get_physics_process_delta_time()
	if summon_kind != "" and _summon_timer <= 0.0:
		_summon_timer = 11.0
		get_tree().call_group("arena", "spawn_minions", global_position, summon_kind, 2)
		get_tree().call_group("game_manager", "toast", "The boss summons minions!")
	var ratio: float = float(health) / float(max_health)
	var enraged: bool = ratio <= 0.5
	if _burst_timer <= 0.0:
		_burst_timer = 2.1 if enraged else 3.4
		var n: int = burst_count + (4 if enraged else 0)
		var off: float = randf() * TAU
		for i in n:
			_fire(off + TAU * float(i) / float(n), 235.0, shot_damage)
		get_tree().call_group("game_manager", "shake", 5.0)
		Audio.play("gate", -6.0, 0.1)
	if _shot_timer <= 0.0:
		_shot_timer = 1.1 if enraged else 1.7
		var base: float = (_player.global_position - global_position).angle()
		for a in [-0.2, 0.0, 0.2]:
			_fire(base + float(a), 330.0, shot_damage)


func _fire(angle: float, speed: float, dmg: int) -> void:
	var p = ProjScript.new()
	p.velocity = Vector2.from_angle(angle) * speed
	p.damage = dmg
	p.position = global_position + Vector2.from_angle(angle) * 26.0
	p.color = art.eye_color()
	p.blind = blind_time
	get_tree().current_scene.add_child(p)
	Audio.play("click", -8.0, 0.15)


func force_chase() -> void:
	if _player_alive() and state != S.DEAD and state != S.CHASE:
		_start_chase()


func _start_chase() -> void:
	_shot_timer = 0.8
	_burst_timer = 1.6
	state = S.CHASE
	awareness = 1.0
	_lost_timer = 0.0
	_last_known = _player.global_position
	Audio.play("alert", -3.0, 0.05)
	get_tree().call_group("game_manager", "on_alert")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.has_method("hear_alert") \
				and global_position.distance_to(e.global_position) < 430.0:
			e.hear_alert(_player.global_position)


## A thrown decoy rattled nearby: walk over and check the spot (not a full alarm).
func hear_noise(pos: Vector2) -> void:
	if state == S.DEAD or state == S.CHASE:
		return
	_last_known = pos
	awareness = maxf(awareness, 0.6)
	state = S.SUSPECT
	_suspect_timer = 4.0


## Another guard shouted: go and look where the player was.
func hear_alert(pos: Vector2) -> void:
	if state == S.DEAD or state == S.CHASE:
		return
	_last_known = pos
	awareness = maxf(awareness, 0.65)
	state = S.SUSPECT
	_suspect_timer = 5.0


# ------------------------------------------------------------------ vision cone
func _build_cone() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var space := get_world_2d().direct_space_state
	var steps: int = 14
	var half: float = view_half_angle
	for i in steps + 1:
		var a: float = facing_angle - half + (2.0 * half) * float(i) / float(steps)
		var end: Vector2 = global_position + Vector2.from_angle(a) * view_range
		var q := PhysicsRayQueryParameters2D.create(global_position, end, SIGHT_MASK)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			pts.append(end - global_position)
		else:
			pts.append(Vector2(hit["position"]) - global_position)
	_cone = pts


func _draw() -> void:
	if state == S.DEAD:
		return
	if _cone.size() >= 3 and state != S.CHASE:
		var col: Color = Color(1.0, 0.95, 0.55, 0.12)
		if state == S.SUSPECT:
			col = Color(1.0, 0.7, 0.2, 0.2)
		draw_colored_polygon(_cone, col)
	if kind == "shield":
		draw_arc(Vector2.ZERO, 24.0, facing_angle - 1.1, facing_angle + 1.1, 14, Color(0.7, 0.75, 0.85, 0.9), 4.0)
	if kind == "archer":
		var bd: Vector2 = Vector2.from_angle(facing_angle)
		draw_arc(bd * 20.0, 17.0, facing_angle - 1.0, facing_angle + 1.0, 10, Color(0.75, 0.6, 0.35), 3.0)
		draw_line(bd * 20.0 + Vector2.from_angle(facing_angle - 1.0) * 17.0, bd * 20.0 + Vector2.from_angle(facing_angle + 1.0) * 17.0, Color(0.9, 0.9, 0.9, 0.7), 1.0)
	elif kind == "brute":
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 24, Color(0.78, 0.8, 0.9, 0.55), 3.0)
	var top: float = -58.0 if is_boss else -46.0
	if awareness > 0.03 and state != S.CHASE:
		draw_rect(Rect2(Vector2(-18.0, top), Vector2(36.0, 5.0)), Color(0, 0, 0, 0.6))
		var fill: Color = Color(1.0, 0.85, 0.2) if awareness < 0.6 else Color(1.0, 0.45, 0.1)
		draw_rect(Rect2(Vector2(-17.0, top + 1.0), Vector2(34.0 * awareness, 3.0)), fill)
	var font: Font = ThemeDB.fallback_font
	if state == S.SUSPECT:
		draw_string(font, Vector2(-6.0, top - 4.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color(1.0, 0.85, 0.2))
	elif state == S.CHASE:
		draw_string(font, Vector2(-5.0, top - 4.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color(1.0, 0.2, 0.15))


# ------------------------------------------------------------------ taking damage
## True when the player is close and behind an unaware guard.
func can_backstab(from_pos: Vector2) -> bool:
	if state == S.DEAD or state == S.CHASE or is_boss:
		return false
	var to_player: Vector2 = from_pos - global_position
	if to_player.length() > 85.0:
		return false
	return absf(angle_difference(facing_angle, to_player.angle())) > 1.9


func backstab(from_pos: Vector2) -> void:
	if state == S.DEAD:
		return
	if kind == "brute":
		get_tree().call_group("game_manager", "toast", "Heavy stab!")
		take_damage(70, from_pos, 380.0)
		return
	var dir: Vector2 = (global_position - from_pos).normalized()
	get_tree().call_group("game_manager", "toast", "Silent takedown!")
	Audio.play("hit", -1.0)
	_die(get_tree().current_scene, dir, true)


## Called by Player when the sword connects (same signature the old Enemy used).
func take_damage(amount: int, from_position: Vector2, knockback_force: float) -> void:
	if _dying:
		return
	# Shieldbearers block anything coming from the front. Hit them from the side or behind.
	if kind == "shield" and absf(angle_difference(facing_angle, (from_position - global_position).angle())) < 1.1:
		if Progression.has_perk("shield_breaker"):
			amount = maxi(1, int(amount / 2))
		else:
			Audio.play("click", -4.0, 0.2)
			Fx.burst(get_tree().current_scene, global_position, Color(1.6, 1.6, 1.8), 6, 200.0, 0.2, 2.0, 30.0, (global_position - from_position).normalized(), true)
			return
	health -= amount
	var dir: Vector2 = (global_position - from_position).normalized()
	_knockback = dir * knockback_force
	_flash_white()
	art.pulse = 1.0
	var root := get_tree().current_scene
	Fx.burst(root, global_position, Color(2.2, 1.7, 0.8), 9, 280.0, 0.25, 2.5, 35.0, dir, true)
	Fx.burst(root, global_position, art.blood_color(), 10, 170.0, 0.5, 4.0, 55.0, dir)
	Fx.damage_number(root, global_position, amount)
	Audio.play("hit", -2.0)
	if health <= 0:
		_die(root, dir, false)
		return
	if state != S.CHASE and _player_alive():
		_start_chase()


func _die(root: Node, dir: Vector2, stealth: bool) -> void:
	_dying = true
	state = S.DEAD
	_cone = PackedVector2Array()
	queue_redraw()
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	art.modulate = Color.WHITE
	remove_from_group("enemies")
	$CollisionShape2D.set_deferred("disabled", true)
	died.emit(self, stealth)

	Audio.play("enemy_death", -2.0)
	Fx.burst(root, global_position, art.blood_color(), 22, 240.0, 0.7, 5.0, 180.0, dir)
	var arena := get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("add_splat"):
		arena.add_splat(global_position, art.blood_color())

	_drop_loot(root)
	if not is_boss and randf() < HEART_DROP_CHANCE:
		var heart := Node2D.new()
		heart.set_script(preload("res://Pickup.gd"))
		heart.position = global_position
		root.call_deferred("add_child", heart)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(art, "scale", art.scale * Vector2(1.35, 0.35), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(art, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)


func _drop_loot(root: Node) -> void:
	var count: int = 1
	var each: int = coin_value
	if is_boss:
		count = 14
		each = coin_value * 2
	elif randf() < 0.35:
		count = 2
	for i in count:
		var l = LootScript.new()
		l.kind = "coin"
		l.value = each
		l.persistent = false
		l.position = global_position
		l.scatter = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 190.0)
		root.call_deferred("add_child", l)
	if not is_boss and randf() < 0.2:
		var a = LootScript.new()
		a.kind = "arrows"
		a.value = 5
		a.persistent = false
		a.position = global_position
		a.scatter = Vector2.from_angle(randf() * TAU) * 90.0
		root.call_deferred("add_child", a)


func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	art.modulate = Color(3.0, 3.0, 3.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(art, "modulate", Color.WHITE, 0.14)
