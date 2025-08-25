extends Node2D

@onready var spawn_point: Node2D = $Level/SpawnPoint
const DEFAULT_PLAYER := preload("res://Scenes/Prefabs/Red.tscn")

func _ready():
	var scene_to_spawn: PackedScene = GameManager.selected_player_scene
	if scene_to_spawn == null:
		scene_to_spawn = DEFAULT_PLAYER
		push_warning("GameState.selected_player_scene is null. Using DEFAULT_PLAYER (Red).")

	var player = scene_to_spawn.instantiate()
	add_child(player)

	if spawn_point:
		player.global_position = spawn_point.global_position
	else:
		push_warning("SpawnPoint not found. Player will spawn at (0,0).")
