extends CharacterBody2D
## Player.gd — top-down hack & slash hero.
## WASD / Arrows = move, C / Ctrl = sneak, Space = sword (stealth kill from behind), Shift = dodge roll.
## Visuals live in HeroArt.gd; this script handles gameplay + feedback (sound, particles, light).

signal health_changed(current: int, maximum: int)
signal player_died

const Fx := preload("res://Fx.gd")
const ItemsScript := preload("res://Items.gd")
const SaveScript := preload("res://Save.gd")
const ArrowScript := preload("res://Arrow.gd")
const DecoyScript := preload("res://Decoy.gd")

# ---------- Tunable stats ----------
@export var speed: float = 250.0
@export var sneak_speed: float = 105.0
@export var max_health: int = 100
@export var attack_damage: int = 16
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 0.35
@export var dodge_duration: float = 0.15
@export var dodge_cooldown: float = 1.0
@export var dodge_speed: float = 700.0      # 0.15s * 700 = ~105px roll
@export var knockback_force: float = 450.0  # applied to enemies we hit

const ENEMY_RADIUS := 20.0                  # matches the enemy CircleShape2D
const BODY_RADIUS := 20.0
const SWING_TIME := 0.22                    # length of the sword-swing animation
const LIGHT_BASE := 1.15

# ---------- Runtime state ----------
var health: int = 100
var is_dead: bool = false
var is_dodging: bool = false
var facing: Vector2 = Vector2.RIGHT
var is_sneaking: bool = false
var keys: Array[String] = []
var dmg_taken_mult: float = 1.0
var speed_mult: float = 1.0
var noise_mult: float = 1.0
var slow_timer: float = 0.0          # >0 while stuck in quicksand
var blind_timer: float = 0.0         # >0 after a blinder's flash: slower, no bow
var invulnerable: float = 0.0        # >0 right after a revive: ignores damage
var bow: Dictionary = {}
var ammo: int = 0
var max_ammo: int = 0
var arrow_mult: float = 1.0
var _shoot_timer: float = 0.0
var _reticle: Node2D
var _auto_target: Node2D = null      # touch aim assist: the enemy the bow would hit right now
var _assist_timer: float = 0.0
const ASSIST_RANGE := 680.0
const ASSIST_CONE := 0.5             # radians (about 29 degrees) the aim stick may be off and still lock on
var _noise_boost: float = 0.0
var _moving: bool = false

var _attack_timer: float = 0.0       # time until next attack allowed
var _swing_time: float = -1.0        # <0 = not swinging
var _dodge_time_left: float = 0.0    # remaining roll time
var _dodge_cd_timer: float = 0.0     # time until next roll allowed
var _dodge_dir: Vector2 = Vector2.RIGHT
var _step_timer: float = 0.0
var decoys: int = 3                  # noise decoys left this level
var _decoy_was_down: bool = false
var _flash_tween: Tween
var _light: PointLight2D

@onready var art: Node2D = $Art


func _ready() -> void:
	add_to_group("player")  # also set in the scene; harmless duplicate
	collision_layer = 1
	collision_mask = 12     # walls + closed doors (4) and props (8)
	_apply_loadout()
	if Progression.has_perk("iron_skin"):
		max_health += 25
	health = max_health

	# Warm light that follows the hero (the arena is dark, so this is what you see by)
	_light = PointLight2D.new()
	_light.texture = Fx.light_texture()
	_light.texture_scale = 1.6
	_light.color = Color(1.0, 0.88, 0.70)
	_light.energy = LIGHT_BASE
	_light.height = 60.0
	add_child(_light)

	_reticle = Node2D.new()
	_reticle.top_level = true
	_reticle.z_index = 40
	_reticle.material = Fx.unshaded_material()
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)

	health_changed.emit(health, max_health)


