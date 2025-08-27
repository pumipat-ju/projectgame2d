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

# --------- NODES ----------
@onready var player_sprite = $AnimatedSprite2D
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- BUILT-IN FUNCTIONS ----------
func _process(_delta):
	if is_dead:
		return
	movement(_delta)
	player_animations()
	flip_player()

# --------- CUSTOM FUNCTIONS ----------
func movement(delta):
	# ----------------- KNOCKBACK -----------------
	if knockback_timer > 0:
		velocity = knockback_velocity
		knockback_timer -= delta
	else:
		# ----------------- GRAVITY -----------------
		if !is_on_floor():
			velocity.y += gravity
		else:
			# รีเซ็ต jump_count เต็มจำนวนตอนอยู่บนพื้น
			jump_count = max_jump_count

		handle_jumping()
		
		var inputAxis = Input.get_axis("Left", "Right")
		velocity.x = inputAxis * move_speed

	move_and_slide()  # Godot 4.x ใช้แบบนี้

func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor():
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1  # ลด count เฉพาะ double jump

func jump():
	jump_tween()
	AudioManager.jump_sfx.play()
	velocity.y = -jump_force

func player_animations():
	particle_trails.emitting = false
	if is_on_floor():
		if abs(velocity.x) > 0:
			particle_trails.emitting = true
			if player_sprite.animation != "Walk" or not player_sprite.is_playing():
				player_sprite.play("Walk", 1.5)
		else:
			if player_sprite.animation != "Idle" or not player_sprite.is_playing():
				player_sprite.play("Idle")
	else:
		if player_sprite.animation != "Jump" or not player_sprite.is_playing():
			player_sprite.play("Jump")

func flip_player():
	player_sprite.flip_h = velocity.x < 0

# --------- HEALTH FUNCTIONS ----------
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO):
	if is_dead:
		return
	health -= amount
	print("Player HP:", health)
	
	# ----------------- APPLY KNOCKBACK -----------------
	if knockback != Vector2.ZERO:
		knockback_velocity = knockback
		knockback_timer = knockback_duration
		velocity.y = 0  # รีเซ็ตความเร็วแกน Y เพื่อไม่ให้กระเด็นผิดปกติ

	if health <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	
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
	AudioManager.respawn_sfx.play()
	
	health = max_health
	is_dead = false
	
	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func jump_tween():
	# ป้องกัน tween ซ้อน
	var existing_tween = get_node_or_null("Tween")
	if existing_tween:
		existing_tween.kill()
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# --------- SIGNALS ----------
func _on_collision_body_entered(_body):
	if _body.is_in_group("Traps"):
		take_damage(9999) # ตายทันทีเมื่อโดน Trap
