# GameManager.gd (Autoload)
extends Node2D

signal health_changed(current: int, max: int)

# --------- SCORE / KILL / DEATH ----------
var score: int = 0
var kill_count: int = 0
var player_deaths: int = 0

# --------- SCENE SELECTION ----------
var selected_player_scene: PackedScene = null

# --------- INTERNAL STORAGE FOR PROPERTIES ----------
var _player_max_health: int = 200
var _player_health: int = 200

# Godot 4 property syntax
var player_max_health: int : set = set_player_max_health, get = get_player_max_health
var player_health: int : set = set_player_health, get = get_player_health

# --------- BOSS HEALTH ----------
signal boss_health_changed(current: int, max: int)
signal boss_died

var _boss_max_health: int = 500
var _boss_health: int = 500

var boss_max_health: int : set = set_boss_max_health, get = get_boss_max_health
var boss_health: int : set = set_boss_health, get = get_boss_health

# --------- RUNTIME TRACKING ----------
var _current_player: Node = null

func _ready() -> void:
	set_player_max_health(200)
	set_player_health(200)

	set_boss_max_health(500)
	set_boss_health(500)

	_try_adopt_player()

	var t := Timer.new()
	t.wait_time = 0.25
	t.one_shot = false
	t.autostart = true
	add_child(t)
	t.timeout.connect(_heartbeat_sync)

# --------- HEARTBEAT / ADOPT PLAYER ----------
func _heartbeat_sync() -> void:
	if not is_instance_valid(_current_player):
		_try_adopt_player()
		return
	_mirror_from_player_if_changed()

func _try_adopt_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_current_player = players[0]
		_adopt_from_player(_current_player)

func _adopt_from_player(p: Node) -> void:
	if "max_health" in p:
		set_player_max_health(p.max_health)
	if "health" in p:
		set_player_health(p.health)

func _mirror_from_player_if_changed() -> void:
	if not is_instance_valid(_current_player):
		return
	if "max_health" in _current_player and _current_player.max_health != _player_max_health:
		set_player_max_health(_current_player.max_health)
	if "health" in _current_player and _current_player.health != _player_health:
		set_player_health(_current_player.health)

# --------- PLAYER SET/GET ----------
func set_player_max_health(v: int) -> void:
	v = max(1, v)
	if v == _player_max_health:
		return
	_player_max_health = v
	if _player_health > v:
		_player_health = v
	_emit_health_changed()

func get_player_max_health() -> int:
	return _player_max_health

func set_player_health(v: int) -> void:
	var clamped: int = clamp(int(v), 0, _player_max_health)
	if clamped == _player_health:
		return
	_player_health = clamped
	_emit_health_changed()

func get_player_health() -> int:
	return _player_health

func _emit_health_changed() -> void:
	emit_signal("health_changed", _player_health, _player_max_health)
	_update_health_ui()

func _update_health_ui() -> void:
	# ตัวอย่างพาธ HUD ผู้เล่น:
	# var bar: TextureProgressBar = get_node_or_null("/root/HUD/HealthBar")
	# if bar:
	#     bar.max_value = _player_max_health
	#     bar.value = _player_health
	pass

# --------- BOSS SET/GET ----------
func set_boss_max_health(v: int) -> void:
	v = max(1, v)
	if v == _boss_max_health:
		return
	_boss_max_health = v
	if _boss_health > v:
		_boss_health = v
	_emit_boss_changed()

func get_boss_max_health() -> int:
	return _boss_max_health

func set_boss_health(v: int) -> void:
	var clamped: int = clamp(int(v), 0, _boss_max_health)
	if clamped == _boss_health:
		return
	_boss_health = clamped
	_emit_boss_changed()
	if _boss_health <= 0:
		_boss_health = 0
		emit_signal("boss_died")
		_force_boss_ui_zero()  # บังคับหลอดให้เป็น 0% เป๊ะทันที

func get_boss_health() -> int:
	return _boss_health

func _emit_boss_changed() -> void:
	emit_signal("boss_health_changed", _boss_health, _boss_max_health)
	_update_boss_health_ui()

func _update_boss_health_ui() -> void:
	# ใส่พาธจริงของหลอดบอสตรงนี้ถ้าต้องการอัปเดตตรงๆ
	# var bar: TextureProgressBar = get_node_or_null("/root/HUD/BossHealthBar")
	# if bar:
	#     bar.max_value = _boss_max_health
	#     bar.value = _boss_health
	pass

func _force_boss_ui_zero() -> void:
	# SNAP UI → 0% ทันทีตอนบอสตาย (แก้ค้าง 1–3%)
	# เปลี่ยนพาธให้ตรงกับโปรเจกต์คุณ
	# var bar: TextureProgressBar = get_node_or_null("/root/HUD/BossHealthBar")
	# if bar:
	#     # ถ้ามี Tween ที่วิ่งอยู่ให้หยุดก่อน
	#     for c in bar.get_children():
	#         if c is Tween:
	#             (c as Tween).kill()
	#     bar.step = 1
	#     bar.max_value = _boss_max_health
	#     bar.value = 0
	#     bar.queue_redraw()
	pass

# --------- PUBLIC API ----------
func add_score(value: int = 1) -> void:
	score += value

func add_kill(value: int = 1) -> void:
	kill_count += value

func add_player_death() -> void:
	player_deaths += 1

func reset() -> void:
	selected_player_scene = null
	set_player_max_health(_player_max_health)
	set_player_health(_player_max_health)

	set_boss_max_health(_boss_max_health)
	set_boss_health(_boss_max_health)

	kill_count = 0
	score = 0
	_update_health_ui()
	_update_boss_health_ui()

func load_next_level(next_scene: PackedScene) -> void:
	get_tree().change_scene_to_packed(next_scene)

# --------- OPTIONAL UTILS ----------
func apply_damage_to_player(dmg: int) -> void:
	if dmg <= 0:
		return
	set_player_health(_player_health - dmg)

func heal_player(amount: int) -> void:
	if amount <= 0:
		return
	set_player_health(_player_health + amount)

func apply_damage_to_boss(dmg: int) -> void:
	if dmg <= 0:
		return
	set_boss_health(_boss_health - dmg)

func heal_boss(amount: int) -> void:
	if amount <= 0:
		return
	set_boss_health(_boss_health + amount)
