extends CharacterBody2D

# --------- VARIABLES ----------
@export var move_speed : float = 500
@export var jump_force : float = 1000
@export var gravity : float = 2800
@export var max_jump_count : int = 2
var jump_count : int = 2

@export var double_jump : bool = false
var is_grounded : bool = false

# --------- KNOCKBACK ----------
var knockback_velocity = Vector2.ZERO
var knockback_timer = 0.0
var knockback_duration = 0.2

# --------- HEALTH ----------
@export var max_health : int = 200
var health : int = max_health
var is_dead: bool = false
@export var flash_duration: float = 0.1

# --------- SLASH ----------
@export var slash_scene: PackedScene
@export var slash_spawn_offset := Vector2(40, 0)
var slash_lock := false
var slash_fired := false  # ยิงคลื่นดาบแล้วในรอบนี้หรือยัง

# --------- NODES ----------
@onready var player_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- FOOTSTEP ----------
@export var footstep_interval_base := 0.35     # ใช้ในโหมดจังหวะก้าว
@export var footstep_loop_mode := true         # true = loop ต่อเนื่อง, false = จังหวะก้าว
var footstep_timer := 0.0

var facing_left = false

func _am() -> Node:
	return get_tree().get_root().get_node_or_null("AudioManager")

# --------- READY ----------
func _ready():
	player_sprite.animation_finished.connect(_on_player_sprite_animation_finished)
	player_sprite.frame_changed.connect(_on_frame_changed)

# --------- PHYSICS LOOP ----------
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# timers
	footstep_timer = max(0.0, footstep_timer - delta)

	movement(delta)
	move_and_slide()

	handle_slash()
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
			# gravity เป็น px/s^2 → ต้องคูณ delta
			velocity.y += gravity * delta
		else:
			jump_count = max_jump_count

		handle_jumping()

		var inputAxis = Input.get_axis("Left", "Right")
		# move_speed คือ px/s → ไม่ต้องคูณ delta
		velocity.x = inputAxis * move_speed

		# ----- WALK SFX -----
		_play_walk_sfx()

func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if Engine.has_singleton("AudioManager"):
			AudioManager.jump_sfx.play()

		if is_on_floor():
			jump()
			jump_count -= 1
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

func jump():
	velocity.y = -jump_force

# --------- WALK SFX HELPER ----------
func _play_walk_sfx():
	var am := _am()
	if am == null:
		return
	var walk_sfx: AudioStreamPlayer = am.get_node_or_null("WalkSfx")
	if walk_sfx == null:
		return

	var walking = is_on_floor() and abs(velocity.x) > 0.1 and knockback_timer <= 0.0 and not is_dead

	if footstep_loop_mode:
		# โหมด loop ต่อเนื่อง
		if walking:
			if not walk_sfx.playing:
				walk_sfx.pitch_scale = randf_range(0.97, 1.03)
				walk_sfx.play()    # แนะนำเปิด Loop ใน Inspector
		else:
			if walk_sfx.playing:
				walk_sfx.stop()
	else:
		# โหมดจังหวะก้าว (ติ๊บ ๆ ตามสปีด)
		if walking:
			var spd = clamp(abs(velocity.x) / max(1.0, move_speed), 0.6, 1.4)
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
	if slash_lock:
		if player_sprite.animation != "Slash":
			player_sprite.play("Slash")
		return
	_set_base_animation()

func _set_base_animation():
	particle_trails.emitting = false
	if is_on_floor():
		if abs(velocity.x) > 0.1:   # <- เปลี่ยน absf เป็น abs
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

# --------- SLASH ----------
func handle_slash():
	var just_pressed = Input.is_action_just_pressed("Slash")
	if just_pressed and not slash_lock:
		slash_lock = true
		slash_fired = false
		player_sprite.play("Slash")

func _on_frame_changed():
	if player_sprite.animation != "Slash":
		return
	# ยิงคลื่นดาบตรงเฟรมกลาง (ปรับหมายเลขเฟรมได้ตามสไปต์จริง)
	if not slash_fired and player_sprite.frame == 1:
		_fire_slash()
		slash_fired = true

func _on_player_sprite_animation_finished():
	if player_sprite.animation == "Slash":
		slash_lock = false
		slash_fired = false

func _fire_slash():
	if slash_scene:
		var slash = slash_scene.instantiate()
		get_parent().add_child(slash)

		var off = slash_spawn_offset
		if player_sprite.flip_h:
			off.x = -off.x
		slash.global_position = global_position + off

		var dir = Vector2.LEFT if player_sprite.flip_h else Vector2.RIGHT
		if slash.has_method("set_direction"):
			slash.set_direction(dir)

	# เล่นเสียงฟันดาบตอนปล่อยคลื่นจริง
	_play_slash_sfx()

# --------- HEALTH FUNCTIONS ----------
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO):
	if is_dead:
		return
	health -= amount
	GameManager.player_health = health   # <<<<< อัปเดต UI ผ่าน GameManager

	print("Player HP:", health)
	flash_red()

	if knockback != Vector2.ZERO:
		knockback_velocity = knockback
		knockback_timer = knockback_duration

	if health <= 0:
		die()

func flash_red():
	_play_damage_sfx()
	player_sprite.modulate = Color(1, 0, 0)
	var timer = get_tree().create_timer(flash_duration)
	await timer.timeout
	player_sprite.modulate = Color(1, 1, 1)

func die():
	if is_dead:
		return
	is_dead = true
	
	GameManager.add_player_death()
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

func death_tween(spawn_position: Vector2 = Vector2.ZERO):
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished

	# ถ้าไม่มี spawn point ให้ใช้ global_position ปัจจุบันแทน
	if spawn_position == Vector2.ZERO and get_parent().has_node("SpawnPoint"):
		spawn_position = get_parent().get_node("SpawnPoint").global_position

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

	# Reset HP หลังเกิดใหม่
	health = max_health
	GameManager.player_health = health


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
func _play_slash_sfx():
	var am := _am()
	if am == null:
		return
	# เข้าถึง node SlashSfx ใน AudioManager โดยตรง
	var slash_sfx: AudioStreamPlayer = am.get_node_or_null("SlashSfx")
	if slash_sfx:
		slash_sfx.pitch_scale = randf_range(0.97, 1.03)
		if slash_sfx.playing:
			slash_sfx.stop()  # รีสตาร์ตให้ดังทันที
		slash_sfx.play()

func _play_damage_sfx():
	var am := _am()
	if am == null:
		return
	# หาเป็น Node ลูกชื่อ DamageSfx
	var dmg: AudioStreamPlayer = am.get_node_or_null("DamageSfx")
	if dmg:
		if dmg.playing:
			dmg.stop()
		dmg.play()
		dmg.seek(0.5)
		return
	# หรือถ้าเก็บเป็น property ในสคริปต์ของ AudioManager
	if Engine.has_singleton("AudioManager") and "DamageSfx" in AudioManager:
		var p = AudioManager.DamageSfx
		if p and (p is AudioStreamPlayer or p is AudioStreamPlayer2D):
			if p.playing:
				p.stop()
			p.play()
