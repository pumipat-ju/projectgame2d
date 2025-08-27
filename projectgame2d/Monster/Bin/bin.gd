extends CharacterBody2D

@export var speed: float = 200
@export var gravity: float = 800
@export var damage: int = 20
@export var damage_cooldown: float = 1.0
@export var max_health: int = 50
@export var flash_duration: float = 0.1  # เวลาแฟลชสีแดง
var health: int

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var player: Node2D
var last_damage_time: float = -1.0

func _ready():
	health = max_health
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		print("⚠️ Player not found in group 'Player'!")

func _physics_process(delta):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			velocity.x = 0
			move_and_slide()
			return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# ไล่ Player
	var dir = sign(player.global_position.x - global_position.x)
	velocity.x = dir * speed
	move_and_slide()

	# Animation
	if abs(velocity.x) > 0 and is_on_floor():
		if anim.animation != "Walk":
			anim.play("Walk")
	else:
		if anim.animation != "Idle":
			anim.play("Idle")
	anim.flip_h = velocity.x < 0

	# ชน Player
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var target = collision.get_collider()
		if target.is_in_group("Player") and target.has_method("take_damage"):
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_damage_time > damage_cooldown:
				var knockback_dir = sign(target.global_position.x - global_position.x)
				var knockback_vector = Vector2(knockback_dir * 700, -400)
				target.take_damage(damage, knockback_vector)
				last_damage_time = current_time

# --------- Enemy Take Damage + Flash ---------
func take_damage(amount: int):
	health -= amount
	print("Enemy HP:", health)
	flash_red()
	if health <= 0:
		queue_free()  # มอนตาย ลบออก

func flash_red():
	anim.modulate = Color(1, 0, 0)  # สีแดง
	await get_tree().create_timer(flash_duration).timeout
	anim.modulate = Color(1, 1, 1)  # สีปกติ
