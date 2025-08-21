# This script is an autoload, that can be accessed from any other script!

extends Node2D

var score : int = 0
var selected_player_scene: PackedScene = null

func reset():
	selected_player_scene = null
# Adds 1 to score variable
func add_score():
	score += 1

# Loads next level
func load_next_level(next_scene : PackedScene):
	get_tree().change_scene_to_packed(next_scene)
