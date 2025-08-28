extends CharacterBody2D

# --------- VARIABLES ----------
@export_category("Player Properties")
@export var move_speed : float = 400
@export var jump_force : float = 1000
@export var gravity : float = 15
@export var max_jump_count : int = 2
var jump_count : int = 2

@export_category("Toggle Functions")
@export var double_jump : bool = false
var is_grounded : bool = false

# --------- HEALTH SYSTEM ----------
@export var max_health : int = 100
var health : int = max_health
var is_dead: bool = false

# --------- KNOCKBACK ----------
var knockback_velocity = Vector2.ZERO
var knockback_timer = 0.0
var knockback_duration = 0.2

# --------- SHOOTING ----------
@export var bullet_scene: PackedScene        # ลาก Bullet.tscn ใส่ Inspector
@export var shoot_cooldown: float = 0.5
@export var shoot_spawn_offset := Vector2(32, -8)
var shoot_timer := 0.0

# --------- SHOOT ANIMATION LOCK ----------
var shoot_lock := false   # ยึดอนิเมชัน Shoot ให้ทับ Walk/Idle/Jump ระหว่างยิง

# --------- NODES ----------
@onready var player_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_sprite:  AnimatedSprite2D = $AnimatedSprite2D  # ตอนนี้ใช้ node เดียวกัน
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

func _ready():
	# กันพลาด: ตั้งค่าเริ่มต้นให้ Shoot ไม่ลูปเอง (เราจะควบคุมด้วยโค้ด)
	if shoot_sprite.sprite_frames and shoot_sprite.sprite_frames.has_animation("Shoot"):
		shoot_sprite.sprite_frames.set_animation_loop("Shoot", false)

# --------- BUILT-IN FUNCTIONS ----------
func _process(delta):
	if is_dead:
		return

	# ลดคูลดาวน์ยิง
	shoot_timer = max(0.0, shoot_timer - delta)

	movement(delta)        # เดิน/กระโดดได้ตามปกติ แม้กำลังกดยิง
	handle_shooting()      # จัดการยิง + ล็อกอนิเมชัน
	player_animations()    # เลือกอนิเมชันตาม shoot_lock
	flip_player()

# --------- MOVEMENT ----------
func movement(delta):
	# ----------------- KNOCKBACK -----------------
	if knockback_timer > 0:
		velocity = knockback_velocity
		knockback_timer -= delta
	else:
		# ----------------- GRAVITY -----------------
		if not is_on_floor():
			velocity.y += gravity
		else:
			jump_count = max_jump_count

		handle_jumping()

		# เดินได้แม้กำลังกดยิง
		var inputAxis = Input.get_axis("Left", "Right")
		velocity.x = inputAxis * move_speed

	move_and_slide()

func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor():
			jump()
			jump_count -= 1
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

func jump():
	jump_tween()
	if Engine.has_singleton("AudioManager"):
		AudioManager.jump_sfx.play()
	velocity.y = -jump_force

# --------- ANIMATIONS ----------
# เลือกอนิเมชันฐาน (Idle/Walk/Jump) ที่เดียวตรงนี้
func player_animations():
	# ถ้ากำลังล็อกยิง → คง Shoot ให้ทับอนิเมชันฐาน
	if shoot_lock:
		if shoot_sprite.animation != "Shoot":
			shoot_sprite.play("Shoot")
		return
	_set_base_animation()

func _set_base_animation():
	particle_trails.emitting = false

	if is_on_floor():
		if abs(velocity.x) > 0:
			particle_trails.emitting = true
			if player_sprite.animation != "Walk":
				player_sprite.play("Walk")
			player_sprite.speed_scale = 1.5
		else:
			if player_sprite.animation != "Idle":
				player_sprite.play("Idle")
			player_sprite.speed_scale = 1.0
	else:
		if player_sprite.animation != "Jump":
			player_sprite.play("Jump")
		player_sprite.speed_scale = 1.0

var facing_left = false

func flip_player():
	if velocity.x < 0:
		facing_left = true
	elif velocity.x > 0:
		facing_left = false

	player_sprite.flip_h = facing_left
	shoot_sprite.flip_h = facing_left

