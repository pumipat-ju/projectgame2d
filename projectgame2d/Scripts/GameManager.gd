extends Node2D

var score: int = 0
var kill_count: int = 0
var player_deaths: int = 0

var selected_player_scene: PackedScene = null

# --- Player Health ---
var player_max_health: int = 200
var player_health: int = 200

# --- Boss Health (กรณีมีบอส) ---
var boss_max_health: int = 500
var boss_health: int = 500


func reset():
	selected_player_scene = null
	player_health = player_max_health
	boss_health = boss_max_health
	kill_count = 0
	score = 0

func add_score():
	score += 1

func add_kill():
	kill_count += 1
	
func add_player_death():
	player_deaths += 1

func load_next_level(next_scene: PackedScene):
	get_tree().change_scene_to_packed(next_scene)
