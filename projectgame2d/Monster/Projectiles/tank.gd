extends Area2D

@export var damage: int = 20
@export var gravity_force: float = 300
@export var boss_owner: Node
@export var life_time: float = 6.0
@export var hit_destroy: bool = true

var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not body_entered.is_connected(Callable(self, "_on_body_entered")):
		body_entered.connect(Callable(self, "_on_body_entered"))

	await get_tree().create_timer(life_time).timeout
	if is_inside_tree():
		queue_free()

func setup(initial_velocity: Vector2, from_owner: Node = null) -> void:
	velocity = initial_velocity
	boss_owner = from_owner
	rotation = velocity.angle()

func launch_at_target(global_start: Vector2, target_pos: Vector2, prefer_time: float = 0.6) -> void:
	var dx = target_pos.x - global_start.x
	var dy = target_pos.y - global_start.y
	var t = max(0.2, prefer_time)
	var vx = dx / t
	var vy = (dy - 0.5 * gravity_force * t * t) / t
	setup(Vector2(vx, vy))

func _physics_process(delta: float) -> void:
	velocity.y += gravity_force * delta
	global_position += velocity * delta
	rotation = velocity.angle()

func _on_body_entered(body: Node) -> void:
	if body == boss_owner:
		return
	if body.is_in_group("Player"):
		if body.has_method("take_damage"):
			var kb = Vector2(sign(body.global_position.x - global_position.x) * 300, -200)
			body.take_damage(damage, kb)
		else:
			get_tree().call_group("Player", "take_damage", damage)
		if hit_destroy:
			queue_free()
		return
	if hit_destroy:
		queue_free()
