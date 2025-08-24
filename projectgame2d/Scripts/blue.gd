extends CharacterBody2D

# --------- VARIABLES ----------
@export_category("Player Properties")
@export var move_speed : float = 400
@export var jump_force : float = 1000
@export var gravity : float = 15
@export var max_jump_count : int = 2
var jump_count : int = 2

@export_category("Toggle Functions")
@export var double_jump : = false

var is_grounded : bool = false

@onready var player_sprite = $AnimatedSprite2D
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- BUILT-IN FUNCTIONS ----------
func _process(_delta):
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
			player_sprite.play("Walk", 1.5)
		else:
			player_sprite.play("Idle")
	else:
		player_sprite.play("Jump")

func flip_player():
	player_sprite.flip_h = velocity.x < 0

# --------- TWEEN ANIMATIONS ----------
func death_tween(spawn_position: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished
	
	global_position = spawn_position # ใช้ตำแหน่ง spawn ที่ส่งมาจาก Level_01
	
	await get_tree().create_timer(0.3).timeout
	AudioManager.respawn_sfx.play()
	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func jump_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# --------- SIGNALS ----------
func _on_collision_body_entered(_body):
	if _body.is_in_group("Traps"):
		AudioManager.death_sfx.play()
		death_particles.emitting = true
		# ส่ง spawn_point จาก Level_01 มาที่ death_tween()
		if get_parent().has_node("SpawnPoint"):
			death_tween(get_parent().get_node("SpawnPoint").global_position)
		else:
			death_tween(Vector2.ZERO)