# --------- SHOOTING ----------
func handle_shooting():
	var pressed := Input.is_action_pressed("Shoot")
	var just_pressed := Input.is_action_just_pressed("Shoot")
	var just_released := Input.is_action_just_released("Shoot")

	# เริ่มกดยิง → ล็อกอนิเมชัน Shoot และตั้งให้วน 1 รอบ/วินาที
	if just_pressed and !shoot_lock:
		shoot_lock = true
		_start_shoot_loop_per_second()

	# ยิงกระสุนตามคูลดาวน์ (รองรับกดค้าง)
	if pressed and shoot_timer <= 0.0:
		_fire_bullet()
		shoot_timer = shoot_cooldown
		# ย้ำให้อนิเมชันอยู่ที่ Shoot เสมอระหว่างล็อก
		if shoot_lock and shoot_sprite.animation != "Shoot":
			shoot_sprite.play("Shoot")

	# ปล่อยปุ่ม → ปลดล็อก, ปิดลูป, รีเซ็ตสปีด และคืนอนิเมชันฐานทันที
	if just_released and shoot_lock:
		shoot_lock = false
		_stop_shoot_loop()
		_set_base_animation()

func _fire_bullet():
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		get_parent().add_child(bullet)

		var off = shoot_spawn_offset
		if player_sprite.flip_h:
			off.x = -off.x
		bullet.global_position = global_position + off

		var dir = Vector2.LEFT if player_sprite.flip_h else Vector2.RIGHT
		if bullet.has_method("set_direction"):
			bullet.set_direction(dir)

	if Engine.has_singleton("AudioManager"):
		AudioManager.shoot_sfx.play()

# วนอนิเมชัน Shoot = 1 รอบต่อ 1 วินาที ขณะค้างปุ่ม
func _start_shoot_loop_per_second():
	if !shoot_sprite.sprite_frames or !shoot_sprite.sprite_frames.has_animation("Shoot"):
		return
	var frames := shoot_sprite.sprite_frames.get_frame_count("Shoot")
	var fps := float(shoot_sprite.sprite_frames.get_animation_speed("Shoot"))
	if fps <= 0.0:
		fps = 1.0
	var base_duration := float(frames) / fps  # วินาที/รอบ (ก่อนคูณ speed_scale)

	# ต้องการให้เล่น 1 รอบ = 1 วินาที
	# duration = base_duration / speed_scale = 1 → speed_scale = base_duration
	shoot_sprite.speed_scale = base_duration
	shoot_sprite.sprite_frames.set_animation_loop("Shoot", true)
	shoot_sprite.play("Shoot")

# หยุดโหมดวนเมื่อปล่อยปุ่ม
func _stop_shoot_loop():
	if shoot_sprite.sprite_frames and shoot_sprite.sprite_frames.has_animation("Shoot"):
		shoot_sprite.sprite_frames.set_animation_loop("Shoot", false)
	shoot_sprite.speed_scale = 1.0
	shoot_sprite.stop()

# --- Callback animation ---
# (ต่อสัญญาณ animation_finished ของ AnimatedSprite2D ที่เล่น "Shoot" มายังฟังก์ชันนี้)
func _on_shoot_sprite_animation_finished():
	# ถ้ายังค้างปุ่มอยู่ เราเปิด loop ไว้แล้ว มันจะเล่นต่อเอง
	# ถ้าไม่ได้ค้าง → รีเซ็ตและคืนอนิเมชันฐาน
	if !Input.is_action_pressed("Shoot"):
		if shoot_lock:
			shoot_lock = false
		_stop_shoot_loop()
		_set_base_animation()

# --------- HEALTH FUNCTIONS ----------
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO):
	if is_dead:
		return
	health -= amount
	print("Player HP:", health)

	if knockback != Vector2.ZERO:
		knockback_velocity = knockback
		knockback_timer = knockback_duration

	if health <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true

	if Engine.has_singleton("AudioManager"):
		AudioManager.death_sfx.play()
	death_particles.emitting = true

	velocity = Vector2.ZERO

	var spawn_pos = Vector2.ZERO
	if get_parent().has_node("SpawnPoint"):
		spawn_pos = get_parent().get_node("SpawnPoint").global_position

	death_tween(spawn_pos)

func death_tween(spawn_position: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished

	global_position = spawn_position
	velocity = Vector2.ZERO

	await get_tree().create_timer(0.3).timeout
	if Engine.has_singleton("AudioManager"):
		AudioManager.respawn_sfx.play()

	health = max_health
	is_dead = false

	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func jump_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# --------- SIGNALS ----------
func _on_collision_body_entered(_body):
	if _body.is_in_group("Traps"):
		take_damage(9999)
