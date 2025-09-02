extends Node2D

@onready var spawn_point: Node2D = $Level/SpawnPoint
const DEFAULT_PLAYER := preload("res://Scenes/Prefabs/Red.tscn")

func _ready():
	var scene_to_spawn: PackedScene = GameManager.selected_player_scene
	if scene_to_spawn == null:
		scene_to_spawn = DEFAULT_PLAYER
		push_warning("GameState.selected_player_scene is null. Using DEFAULT_PLAYER (Red).")
	
	# ✅ ย้าย connect ออกมาไม่ว่า player จะเป็น null หรือไม่
	GameManager.boss_died.connect(_on_boss_died)

	var player = scene_to_spawn.instantiate()
	add_child(player)
	player.add_to_group("Player")

	if spawn_point:
		player.global_position = spawn_point.global_position
	else:
		push_warning("SpawnPoint not found. Player will spawn at (0,0).")

	# --- เล่นเพลงด่าน 1 (ใช้ Autoload ที่ /root/AudioManager) ---
	var am := get_node_or_null("/root/AudioManager")
	if am:
		var p: AudioStreamPlayer = am.get_node_or_null("BossFight")
		if p:
			if p.stream == null:
				push_warning("AudioManager/BossFight has no stream assigned.")
			else:
				p.play()
		else:
			push_warning("Node 'BossFight' not found under AudioManager.")
	else:
		push_warning("Autoload 'AudioManager' not found. Add it in Project Settings → Autoload.")


func _on_boss_died():
	var victory_scene: PackedScene = preload("res://victory_menu.tscn")
	var victory_menu = victory_scene.instantiate()
	add_child(victory_menu)

	# ✅ ให้เมนูครอบจอเสมอ
	if victory_menu is Control:
		victory_menu.set_anchors_preset(Control.PRESET_FULL_RECT)


func _exit_tree():
	var am := get_node_or_null("/root/AudioManager")
	if am:
		var p: AudioStreamPlayer = am.get_node_or_null("BossFight")
		if p:
			p.stop()
