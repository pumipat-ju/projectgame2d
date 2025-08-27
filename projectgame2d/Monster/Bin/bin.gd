extends CharacterBody2D

@export var speed: float = 200
@export var gravity: float = 800
@export var damage: int = 20
@export var damage_cooldown: float = 1.0 # หน่วงเวลา 1 วินาทีระหว่างดาเมจ

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var player: Node2D
var last_damage_time: float = -1.0

func _ready():
	# หา Player จากกลุ่ม
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		print("⚠️ Player not found in group 'Player'!")

func _physics_process(delta):
	# หา player ใหม่ถ้าไม่เจอ
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

	# ติดตาม Player (แกน X)
	var dir = sign(player.global_position.x - global_position.x) # -1 ซ้าย, 1 ขวา
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

	# ชน Player แล้วทำดาเมจแบบ cooldown
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var target = collision.get_collider()
		if target.is_in_group("Player") and target.has_method("take_damage"):
			var current_time = Time.get_ticks_msec() / 500.0
			if current_time - last_damage_time > damage_cooldown:
				target.take_damage(damage)
				last_damage_time = current_time
