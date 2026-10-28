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
var bow: Dictionary = {}
var ammo: int = 0
var max_ammo: int = 0
var _shoot_timer: float = 0.0
var _reticle: Node2D
var _noise_boost: float = 0.0
var _moving: bool = false

var _attack_timer: float = 0.0       # time until next attack allowed
var _swing_time: float = -1.0        # <0 = not swinging
var _dodge_time_left: float = 0.0    # remaining roll time
var _dodge_cd_timer: float = 0.0     # time until next roll allowed
var _dodge_dir: Vector2 = Vector2.RIGHT
var _step_timer: float = 0.0
var _flash_tween: Tween
var _light: PointLight2D

@onready var art: Node2D = $Art


func _ready() -> void:
	add_to_group("player")  # also set in the scene; harmless duplicate
	collision_layer = 1
	collision_mask = 12     # walls + closed doors (4) and props (8)
	_apply_loadout()
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
	dmg_taken_mult = float(suit["dmg"])
	speed_mult = float(suit["spd"])
	noise_mult = float(suit["noise"])
	max_health = 100 + ItemsScript.VITALITY_HP * int(SaveScript.vitality)
	max_ammo = int(bow["ammo"])
	ammo = max_ammo
	art.apply_loadout(suit, sword, bow)


func add_ammo(n: int) -> int:
	var before: int = ammo
	ammo = mini(ammo + n, max_ammo)
	return ammo - before


func _draw_reticle() -> void:
	if is_dead:
		return
	var m: Vector2 = get_global_mouse_position()
	_reticle.global_position = Vector2.ZERO
	var col := Color(1.0, 0.9, 0.5, 0.75) if ammo > 0 else Color(1.0, 0.3, 0.3, 0.6)
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
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)

	# Tick timers
	_noise_boost = maxf(_noise_boost - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_dodge_cd_timer = maxf(_dodge_cd_timer - delta, 0.0)
	if _swing_time >= 0.0:
		_swing_time += delta
		if _swing_time >= SWING_TIME:
			_swing_time = -1.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()

	if is_dodging:
		_dodge_time_left -= delta
		velocity = _dodge_dir * dodge_speed
		if _dodge_time_left <= 0.0:
			_end_dodge()
	else:
		is_sneaking = Input.is_action_pressed("sneak")
		var spd_k: float = speed_mult * (0.45 if slow_timer > 0.0 else 1.0)
		velocity = input_dir * (sneak_speed if is_sneaking else speed) * spd_k
		if Input.is_action_just_pressed("dodge") and _dodge_cd_timer <= 0.0:
			_start_dodge(input_dir)
		elif Input.is_action_pressed("attack") and _attack_timer <= 0.0:
			_attack()
		elif Input.is_action_pressed("shoot") and _shoot_timer <= 0.0:
			_shoot()

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
	art.move_amount = 0.0 if is_dodging else clampf(velocity.length() / speed, 0.0, 1.0)
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
func _shoot() -> void:
	if ammo <= 0:
		_shoot_timer = 0.3
		get_tree().call_group("game_manager", "toast", "Out of arrows!")
		return
	ammo -= 1
	_shoot_timer = float(bow["cd"])
	var aim: Vector2 = get_global_mouse_position() - global_position
	var dir: Vector2 = aim.normalized() if aim.length() > 26.0 else facing
	facing = dir
	var a = ArrowScript.new()
	a.velocity = dir * float(bow["speed"])
	a.damage = int(bow["dmg"])
	a.pierce = int(bow["pierce"])
	a.color = bow["color"]
	a.position = global_position + dir * 26.0
	get_parent().add_child(a)
	art.bow_show = 0.3
	_noise_boost = 0.3
	Audio.play("swing", -6.0, 0.2)


# ---------- Dodge ----------
func _start_dodge(input_dir: Vector2) -> void:
	is_dodging = true
	_dodge_time_left = dodge_duration
	_dodge_cd_timer = dodge_cooldown
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
	return r * noise_mult


## 0..1, how recharged the dodge roll is (1 = ready). Used by the HUD bar.
func dodge_ready_ratio() -> float:
	return 1.0 - clampf(_dodge_cd_timer / dodge_cooldown, 0.0, 1.0)


# ---------- Damage ----------
## Returns true if damage was actually applied (false while dodging / dead).
func take_damage(amount: int) -> bool:
	if is_dead or is_dodging:
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
