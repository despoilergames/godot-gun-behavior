@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("GunBehavior", "Node", preload("res://addons/gun_behavor/gun_behavior.gd"), preload("res://addons/gun_behavor/icon.svg"))


func _exit_tree() -> void:
	remove_custom_type("GunBehavior")


func _has_main_screen() -> bool:
	return false


func _make_visible(visible: bool) -> void:
	pass


func _get_plugin_name() -> String:
	return "Gun Behavior"
