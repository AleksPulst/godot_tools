extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D


func _process(_delta: float) -> void:
	# split the lerp into as many sections as there are regular frames in a physics frame.
	if Engine.time_scale <= 0.01: return

	mesh_instance_3d.global_position = mesh_instance_3d.global_position.lerp(global_position,0.2)
	mesh_instance_3d.global_rotation = global_rotation # Update the rotation because the mesh is now a top level node.


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity = basis.z * SPEED * input_dir.y
		rotation_degrees.y += input_dir.x * 90 *delta

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
