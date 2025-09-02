extends CharacterBody2D

# --------- VARIABLES ----------
@export_category("Player Properties")
@export var move_speed : float = 400
@export var jump_force : float = 1000
@export var gravity : float = 2800.0
@export var max_jump_count : int = 2
var jump_count : int = 2

@export_category("Toggle Functions")
@export var double_jump : bool = false
var is_grounded : bool = false

# --------- HEALTH SYSTEM ----------
@export var max_health : int = 150
var health : int = max_health
var is_dead: bool = false
@export var flash_duration: float = 0.1

# --------- KNOCKBACK ----------
var knockback_velocity = Vector2.ZERO
var knockback_timer = 0.0
var knockback_duration = 0.2

# --------- SHOOTING ----------
@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 0.5
@export var shoot_spawn_offset := Vector2(32, -8)
var shoot_timer := 0.0
var shoot_lock := false   # ยึดอนิเมชัน Shoot ให้ทับ Walk/Idle/Jump ระหว่างยิง

# --------- NODES ----------
@onready var player_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_sprite:  AnimatedSprite2D = $AnimatedSprite2D  # ตอนนี้ใช้ node เดียวกัน
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- FOOTSTEP ----------
@export var footstep_interval_base := 0.35     # ใช้ในโหมดจังหวะก้าว
@export var footstep_loop_mode := true         # true = loop ต่อเนื่อง, false = จังหวะก้าว
var footstep_timer := 0.0

var facing_left = false

func _am() -> Node:
	return get_tree().get_root().get_node_or_null("AudioManager")

func _ready():
	if shoot_sprite.sprite_frames and shoot_sprite.sprite_frames.has_animation("Shoot"):
		shoot_sprite.sprite_frames.set_animation_loop("Shoot", false)

# --------- BUILT-IN FUNCTIONS ----------
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# timers
	footstep_timer = max(0.0, footstep_timer - delta)
	shoot_timer = max(0.0, shoot_timer - delta)

	movement(delta)
	move_and_slide()

	handle_shooting()
	player_animations()
	flip_player()

func _process(_delta): pass

# --------- MOVEMENT ----------
func movement(delta):
	if knockback_timer > 0.0:
		velocity = knockback_velocity
		knockback_timer -= delta
	else:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			jump_count = max_jump_count

		handle_jumping()

		var inputAxis = Input.get_axis("Left", "Right")
		velocity.x = inputAxis * move_speed

		# ----- WALK SFX -----
		_play_walk_sfx()

func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		# เล่นเสียงกระโดด (ต้องมี AudioManager เป็น Autoload และมี jump_sfx)
		if Engine.has_singleton("AudioManager"):
			AudioManager.jump_sfx.play()

		if is_on_floor():
			jump()
			jump_count -= 1
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

func jump():
	jump_tween()
	velocity.y = -jump_force

# --------- WALK SFX HELPER ----------
func _play_walk_sfx():
	var am := _am()
	if am == null:
		return
	var walk_sfx: AudioStreamPlayer = am.get_node_or_null("WalkSfx")
	if walk_sfx == null:
		return

	var walking = is_on_floor() and absf(velocity.x) > 0.1 and knockback_timer <= 0.0 and not is_dead

	if footstep_loop_mode:
		# โหมด loop ต่อเนื่อง
		if walking:
			if not walk_sfx.playing:
				walk_sfx.pitch_scale = randf_range(0.97, 1.03)
				walk_sfx.play()   # แนะนำเปิด Loop ใน Inspector
		else:
			if walk_sfx.playing:
				walk_sfx.stop()
	else:
		# โหมดจังหวะก้าว (ติ๊บ ๆ ตามสปีด)
		if walking:
			# แก้ไขบรรทัดที่ 130-131
			var spd = clamp(absf(velocity.x) / max(1.0, move_speed), 0.6, 1.4)
			var interval = footstep_interval_base / spd
			if footstep_timer <= 0.0:
				walk_sfx.pitch_scale = randf_range(0.95, 1.05)
				walk_sfx.play()
				footstep_timer = interval
		else:
			footstep_timer = 0.0
			# ถ้าเผลอเปิด loop ที่ไฟล์เสียงไว้ ให้หยุดด้วย
			if walk_sfx.playing and walk_sfx.stream and walk_sfx.stream.loop:
				walk_sfx.stop()


