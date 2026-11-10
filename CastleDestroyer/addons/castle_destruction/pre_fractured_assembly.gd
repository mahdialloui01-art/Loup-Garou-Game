@tool
extends Node3D
class_name PreFracturedAssembly
## Runtime mesh-swap helper. Assign pre-fractured RigidBody3D scenes in the
## Inspector; each scene should contain its own MeshInstance3D and collision.

@export var fragment_scenes: Array[PackedScene] = []
@export_range(1, 128, 1) var fragment_budget: int = 32
@export var hide_source_after_fracture: bool = true

func fracture(source: Node3D, impulse: Vector3, force: float = 8.0) -> int:
	if source == null or fragment_scenes.is_empty():
		return 0
	var spawned := 0
	var source_transform: Transform3D = source.global_transform
	var max_count: int = mini(fragment_scenes.size(), fragment_budget)
	for index in range(max_count):
		var packed: PackedScene = fragment_scenes[index]
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		if not instance is RigidBody3D:
			instance.queue_free()
			continue
		var fragment := instance as RigidBody3D
		var local_transform: Transform3D = fragment.transform
		add_child(fragment)
		fragment.global_transform = source_transform * local_transform
		var spread := Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.25), randf_range(-0.2, 0.2))
		var direction: Vector3 = impulse.normalized() if impulse.length_squared() > 0.001 else Vector3.UP
		fragment.apply_central_impulse((direction + spread).normalized() * force)
		spawned += 1
	if hide_source_after_fracture and spawned > 0:
		source.hide()
		source.process_mode = Node.PROCESS_MODE_DISABLED
	return spawned
