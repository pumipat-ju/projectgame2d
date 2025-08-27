extends Area2D

@export var speed: float = 400
@export var damage: int = 15

var direction: Vector2 = Vector2.RIGHT

func _ready():
	# กันลืมเปิด Monitoring ใน Inspector ก็ยังทำงาน เพราะ Area2D เปิดอยู่แล้วโดยปริยาย
	await get_tree().create_timer(3.0).timeout
	queue_free()

func set_direction(bullet_direction: Vector2):
	direction = bullet_direction.normalized()
	rotation = direction.angle()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body: Node):
	# อย่าให้กระสุนชนผู้เล่น (กันพลาด)
	if body.is_in_group("Player"):
		return

	# ชนศัตรู → ทำดาเมจ
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return

	# ชนสิ่งอื่น (กำแพง/พื้น/ของแข็ง) → กระสุนหาย
	# Note: ถ้า TileMap ไม่ได้อยู่ใน group ใด ๆ จะเข้าบล็อกนี้
	queue_free()