# --------- ANIMATIONS ----------
func player_animations():
	if shoot_lock:
		if shoot_sprite.animation != "Shoot":
			shoot_sprite.play("Shoot")
		return
	_set_base_animation()

func _set_base_animation():
	particle_trails.emitting = false

	if is_on_floor():
		if abs(velocity.x) > 0.1:
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

func flip_player():
	if velocity.x < 0.0:
		facing_left = true
	elif velocity.x > 0.0:
		facing_left = false

	player_sprite.flip_h = facing_left
	shoot_sprite.flip_h = facing_left

# --------- SHOOTING ----------
func handle_shooting():
	var pressed := Input.is_action_pressed("Shoot")
	var just_pressed := Input.is_action_just_pressed("Shoot")
	var just_released := Input.is_action_just_released("Shoot")

	if just_pressed and not shoot_lock:
		shoot_lock = true
		_start_shoot_loop_per_second()

	if pressed and shoot_timer <= 0.0:
		_fire_bullet()
		shoot_timer = shoot_cooldown
		if shoot_lock and shoot_sprite.animation != "Shoot":
			shoot_sprite.play("Shoot")

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

	# เล่นเสียงยิงตอนยิงจริง (เรียกฟังก์ชัน helper)
	_play_shoot_sfx()



func _start_shoot_loop_per_second():
	if not shoot_sprite.sprite_frames or not shoot_sprite.sprite_frames.has_animation("Shoot"):
		return
	var frames := shoot_sprite.sprite_frames.get_frame_count("Shoot")
	var fps := float(shoot_sprite.sprite_frames.get_animation_speed("Shoot"))
	if fps <= 0.0:
		fps = 1.0
	var base_duration := float(frames) / fps
	shoot_sprite.speed_scale = base_duration           # ทำให้ความยาวรอบ = 1 วินาที
	shoot_sprite.sprite_frames.set_animation_loop("Shoot", true)
	shoot_sprite.play("Shoot")

func _stop_shoot_loop():
	if shoot_sprite.sprite_frames and shoot_sprite.sprite_frames.has_animation("Shoot"):
		shoot_sprite.sprite_frames.set_animation_loop("Shoot", false)
	shoot_sprite.speed_scale = 1.0
	shoot_sprite.stop()

func _on_shoot_sprite_animation_finished():
	if not Input.is_action_pressed("Shoot"):
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

	flash_red()

	if knockback != Vector2.ZERO:
		knockback_velocity = knockback
		knockback_timer = knockback_duration

	if health <= 0:
		die()

func flash_red():
	player_sprite.modulate = Color(1, 0, 0)
	if shoot_sprite != player_sprite:
		shoot_sprite.modulate = Color(1, 0, 0)

	var timer = get_tree().create_timer(flash_duration)
	await timer.timeout

	player_sprite.modulate = Color(1, 1, 1)
	if shoot_sprite != player_sprite:
		shoot_sprite.modulate = Color(1, 1, 1)

func die():
	if is_dead:
		return
	is_dead = true

	# หยุดเสียงเดินทันที
	_stop_walk_sfx()

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

# --------- UTIL ----------
func _stop_walk_sfx():
	var am := _am()
	if am:
		var walk_sfx: AudioStreamPlayer = am.get_node_or_null("WalkSfx")
		if walk_sfx and walk_sfx.playing:
			walk_sfx.stop()
# --------- SFX HELPERS ----------
func _play_shoot_sfx():
	var am := _am()
	if am == null:
		return

	var shoot_sfx: AudioStreamPlayer = am.get_node_or_null("ShootSfx")
	if shoot_sfx:
		shoot_sfx.pitch_scale = randf_range(0.97, 1.03)
		if shoot_sfx.playing:
			shoot_sfx.stop()
		shoot_sfx.play()
