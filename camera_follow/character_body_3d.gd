extends CharacterBody3D

## This is the default implementation for the character movement with few additions.
## Movement is remaped to match the cameras orientation
## and the characters mesh in interpolated in process instead of the physics process to remove jitter.

const SPEED = 8.0
const JUMP_VELOCITY = 7.0
@export var input_space : Node3D
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	mesh_instance_3d.top_level = true

func _process(_delta: float) -> void:
	# split the lerp into as many sections as there are regular frames in a physics frame.
	if Engine.time_scale <= 0.01: return

	mesh_instance_3d.global_position = mesh_instance_3d.global_position.lerp(global_position,0.3)
	mesh_instance_3d.global_rotation = global_rotation # Update the rotation because the mesh is now a top level node.

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if Engine.time_scale <= 0.001 : return

	if not is_on_floor():
		velocity += get_gravity() * delta*2

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY


	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var axis_aligned_input_space := Basis(input_space.global_basis.x,global_basis.y,input_space.global_basis.z).orthonormalized()
	var direction := (axis_aligned_input_space * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
