extends CharacterBody2D

enum BossState { PHASE1, PHASE2_WALK, PHASE2_DASH }
var state = BossState.PHASE1

# -------- CONFIG ---------
@export var gravity: float = 800
@export var damage: int = 50
@export var flash_duration: float = 0.1

@export var phase1_health: int = 400
@export var phase2_health: int = 400

@export var throw_interval: float = 3.0
@export var throw_cycle: float = 15.0

@export var walk_speed: float = 150
@export var walk_duration: float = 3.0

@export var dash_distance: float = 1000.0
@export var dash_duration: float = 0.8
@export var dash_delay: float = 1.0
@export var dash_repeats: int = 3

# -------- STATE ---------
var health: int
var walk_timer: float = 0.0
var dash_in_progress: bool = false
var boss_health_bar_shown: bool = false 

# -------- REFERENCES ---------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_area: Area2D = $DashArea
var player: Node2D
var spawn_position: Vector2

# Projectile scenes
var projectiles = [
	preload("res://Monster/Projectiles/bottle.tscn"),
	preload("res://Monster/Projectiles/can.tscn"),
	preload("res://Monster/Projectiles/tank.tscn")
]

# -------- READY ---------
func _ready():
	health = phase1_health
	spawn_position = global_position
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		print("⚠️ Player not found!")

	if dash_area:
		dash_area.body_entered.connect(_on_dash_body_entered)
	else:
		print("⚠️ DashArea not found!")

	# ตั้งค่าหลอดบอสแบบ “รวมสองเฟส”
	var max_total := phase1_health + phase2_health
	GameManager.boss_max_health = max_total
	GameManager.boss_health = max_total  # เริ่มเต็ม
	# (จะโชว์หลอดจริงเมื่อโดนครั้งแรก ตามโค้ดด้านล่าง)

	start_throwing_cycle()

# -------- PHYSICS ---------
func _physics_process(delta):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	match state:
		BossState.PHASE1:
			velocity.x = 0
		BossState.PHASE2_WALK:
			if not dash_in_progress:
				walk_towards_player(delta)
				walk_timer += delta
				if walk_timer >= walk_duration:
					walk_timer = 0
					await _start_dash_cycle()
		BossState.PHASE2_DASH:
			pass

	move_and_slide()
	update_animation()

# -------- WALK ---------
func walk_towards_player(delta):
	var dx = player.global_position.x - global_position.x
	if abs(dx) > 10:
		velocity.x = sign(dx) * walk_speed
	else:
		velocity.x = 0

# -------- DASH CYCLE ---------
func _start_dash_cycle() -> void:
	dash_in_progress = true
	state = BossState.PHASE2_DASH
	for i in range(dash_repeats):
		await get_tree().create_timer(dash_delay).timeout  # Delay ก่อนพุ่ง
		var dir_x = sign(player.global_position.x - global_position.x)
		var elapsed = 0.0
		while elapsed < dash_duration:
			velocity.x = dir_x * (dash_distance / dash_duration)
			# move_and_collide ให้ชน Player ได้
			var col = move_and_collide(Vector2(velocity.x * get_process_delta_time(), 0))
			if col:
				var hit = col.get_collider()
				if hit.is_in_group("Player") and hit.has_method("take_damage"):
					var kb = Vector2(dir_x * 400, -200)
					hit.take_damage(damage, kb)
			elapsed += get_process_delta_time()
			await get_tree().physics_frame
		velocity.x = 0
	dash_in_progress = false
	state = BossState.PHASE2_WALK
	walk_timer = 0

# -------- Dash damage signal ---------
func _on_dash_body_entered(body: Node):
	if state == BossState.PHASE2_DASH and body.is_in_group("Player"):
		if body.has_method("take_damage"):
			var dir_x = sign(body.global_position.x - global_position.x)
			var kb = Vector2(dir_x * 400, -200)
			body.take_damage(damage, kb)

# -------- THROW PROJECTILES ---------
func start_throwing_cycle():
	if state != BossState.PHASE1: return
	spawn_projectile_loop()

func spawn_projectile_loop():
	if state != BossState.PHASE1: return
	var t = throw_cycle / throw_interval
	for i in range(int(t)):
		spawn_projectile()
		await get_tree().create_timer(throw_interval).timeout
		if state != BossState.PHASE1: return
	await get_tree().create_timer(3).timeout
	if state == BossState.PHASE1:
		spawn_projectile_loop()

func spawn_projectile():
	if player == null: return
	var scene = projectiles[randi() % projectiles.size()]
	var proj = scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position

	var dist = global_position.distance_to(player.global_position)
	var time_to_hit = clamp(dist / 500.0, 0.4, 1.2)
	proj.launch_at_target(global_position, player.global_position, time_to_hit)
	proj.boss_owner = self

# -------- DAMAGE ---------
func take_damage(amount: int):
	# โชว์หลอดบอสครั้งแรกเมื่อโดน
	if not boss_health_bar_shown:
		var ui = get_tree().get_root().get_node_or_null("UserInterface/GameUI")
		if ui and ui.has_node("BossHealthBar"):
			ui.get_node("BossHealthBar").visible = true
		boss_health_bar_shown = true

	# ลด HP ของ "เฟสปัจจุบัน" และอัปเดต "เลือดรวมคงเหลือ"
	health = max(0, health - amount)
	_update_boss_health_total()

	flash_red()
	print("Boss HP (phase cur):", health, " | total left:", _get_total_left())

	if health <= 0:
		if state == BossState.PHASE1:
			phase_transition()
		else:
			# PHASE2 ตาย → กด GameManager = 0 แล้วค่อย free
			GameManager.boss_health = 0
			queue_free()

# รวมเลือดคงเหลือ: PHASE1 = health + phase2_health (ยังไม่ได้ใช้), PHASE2 = health
func _get_total_left() -> int:
	return (health + phase2_health) if state == BossState.PHASE1 else health

func _update_boss_health_total() -> void:
	# อัปเดตค่าไป GameManager เป็น "เลือดรวมคงเหลือ" เสมอ
	GameManager.boss_health = _get_total_left()

func flash_red():
	anim.modulate = Color(1, 0, 0)
	await get_tree().create_timer(flash_duration).timeout
	anim.modulate = Color(1, 1, 1)

func phase_transition():
	# เข้าสู่ PHASE2: ตั้งเลือดเฟสใหม่ แล้วอัปเดต "เลือดรวมคงเหลือ" (ซึ่งเท่ากับ phase2_health)
	state = BossState.PHASE2_WALK
	flash_transition()
	health = phase2_health
	_update_boss_health_total()  # ตอนนี้ total = phase2_health พอดี

func flash_transition():
	for i in range(6):
		anim.modulate = Color(1, 0, 0)
		await get_tree().create_timer(0.2).timeout
		anim.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.2).timeout

# -------- ANIMATION ---------
func update_animation():
	if abs(velocity.x) > 0 and is_on_floor():
		if anim.animation != "Walk":
			anim.play("Walk")
	else:
		if anim.animation != "Idle":
			anim.play("Idle")
	# Flip sprite ให้ตรงกับทิศทาง
	if velocity.x != 0:
		anim.flip_h = velocity.x < 0
