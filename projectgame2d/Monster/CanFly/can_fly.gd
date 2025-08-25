extends CharacterBody2D

@export var speed: float = 1000
@export var gravity: float = 0

var left_limit: float
var right_limit: float
var direction: int = 1  # 1 = ขวา, -1 = ซ้าย

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# ดึง PatrolPoints จาก Level_01
	var patrol_node = get_parent().get_node("PatroPoints")
	# สมมติว่ามี PointA และ PointB
	var point_a = patrol_node.get_node("PointB2")
	var point_b = patrol_node.get_node("PointB3")
	
	left_limit = point_a.global_position.x
	right_limit = point_b.global_position.x

func _physics_process(delta):
	# แรงโน้มถ่วง
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# เดินซ้ายขวา
	velocity.x = direction * speed
	move_and_slide()

	# กลับทิศเมื่อถึงขอบ
	if position.x > right_limit:
		direction = -1
	elif position.x < left_limit:
		direction = 1

	# เล่นแอนิเมชันเดิน
	if velocity.x != 0 and is_on_floor():
		if not anim.is_playing():
			anim.play("Walk")
	else:
		anim.stop()

	# พลิกหันซ้ายขวา
	anim.flip_h = direction < 0
