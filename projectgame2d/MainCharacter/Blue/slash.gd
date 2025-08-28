extends Area2D

@export var speed: float = 1000
@export var damage: int = 10

var direction: Vector2 = Vector2.RIGHT
var hit_targets: Array = []  # เก็บศัตรูที่โดนแล้ว

func _ready():
	await get_tree().create_timer(0.1).timeout  # อยู่แค่ครู่เดียว
	queue_free()

func set_direction(bullet_direction: Vector2):
	direction = bullet_direction.normalized()
	rotation = direction.angle()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body: Node):
	if body.is_in_group("Player"):
		return
	if body.is_in_group("enemies") and body not in hit_targets:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		hit_targets.append(body)  # บันทึกว่าตัวนี้โดนแล้ว
		# ไม่ queue_free() ทำให้ Slash สามารถโดนศัตรูอื่นต่อ
		return
