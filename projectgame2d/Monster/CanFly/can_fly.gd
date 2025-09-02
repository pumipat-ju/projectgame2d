extends CharacterBody2D

# ----------------- Properties -----------------
@export var speed: float = 150                # ความเร็วส่ายรอบ spawn
@export var chase_speed: float = 250         # ความเร็วบินตามแกน X
@export var detection_range: float = 500     # ระยะเห็นผู้เล่น
@export var damage: int = 0
@export var damage_cooldown: float = 1.0
@export var max_health: int = 30
@export var flash_duration: float = 0.1
@export var laser_scene: PackedScene
@export var laser_cooldown: float = 2.0
@export var hover_distance_x: float = 50     # ระยะส่ายแกน X รอบ spawn
@export var hover_distance_y: float = 30     # ระยะส่ายแกน Y รอบ spawn

# ----------------- Variables -----------------
var health: int
var player: Node2D
var last_damage_time: float = -1.0
var last_laser_time: float = -1.0
var spawn_position: Vector2
var state: String = "idle"
var target_pos: Vector2

# ----------------- Nodes -----------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# ----------------- Ready -----------------
func _ready():
	health = max_health
	spawn_position = global_position
	target_pos = spawn_position
	player = get_tree().get_first_node_in_group("Player")
	if player == null:
		print("⚠️ Player not found in group 'Player'!")

# ----------------- Physics Process -----------------
func _physics_process(delta):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if player == null:
			return

	# ----------------- ตรวจสอบระยะผู้เล่น -----------------
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= detection_range:
		state = "chase"
	else:
		state = "idle"

	# ----------------- State Behavior -----------------
	if state == "idle":
		_patrol(delta)
	elif state == "chase":
		_chase_player(delta)

	# ----------------- Animation Walk / Idle -----------------
	var move_vector = target_pos - global_position
	if move_vector.length() > 1:
		if anim.animation != "Walk":
			anim.play("Walk")
	else:
		if anim.animation != "Idle":
			anim.play("Idle")
	anim.flip_h = move_vector.x < 0

	# ----------------- ยิงเลเซอร์เฉพาะตอนเห็นผู้เล่น -----------------
	if state == "chase":
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_laser_time > laser_cooldown:
			shoot_laser()
			last_laser_time = current_time

# ----------------- Patrol / ส่ายรอบ spawn -----------------
func _patrol(_delta):
	if global_position.distance_to(target_pos) < 2:
		var offset_x = randf_range(-hover_distance_x, hover_distance_x)
		var offset_y = randf_range(-hover_distance_y, hover_distance_y)
		target_pos = spawn_position + Vector2(offset_x, offset_y)
	var direction = (target_pos - global_position).normalized()
	var distance = global_position.distance_to(target_pos)
	var move_amount = min(distance, speed * _delta)
	global_position += direction * move_amount

# ----------------- Chase / แกน X ตามผู้เล่น -----------------
func _chase_player(_delta):
	var desired_x = player.global_position.x
	target_pos = Vector2(desired_x, global_position.y)  # Y คงเดิม
	var direction = (target_pos - global_position).normalized()
	var distance = global_position.distance_to(target_pos)
	var move_amount = min(distance, chase_speed * _delta)
	global_position += direction * move_amount

# ----------------- ยิงเลเซอร์ -----------------
func shoot_laser():
	if laser_scene == null or player == null:
		return
	var laser = laser_scene.instantiate()
	laser.global_position = global_position
	laser.aim_at(player.global_position)
	get_parent().add_child(laser)

# ----------------- โดนโจมตี -----------------
func take_damage(amount: int):
	health -= amount
	print("Enemy HP:", health)
	flash_red()
	if health <= 0:
		die()

func flash_red():
	anim.modulate = Color(1, 0, 0)
	await get_tree().create_timer(flash_duration).timeout
	anim.modulate = Color(1, 1, 1)

# ----------------- รีเซ็ตตำแหน่ง -----------------
func reset_to_spawn():
	global_position = spawn_position
	state = "idle"
	target_pos = spawn_position
	anim.play("Idle")
	
func die():
	GameManager.add_kill()
	queue_free()
