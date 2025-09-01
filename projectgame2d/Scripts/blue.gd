extends CharacterBody2D

# --------- VARIABLES ----------
@export var move_speed : float = 500
@export var jump_force : float = 1000

# เดิมคุณใช้ gravity = 15 ต่อ "เฟรม"
# เทียบเท่าประมาณ 15*60 = 900 ต่อ "วินาที^2" (ถ้า Physics 60 FPS)
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
@export var flash_duration: float = 0.1   # เวลาเป็นสีแดงต่อครั้ง

# --------- SLASH ----------
@export var slash_scene: PackedScene
@export var slash_spawn_offset := Vector2(40,0)
var slash_lock := false
var slash_fired := false  # เช็คว่าคลื่นดาบยิงแล้วในเฟรมนี้

# --------- NODES ----------
@onready var player_sprite = $AnimatedSprite2D
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- READY ----------
func _ready():
	player_sprite.animation_finished.connect(_on_player_sprite_animation_finished)
	player_sprite.frame_changed.connect(_on_frame_changed)

# --------- PHYSICS LOOP ----------
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	movement(delta)        # <-- เคลื่อนที่/แรงโน้มถ่วงคูณ delta
	move_and_slide()       # <-- เรียกที่นี่ "ที่เดียว" ในฟิสิกส์ลูป

	handle_slash()
	player_animations()
	flip_player()

# --------- (เดิม) PROCESS ----------
# ไม่ใช้สำหรับฟิสิกส์อีกต่อไป
func _process(_delta): pass

# --------- MOVEMENT ----------
func movement(delta):
	if knockback_timer > 0:
		velocity = knockback_velocity
		knockback_timer -= delta
	else:
		if !is_on_floor():
			# gravity เป็นหน่วย px/s^2 → ต้องคูณ delta
			velocity.y += gravity * delta
		else:
			jump_count = max_jump_count

		handle_jumping()

		var inputAxis = Input.get_axis("Left","Right")
		# move_speed คือ "ความเร็ว" px/s ไม่ต้องคูณ delta
		velocity.x = inputAxis * move_speed

	# IMPORTANT: ตัด move_and_slide() ออกจากที่นี่
	# ให้ไปเรียกใน _physics_process() แทน

func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor():
			jump()
			jump_count -= 1
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

func jump():
	# jump_force เป็น "ความเร็วเริ่มต้น" ของการกระโดด (px/s) → ไม่คูณ delta
	velocity.y = -jump_force

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
	if velocity.x < 0: facing_left = true
	elif velocity.x > 0: facing_left = false
	player_sprite.flip_h = facing_left

# --------- SLASH ----------
func handle_slash():
	var just_pressed := Input.is_action_just_pressed("Slash")
	if just_pressed and !slash_lock:
		slash_lock = true
		slash_fired = false
		player_sprite.play("Slash")

func _on_frame_changed():
	if player_sprite.animation != "Slash": return
	if !slash_fired and player_sprite.frame == 1:  # เฟรมกลาง Slash
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
		if player_sprite.flip_h: off.x = -off.x
		slash.global_position = global_position + off
		var dir = Vector2.LEFT if player_sprite.flip_h else Vector2.RIGHT
		if slash.has_method("set_direction"):
			slash.set_direction(dir)

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
	var timer = get_tree().create_timer(flash_duration)
	await timer.timeout
	player_sprite.modulate = Color(1, 1, 1)

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

func jump_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# --------- SIGNALS ----------
func _on_collision_body_entered(_body):
	if _body.is_in_group("Traps"):
		take_damage(9999)
