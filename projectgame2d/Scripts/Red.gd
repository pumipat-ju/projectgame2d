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
@export var shoot_cooldown: float = 0.25
@export var shoot_spawn_offset := Vector2(32, -8)
var shoot_timer := 0.0

# --------- NODES ----------
@onready var player_sprite = $AnimatedSprite2D
@onready var shoot_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- BUILT-IN FUNCTIONS ----------
func _process(delta):
	if is_dead:
		return
	shoot_timer = max(0.0, shoot_timer - delta)
	movement(delta)
	player_animations()
	flip_player()
	handle_shooting()

# --------- CUSTOM FUNCTIONS ----------
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

		var inputAxis = Input.get_axis("Left", "Right")
		velocity.x = inputAxis * move_speed

	move_and_slide()  # Godot 4.x ใช้ velocity ของ CharacterBody2D

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

func player_animations():
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

func flip_player():
	player_sprite.flip_h = velocity.x < 0
	shoot_sprite.flip_h = player_sprite.flip_h

# --------- SHOOTING FUNCTIONS ----------
func handle_shooting():
	# ยิงกระสุนตาม cooldown
	if Input.is_action_just_pressed("Shoot") and shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		
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
		
	# เล่น animation Shoot แค่ตอนเริ่มยิง และไม่รีเซ็ตถ้า animation ยังไม่จบ
	if Input.is_action_just_pressed("Shoot") and shoot_sprite.animation != "Shoot":
		shoot_sprite.play("Shoot")


# --------- HEALTH FUNCTIONS ----------
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO):
	if is_dead:
		return
	health -= amount
	print("Player HP:", health)
	
	if knockback != Vector2.ZERO:
		knockback_velocity = knockback
		knockback_timer = knockback_duration
		# ไม่รีเซ็ต velocity.y เพื่อไม่ให้ลอย

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
