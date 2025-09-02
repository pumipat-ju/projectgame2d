extends Control

@onready var kills_label: Label = $KillsLabel
@onready var deaths_label: Label = $DeathsLabel
@onready var restart_button: Button = $RestartButton
@onready var quit_button: Button = $QuitButton

func _ready():
	if kills_label:
		kills_label.text = "Kills: %d" % GameManager.kill_count
	if deaths_label:
		deaths_label.text = "Deaths: %d" % GameManager.player_deaths

	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_restart_pressed():
	# โหลดด่านแรกใหม่
	get_tree().change_scene_to_file("res://Scenes/Prefabs/control.tscn")

func _on_quit_pressed():
	# กลับไปเมนูหลัก
	get_tree().quit()
