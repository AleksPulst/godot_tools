@tool
## A Camera behaviour script that has smoothing and targets tracking.
## Tank like camera works but setting the use_follow_target_as_base_transform to true and mouse motion false.
extends Camera3D

## Multiplier for damp values to simplify the numbers that are exposed to the editor.
@export var EXPODENTIAL_MULTIPLIER : float = 1000

## The Node3d that the camera is following
@export var _follow_target : Node3D


## Cameras starting rotation in degrees. This value is changed from the code in runtime if mouse input is enabled.
@export var camera_rotation_degrees : Vector3 :
	set(value):
		camera_rotation_degrees.x = clampf(value.x,-90,0)
		camera_rotation_degrees.y = value.y
		camera_rotation_degrees.z = value.z

## Is the mouse motion used to change the cameras oriantation.
@export var use_mouse_motion : bool = true

@export var use_follow_target_as_base_transform : bool = false

var base_camera_rotation : Vector3

@export_subgroup("Position")

## The current and starting clamped distance that the camera takes from the target.
@export var _distance: float = 5:
	set(value):
		_distance = clampf(value,_min_distance,_max_distance)

## The distance value damped based on the zoom damp amount.
var _damped_distance : float = 5

## Minimum distance that the camera can be from the target.
@export var _min_distance : float = 1.0 :
	set(value):
		_min_distance = value
		if value > _max_distance:
			_max_distance = value
		_distance = _distance # NOTE when the min changes we want to update the _distance so it can clamp itself

## Maximum Distance that the camera can be from the target.
@export var _max_distance : float = 10.0:
	set(value):
		if value < _min_distance:
			_min_distance = value
		_max_distance = value
		_distance = _distance # NOTE when the min changes we want to update the _distance so it can clamp itself
@export var _look_ahead_amount : float = 1.0
## The smoothed position of the follow_targets global position. The targets position is smoothed
## instead of the cameras to ensure that there wont be any weird movement of the camera when
## the orienatation is changed quicly.

@export_subgroup("Damping")

## Damping value of how much the the tracing is damped. 0 is none and 1 is almost a stationary camera.
@export_range(0,1) var _targets_position_damp : float = 0.2

## Damping value for the looking ahead behaviour.
@export_range(0,1) var _look_ahead_damp : float = 0.2

## Damping value for the zooming movement.
@export_range(0,1) var _zoom_damp : float = 0.2

@export_range(0,1) var _rotation_damp : float = 0.1

# The cached damped values
var _damped_target_position : Vector3 = Vector3.ZERO
var _damped_rotation_degrees : Vector3 = Vector3.ZERO
var _damped_look_ahead_position : Vector3 = Vector3.ZERO

@export_subgroup("Sensitivity")

## How responsive is the camera to zooming.
@export var mouse_zoom_sensitivity : float = 50

## Sensitivity of the mouse motions y axis to the cameras pitch.
@export_range(0.0,50) var look_sensitivity_y : float = 10

## Sensitivity of the mouse motions x axis to the cameras yaw.
@export_range(0.0,50) var look_sensitivity_x : float = 10


var _velocity : Vector3 = Vector3.ZERO
var _position_last_frame : Vector3 = Vector3.ZERO


## The Input function is used to listen to direct mouse inputs instead of the input system.
func _input(event: InputEvent) -> void:

	if not use_mouse_motion: return

	# Mouse motion needs to be captured in the _input function
	if event is InputEventMouseMotion:
		camera_rotation_degrees.x -= event.relative.y * look_sensitivity_y /100
		camera_rotation_degrees.y -= event.relative.x * look_sensitivity_x /100

	# Mouse scroll can be captured in the input system but it's here for clarity reasons.
	if event is InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_distance -= mouse_zoom_sensitivity * get_process_delta_time()
				MOUSE_BUTTON_WHEEL_DOWN:
					_distance += mouse_zoom_sensitivity * get_process_delta_time()

func _ready() -> void:
	# Locks the mouse to the center of the screen and set the damp position to its inital position.
	if not Engine.is_editor_hint():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_damped_target_position = _follow_target.global_position
	_damped_distance = _distance
	if use_follow_target_as_base_transform:
		base_camera_rotation = _follow_target.global_rotation_degrees
	_damped_rotation_degrees = camera_rotation_degrees + base_camera_rotation
	_damped_look_ahead_position = Vector3.ZERO
	_position_last_frame = _follow_target.global_position



func _process(delta: float) -> void:
	_update_damp_values(delta)
	# The camera rotation and position are set in the process function to keep it as smooth as possible.
	global_rotation_degrees = get_target_rotation_degrees()
	global_position = get_target_position()

func _physics_process(delta: float) -> void:
	_velocity = (_follow_target.global_position - _position_last_frame)/delta
	_position_last_frame = _follow_target.global_position

## Updates to position and rotation damping values using expodential decay so that changin the time scale will also change the damping.
func _update_damp_values(delta : float):

	# If timescale is 0 then nothing is moving anyways so we can return the function.
	if Engine.time_scale <= 0 : return

	# using expodential decay to remove frame dependency.
	# camera position damping
	var pos_damp_t : float = 1.0-pow(_targets_position_damp**4,delta)
	_damped_target_position = _damped_target_position.lerp(_follow_target.global_position,pos_damp_t)

	# Camera look ahead position damping.
	var look_ahead_damp_t : float = 1.0 - pow(_look_ahead_damp**4,delta)
	var look_ahead_pos : Vector3 = (_velocity.limit_length(1.0) * _look_ahead_amount)
	_damped_look_ahead_position = _damped_look_ahead_position.lerp(look_ahead_pos,look_ahead_damp_t)

	# Camera rotation damping.
	var rotation_damp_t : float = 1.0 - pow(_rotation_damp**4,delta)
	var target_rotation : Vector3
	if use_follow_target_as_base_transform:
		target_rotation = camera_rotation_degrees + _follow_target.global_rotation_degrees
	else :
		target_rotation = camera_rotation_degrees
	# Every axis has to be separetly lerped to prevent the rotation from looping around. Slerp might also work just didnt think of it before it was done.
	_damped_rotation_degrees.x = rad_to_deg(lerp_angle(deg_to_rad(_damped_rotation_degrees.x), deg_to_rad(target_rotation.x), rotation_damp_t))
	_damped_rotation_degrees.z = rad_to_deg(lerp_angle(deg_to_rad(_damped_rotation_degrees.z), deg_to_rad(target_rotation.z), rotation_damp_t))
	_damped_rotation_degrees.y = rad_to_deg(lerp_angle(deg_to_rad(_damped_rotation_degrees.y), deg_to_rad(target_rotation.y), rotation_damp_t))

	var damp_t : float = 1.0- pow(_zoom_damp**4,delta)
	_damped_distance = lerpf(_damped_distance,_distance,damp_t)

## Returns a position _distance away from target on the z axis.
## The orientation has to set first for this to work properly.
func get_target_position():
	return _damped_target_position + _damped_look_ahead_position + basis.z * _damped_distance

## Returns a vector in degrees that is comprised of the pitch yaw and roll angle.
func get_target_rotation_degrees():
	return _damped_rotation_degrees