## Reads the equipped sword / suit / bow and the vitality upgrade from the save file.
func _apply_loadout() -> void:
	SaveScript.ensure()
	var sword: Dictionary = ItemsScript.find("sword", String(SaveScript.equipped["sword"]))
	var suit: Dictionary = ItemsScript.find("suit", String(SaveScript.equipped["suit"]))
	bow = ItemsScript.find("bow", String(SaveScript.equipped["bow"]))
	attack_damage = int(sword["dmg"])
	attack_cooldown = float(sword["cd"])
	attack_range = float(sword["range"])
	var hero: Dictionary = ItemsScript.find("hero", String(SaveScript.equipped["hero"]))
	dmg_taken_mult = float(suit["dmg"]) * float(hero["dmg"])
	speed_mult = float(suit["spd"]) * float(hero["speed"])
	noise_mult = float(suit["noise"])
	max_health = 100 + ItemsScript.VITALITY_HP * int(SaveScript.vitality) + int(hero["hp"])
	max_ammo = int(bow["ammo"]) + int(hero["arrows"])
	arrow_mult = float(hero["arrow_mult"])
	ammo = max_ammo
	art.apply_loadout(suit, sword, bow)
	art.apply_hero(hero)


func add_ammo(n: int) -> int:
	var before: int = ammo
	ammo = mini(ammo + n, max_ammo)
	return ammo - before


