@tool
extends EditorPlugin

const ASSEMBLY_SCRIPT = preload("res://addons/castle_destruction/pre_fractured_assembly.gd")

func _enter_tree() -> void:
	add_custom_type("PreFracturedAssembly", "Node3D", ASSEMBLY_SCRIPT, null)

func _exit_tree() -> void:
	remove_custom_type("PreFracturedAssembly")
