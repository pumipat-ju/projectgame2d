extends Area2D

@export var speed: float = 600
@export var damage: int = 30
@export var lifetime: float = 5.0
var velocity: Vector2 = Vector2.ZERO

func _ready():
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	position += velocity * delta

# เปลี่ยนชื่อฟังก์ชันจาก look_at -> aim_at
func aim_at(target: Vector2):
	var direction = (target - global_position).normalized()
	velocity = direction * speed
	rotation = velocity.angle()

func _on_body_entered(body):
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(damage, Vector2.ZERO)
		queue_free()
	else:
		queue_free()
