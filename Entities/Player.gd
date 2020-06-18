extends KinematicBody2D


enum State {
	DEFAULT,
	MELEE,
	SCRIPTED
}


const VELOCITY_WALK = 200
const VELOCITY_RUN_MOD = 1.5


var _state = State.DEFAULT
var _run_toggle = false
var _interactable_body = null


onready var Camera = GameCamera
onready var AnimationTree = $AnimationTree
onready var RotationHelper = $RotationHelper

onready var AnimationStateMachine = AnimationTree[ "parameters/playback" ]


# Initialize the player
func _ready():
	pass


# Physics update
func _physics_process( _delta ):
	match _state:
		State.DEFAULT:
			_state_default()
		
		State.MELEE:
			_state_melee()
			
		State.SCRIPTED:
			_state_scripted()
		
		_:
			pass


# Get the motion-related input
func get_motion():
	var velocity = Vector2( 0, 0 )

	velocity.x = Input.get_action_strength( "pl_right" ) - Input.get_action_strength( "pl_left" )
	velocity.y = Input.get_action_strength( "pl_down" ) - Input.get_action_strength( "pl_up" )

	if velocity.length_squared() > 1:
		velocity = velocity.normalized()
	
	velocity *= VELOCITY_WALK
	
	if Input.is_action_just_pressed( "pl_run_toggle" ):
		_run_toggle = !_run_toggle
	
	if Input.is_action_pressed( "pl_run" ) != _run_toggle: # If run is toggled on, run button walks. Otherwise, run button runs.
		velocity *= VELOCITY_RUN_MOD
	
	return velocity


# Check if there is an interaction available
func is_interact_enabled():
	return _interactable_body != null


# Set the current state to new_state
func set_state( new_state ):
	_on_state_end( _state )
	_state = new_state
	_on_state_begin( _state )


# Default State
func _state_default():
	# Get the motion
	var velocity = get_motion()
	
	# Update things that depend on the velocity's direction
	if velocity.length_squared() > 0:
		RotationHelper.rotation = velocity.angle()
		_update_animation_blendtree( velocity.normalized() )
	
	# Update the animation
	_update_animation_default( velocity.length_squared() )
	
	# Move the player
	velocity = move_and_slide( velocity )
	
	# Update the state if needed
	if Input.is_action_just_pressed( "pl_interact" ) and is_interact_enabled():
		_interactable_body.on_interact( self ) # Interactable bodies need an on_interact() method
	elif Input.is_action_just_pressed( "pl_melee" ):
		# Melee attack state
		set_state( State.MELEE )
	elif Input.is_action_just_pressed( "pl_ranged" ):
		# Ranged attack state
		pass
	
	# Update the camera
	Camera.set_camera_center( global_position )


# Melee State
func _state_melee():
	# Return to default after the animation ends
	if AnimationStateMachine.get_current_node() != "AttackMelee":
		set_state( State.DEFAULT )


# Scripted state (nothing happens, the player is under external control)
func _state_scripted():
	pass


# Begin a new state
func _on_state_begin( state ):
	match state:
		State.DEFAULT:
			pass
		
		State.MELEE:
			AnimationStateMachine.start( "AttackMelee" )
		
		State.SCRIPTED:
			AnimationStateMachine.start( "Idle" )
		
		_:
			pass


# Ends a state
func _on_state_end( state ):
	match state:
		State.DEFAULT:
			pass
		
		State.MELEE:
			pass
		
		State.SCRIPTED:
			pass
		
		_:
			pass


# Update the animation blendtrees so the right animations are picked
func _update_animation_blendtree( direction ):
	AnimationTree[ "parameters/Idle/blend_position" ] = direction
	AnimationTree[ "parameters/Walk/blend_position" ] = direction


# Update the animation in the default state
func _update_animation_default( vel_sq ):
	var desired_animation = "Idle"
	if vel_sq > 0:
		desired_animation = "Walk"
		
	if AnimationStateMachine.get_current_node() != desired_animation:
		AnimationStateMachine.travel( desired_animation )


# Acquire interactable body
# Assumption: Only one body will enter the area at a time
func _on_InteractionBox_body_entered( body ):
	_interactable_body = body


# Lose interactable body
# Assumption: Only one body will enter the area at a time
func _on_InteractionBox_body_exited( _body ):
	_interactable_body = null