func _draw_reticle() -> void:
	if is_dead:
		return
	_reticle.global_position = Vector2.ZERO
	var col := Color(1.0, 0.9, 0.5, 0.75) if ammo > 0 else Color(1.0, 0.3, 0.3, 0.6)
	if _touch_mode():
		# Touch: a dashed aim line while the stick is held, and a ring on the enemy that will be hit.
		var tp: Vector2 = Vector2.ZERO
		var has_t: bool = is_instance_valid(_auto_target)
		if has_t:
			tp = _auto_target.global_position
		if TouchControls.aim_active:
			var end: Vector2 = tp if has_t else global_position + TouchControls.aim_dir * 260.0
			var seg: Vector2 = end - global_position
			var n: int = int(seg.length() / 22.0)
			for i in n:
				var a: Vector2 = global_position + seg.normalized() * (30.0 + float(i) * 22.0)
				_reticle.draw_line(a, a + seg.normalized() * 11.0, Color(col, 0.55), 2.2)
		if has_t and ammo > 0:
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
			_reticle.draw_arc(tp, 24.0 + pulse * 3.0, 0.0, TAU, 28, Color(1.0, 0.35, 0.3, 0.9), 2.4)
			_reticle.draw_arc(tp, 13.0, 0.0, TAU, 20, Color(1.0, 0.8, 0.4, 0.8), 1.6)
			_reticle.draw_circle(tp, 2.4, Color(1.0, 0.85, 0.5, 0.95))
		return
	var m: Vector2 = get_global_mouse_position()
	_reticle.draw_arc(m, 11.0, 0.0, TAU, 20, col, 1.6)
	_reticle.draw_circle(m, 1.8, col)
	var d: Vector2 = (m - global_position)
	if d.length() > 40.0:
		_reticle.draw_line(global_position + d.normalized() * 34.0, global_position + d.normalized() * minf(d.length() - 14.0, 150.0), Color(col, 0.22), 1.4)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_reticle.queue_redraw()
	slow_timer = maxf(slow_timer - delta, 0.0)
	blind_timer = maxf(blind_timer - delta, 0.0)
	invulnerable = maxf(invulnerable - delta, 0.0)
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)

	# Tick timers
	_noise_boost = maxf(_noise_boost - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_dodge_cd_timer = maxf(_dodge_cd_timer - delta, 0.0)
	if _swing_time >= 0.0:
		_swing_time += delta
		if _swing_time >= SWING_TIME:
			_swing_time = -1.0

	_assist_timer -= delta
	if _assist_timer <= 0.0 or TouchControls.aim_active:
		_assist_timer = 0.08
		_update_assist()
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()

	if is_dodging:
		_dodge_time_left -= delta
		velocity = _dodge_dir * dodge_speed * Tuning.dodge_scale()
		if _dodge_time_left <= 0.0:
			_end_dodge()
	else:
		is_sneaking = Input.is_action_pressed("sneak")
		var spd_k: float = speed_mult * (0.45 if slow_timer > 0.0 else 1.0) * (0.6 if blind_timer > 0.0 else 1.0)
		velocity = input_dir * (sneak_speed if is_sneaking else speed) * spd_k * Tuning.move_scale()
		# Decoy: E key, or the DECOY button on touch screens (edge-triggered)
		var decoy_now: bool = Input.is_key_pressed(KEY_E) or TouchControls.consume_decoy()
		var aim_fire: bool = TouchControls.aim_fire and _shoot_timer <= 0.0
		if decoy_now and not _decoy_was_down and decoys > 0:
			_throw_decoy(input_dir)
		_decoy_was_down = decoy_now
		if Input.is_action_just_pressed("dodge") and _dodge_cd_timer <= 0.0:
			_start_dodge(input_dir)
		elif Input.is_action_pressed("attack") and _attack_timer <= 0.0:
			_attack()
		elif (Input.is_action_pressed("shoot") or aim_fire) and _shoot_timer <= 0.0:
			if aim_fire:
				TouchControls.aim_fire = false
			_shoot(aim_fire)

	move_and_slide()
	_moving = input_dir != Vector2.ZERO

	# Footstep dust (none while sneaking)
	if not is_dodging and not is_sneaking and input_dir != Vector2.ZERO:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.2
			Fx.burst(get_parent(), global_position + Vector2(0, 13), Color(0.55, 0.52, 0.5, 0.45),
					3, 28.0, 0.35, 3.0, 180.0, -input_dir)

	# Feed the animation
	art.aim_angle = facing.angle()
	art.move_amount = 0.0 if is_dodging else clampf(velocity.length() / (speed * Tuning.move_scale()), 0.0, 1.0)
	art.dodging = is_dodging
	art.scale = Vector2(0.9, 0.9) if is_sneaking else Vector2.ONE
	art.attack_progress = (_swing_time / SWING_TIME) if _swing_time >= 0.0 else -1.0

	# Light settles back after an attack bump
	_light.energy = lerpf(_light.energy, LIGHT_BASE, minf(1.0, delta * 9.0))


# ---------- Attack ----------
func _attack() -> void:
	_attack_timer = attack_cooldown
	_swing_time = 0.0
	_light.energy = LIGHT_BASE * 1.7
	_flash(Color(1.35, 1.3, 0.6))  # yellow flash on attack
	Audio.play("swing", -3.0)

	# Face the closest enemy in range so the swing looks aimed
	var nearest: Node2D = null
	var best := INF
	var targets: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d := global_position.distance_to(enemy.global_position)
		# attack_range is measured to the enemy's edge, so add its radius
		if d <= attack_range + ENEMY_RADIUS:
			targets.append(enemy)
			if d < best:
				best = d
				nearest = enemy
	if nearest:
		facing = (nearest.global_position - global_position).normalized()

	_noise_boost = 0.45
	var stealth_kill: bool = false
	for enemy in targets:
		if enemy.has_method("can_backstab") and enemy.can_backstab(global_position):
			enemy.backstab(global_position)
			stealth_kill = true
		else:
			enemy.take_damage(attack_damage, global_position, knockback_force)
	if stealth_kill:
		Fx.burst(get_parent(), global_position + facing * 30.0, Color(2.0, 1.8, 1.2), 10, 260.0, 0.25, 3.0, 40.0, facing, true)

	if not targets.is_empty():
		_shake(3.5)
		Fx.hit_stop(get_tree(), 0.04)


# ---------- Bow ----------
func _shoot(from_stick: bool = false) -> void:
	if blind_timer > 0.0:
		return
	if ammo <= 0:
		_shoot_timer = 0.3
		get_tree().call_group("game_manager", "toast", "Out of arrows!")
		return
	ammo -= 1
	_shoot_timer = float(bow["cd"])
	var dir: Vector2 = _shot_dir(from_stick)
	facing = dir
	var a = ArrowScript.new()
	a.velocity = dir * float(bow["speed"]) * (1.25 if Progression.has_perk("eagle_eye") else 1.0)
	a.damage = int(round(float(bow["dmg"]) * arrow_mult))
	a.pierce = int(bow["pierce"])
	a.color = bow["color"]
	a.position = global_position + dir * 26.0
	get_parent().add_child(a)
	art.bow_show = 0.3
	_noise_boost = 0.3
	Audio.play("swing", -6.0, 0.2)


## Touch aiming. The aim stick points roughly and the game locks onto the enemy nearest to that
## direction; the BOW button alone shoots at the nearest enemy it can see. Moving enemies are led.
func _touch_mode() -> bool:
	return TouchControls.is_touch or Tuning.FORCE_MOBILE


func _shot_dir(from_stick: bool) -> Vector2:
	if _touch_mode():
		if from_stick or TouchControls.aim_active:
			var t: Node2D = _pick_target(TouchControls.aim_dir, ASSIST_CONE, ASSIST_RANGE)
			if t != null:
				return _lead_dir(t)
			return TouchControls.aim_dir
		var t2: Node2D = _pick_target(facing, PI, ASSIST_RANGE)
		if t2 != null:
			return _lead_dir(t2)
		return facing
	var aim: Vector2 = get_global_mouse_position() - global_position
	return aim.normalized() if aim.length() > 26.0 else facing


func _los_clear(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to, 12)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Best enemy for the shot: inside the cone, in range, in line of sight. Aligned beats close.
func _pick_target(dir: Vector2, cone: float, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_score: float = INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or int(e.get("state")) == 3:
			continue
		var to: Vector2 = e.global_position - global_position
		var d: float = to.length()
		if d > max_range or d < 1.0:
			continue
		var ad: float = absf(angle_difference(dir.angle(), to.angle()))
		if ad > cone:
			continue
		var score: float = ad * (400.0 if cone < PI else 90.0) + d * 0.35
		if score >= best_score:
			continue
		if not _los_clear(e.global_position):
			continue
		best_score = score
		best = e
	return best


func _lead_dir(t: Node2D) -> Vector2:
	var spd: float = float(bow["speed"]) * (1.25 if Progression.has_perk("eagle_eye") else 1.0)
	var to: Vector2 = t.global_position - global_position
	var v: Vector2 = Vector2.ZERO
	if t is CharacterBody2D:
		v = (t as CharacterBody2D).velocity
	var aim_pt: Vector2 = to + v * (to.length() / maxf(spd, 1.0)) * 0.9
	return aim_pt.normalized() if aim_pt.length() > 1.0 else facing


func _update_assist() -> void:
	if is_dead or not _touch_mode():
		_auto_target = null
	elif TouchControls.aim_active:
		_auto_target = _pick_target(TouchControls.aim_dir, ASSIST_CONE, ASSIST_RANGE)
	else:
		_auto_target = _pick_target(facing, PI, ASSIST_RANGE)
	if _reticle != null:
		_reticle.queue_redraw()


# ---------- Decoy ----------
func _throw_decoy(input_dir: Vector2) -> void:
	decoys -= 1
	var dir: Vector2 = input_dir.normalized() if input_dir != Vector2.ZERO else facing
	var d = DecoyScript.new()
	d.setup(global_position + dir * 20.0, dir)
	get_parent().add_child(d)
	get_tree().call_group("game_manager", "toast", "Decoy thrown (%d left)" % decoys)


# ---------- Dodge ----------
func _start_dodge(input_dir: Vector2) -> void:
	is_dodging = true
	_dodge_time_left = dodge_duration
	_dodge_cd_timer = dodge_cooldown * (0.6 if Progression.has_perk("quick_roll") else 1.0)
	_dodge_dir = input_dir.normalized() if input_dir != Vector2.ZERO else facing
	art.self_modulate.a = 0.45  # translucent while invulnerable
	Audio.play("dodge", -4.0)
	Fx.burst(get_parent(), global_position + Vector2(0, 8), Color(0.7, 0.68, 0.65, 0.6),
			10, 120.0, 0.4, 4.0, 60.0, -_dodge_dir)
	Fx.burst(get_parent(), global_position, Color(1.1, 1.2, 1.5, 0.7),
			6, 220.0, 0.2, 2.0, 15.0, -_dodge_dir, true)


func _end_dodge() -> void:
	is_dodging = false
	_dodge_time_left = 0.0
	art.self_modulate.a = 1.0


## How far guards can HEAR the player right now (pixels).
func noise_radius() -> float:
	if is_dead:
		return 0.0
	var r: float = 0.0
	if is_dodging:
		r = 150.0
	elif _moving:
		r = 45.0 if is_sneaking else 120.0
	if _noise_boost > 0.0:
		r = maxf(r, 230.0)
	if Progression.has_perk("light_feet"):
		r *= 0.75
	return r * noise_mult


## 0..1, how recharged the dodge roll is (1 = ready). Used by the HUD bar.
func dodge_ready_ratio() -> float:
	return 1.0 - clampf(_dodge_cd_timer / dodge_cooldown, 0.0, 1.0)


# ---------- Damage ----------
## Returns true if damage was actually applied (false while dodging / dead).
func take_damage(amount: int) -> bool:
	if is_dead or is_dodging or invulnerable > 0.0:
		return false
	amount = maxi(1, int(round(float(amount) * dmg_taken_mult)))
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_flash(Color(2.0, 0.25, 0.25))  # red flash on hit
	Audio.play("hurt", -2.0)
	var root := get_parent()
	Fx.burst(root, global_position, Color(0.8, 0.05, 0.08), 12, 190.0, 0.5, 4.0)
	Fx.damage_number(root, global_position, amount, Color(1.0, 0.3, 0.3))
	Fx.hit_stop(get_tree(), 0.06)
	if health <= 0:
		_die()
	return true


## Revive Kit: stand back up with part of your health and a short grace period.
func revive(fraction: float) -> void:
	is_dead = false
	health = maxi(1, int(max_health * fraction))
	invulnerable = 1.5
	art.modulate = Color.WHITE
	health_changed.emit(health, max_health)
	_flash(Color(1.6, 1.8, 1.6))
	Audio.play("heal")
	Fx.burst(get_parent(), global_position, Color(0.5, 1.0, 0.6), 22, 200.0, 0.6, 4.0)


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	art.modulate = Color(0.35, 0.35, 0.4)
	art.attack_progress = -1.0
	art.move_amount = 0.0
	Audio.play("player_death")
	Fx.burst(get_parent(), global_position, Color(0.8, 0.05, 0.08), 28, 260.0, 0.8, 5.0)
	player_died.emit()


# ---------- Wave / upgrade helpers (called by GameManager) ----------
func reset_for_wave(start_position: Vector2) -> void:
	_end_dodge()
	_attack_timer = 0.0
	_dodge_cd_timer = 0.0
	_swing_time = -1.0
	global_position = start_position
	health = max_health
	health_changed.emit(health, max_health)


## Restores health (never above max). Returns how much was actually healed.
func heal(amount: int) -> int:
	if is_dead:
		return 0
	var before := health
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	_flash(Color(0.6, 1.8, 0.8))  # green flash on heal
	return health - before


func upgrade_attack(amount: int) -> void:
	attack_damage += amount


func upgrade_max_health(amount: int) -> void:
	max_health += amount
	health += amount
	health_changed.emit(health, max_health)


# ---------- Juice ----------
## Blinder's flash: the hero slows down and cannot shoot for a moment.
func blind(duration: float) -> void:
	if is_dead:
		return
	if blind_timer <= 0.0:
		get_tree().call_group("game_manager", "toast", "Blinded!")
	blind_timer = maxf(blind_timer, duration)
	_flash(Color(2.4, 2.4, 2.2))


func _flash(color: Color) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	art.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(art, "modulate", Color.WHITE, 0.16)


func _shake(amount: float) -> void:
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("shake"):
		gm.shake(amount)
