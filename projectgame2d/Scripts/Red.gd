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

@onready var player_sprite = $AnimatedSprite2D
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- BUILT-IN FUNCTIONS ----------
func _process(_delta):
	if is_dead:
		return # หยุด input และ movement ชั่วคราว
	movement()
	player_animations()
	flip_player()

# --------- CUSTOM FUNCTIONS ----------
func movement():
	if !is_on_floor():
		velocity.y += gravity
	elif is_on_floor():
		jump_count = max_jump_count

	handle_jumping()
	
	var inputAxis = Input.get_axis("Left", "Right")
	velocity = Vector2(inputAxis * move_speed, velocity.y)
	move_and_slide()

func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor() and !double_jump:
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

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
func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	print("Player HP:", health)
	
	if health <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	
	AudioManager.death_sfx.play()
	death_particles.emitting = true
	
	# ปิด movement
	velocity = Vector2.ZERO

	# tween ย่อก่อน respawn
	if get_parent().has_node("SpawnPoint"):
		death_tween(get_parent().get_node("SpawnPoint").global_position)
	else:
		death_tween(Vector2.ZERO)

func death_tween(spawn_position: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished
	
	global_position = spawn_position
	await get_tree().create_timer(0.3).timeout
	AudioManager.respawn_sfx.play()
	
	# รีเซ็ตเลือดและสถานะ
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
		take_damage(9999) # ตายทันทีเมื่อโดน Trap
