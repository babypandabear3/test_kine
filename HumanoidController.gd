extends KinematicBody
class_name HumanoidController

signal swim_entered
signal walk_entered
signal fly_entered

enum mode_list {
	WALK,
	FLY,
	SWIM,
}

var mode = mode_list.WALK
var is_in_water = false

export (float) var water_level_normal = 0.0
export (float) var water_level_dead = -0.7

export (bool) var immune_floor_slippery = false
export (bool) var immune_floor_sticky = false
export (bool) var immune_no_jump = false
export (float) var body_align_rotation_speed = 6.0
export (bool) var body_align_floor_normal = false
export (float) var speed_h_max = 8.0
export (float) var speed_v_max = 20.0
export (float) var speed_acc = 50.0
export (float) var speed_deacc = 50.0

export (float) var slope_limit = 70.0
export (float) var slope_limit_low = 60.137

export (float) var jump_force = 14.0
export (int) var jump_limit = 2
export (float) var coyote_time = 0.2

export (float) var trampoline_force = 10.0

export (float) var gravity_force = 60.0
export (float) var gravity_acc_up = 35.0
export (float) var gravity_acc = 60.0
export (float) var gravity_scale = 1.0
export (float) var gravity_scale_glide = 0.3
export (float) var waterflow_speed = 120.0
export (float) var speed_evade_max = 360.0 * 2
export (float) var speed_evade_acc = 100.0

export (float) var slippery_max = 480.0
export (float) var slippery_deacc = 54.0
export (float) var sticky_max = 120.0

export (float) var swim_v_deacc = 52.0
export (float) var height = 1.80
export (float) var impulse_drag = 50.0

var speed_h = 0.0
var default_speed_acc = speed_acc
var default_speed_deacc = speed_deacc
var default_speed_h_max = speed_h_max
var gravity_vector_default = Vector3.DOWN
var gravity_vector = gravity_vector_default

var floor_normal = -gravity_vector_default
var floor_angle = 0.0

var jump_count = 0
var airborne = 0.0

var velocity = Vector3.ZERO
var direction = Vector3.ZERO
var prev_vel_h = Vector3.ZERO
var prev_vel_v = Vector3.ZERO

var velocity_h = Vector3.ZERO
var velocity_v = Vector3.ZERO

var horizontal_vector = Vector3.ZERO
var vertical_vector = gravity_vector

var snap_vector = Vector3.DOWN

var gravity_objs = []

var floor_rotation_val = 0.0
var floor_obj_prev = null
var floor_obj = null
var floor_prev_basis = null

var upward_force = Vector3.ZERO
var dict_floor_slippery = {}
var floor_slippery_val = 1.0

var dict_floor_sticky = {}
var jump_limit_default = jump_limit
var reset_velocity_v = false
var applied_jump_vector = Vector3.ZERO

var impulse = Vector3.ZERO
var applied_impulse = Vector3.ZERO
var altitude = 1.0

onready var water_level = $water_level

var wall_angle = 0.0
var wall_normal = Vector3.ZERO
var gravity_scale_default = gravity_scale

var is_drowning = false

var out_swim_timer_initial = 0.1
var out_swim_timer = 0.0

var prev_basis 
var prev_origin
var prev_rotation

var wall_obj = null

var half_up_speed = false
# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("no_wallrun")
	water_level.translation.y = water_level_normal

func _physics_process(delta):
	find_floor_obj()
	find_wall_obj()
	align_with_floor(delta)
	
	match mode:
		mode_list.WALK:
			walk_body(delta)
		mode_list.FLY:
			fly_body(delta)
		mode_list.SWIM:
			swim_body(delta)
	
	#check altitude
	altitude = get_altitude()
	if altitude > 0.0 :
		out_swim_timer -= delta
	else:
		out_swim_timer = out_swim_timer_initial
		
	if out_swim_timer > 0.0:
		is_in_water = true
		set_mode_swim()
	else:
		is_in_water = false
		set_mode_walk()
	
func get_altitude():
	#REPLACE WITH REAL LOGIC TO GET ALTITUDE OF BODY
	return 1.0
	
func find_floor_obj():
	floor_obj_prev = floor_obj
	if is_on_floor():
		for i in get_slide_count():
			var o = get_slide_collision(i)
			if rad2deg(o.normal.angle_to(-gravity_vector)) < (90.0 - slope_limit):
				floor_obj = o.collider
	else:
		floor_obj = null
	
func find_wall_obj():
	if is_on_wall():
		for i in get_slide_count():
			var o = get_slide_collision(i)
			if rad2deg(o.normal.angle_to(-gravity_vector)) >= (90.0 - slope_limit):
				wall_obj = o.collider
	else:
		wall_obj = null
		
func get_wall_obj():
	return wall_obj
	
func get_gravity_vector():
	return gravity_vector
	
func calc_angular_velocity(from_basis: Basis, to_basis: Basis) -> Vector3:
	var q1 = from_basis.get_rotation_quat()
	var q2 = to_basis.get_rotation_quat()

	# Quaternion that transforms q1 into q2
	var qt = q2 * q1.inverse()

	# Angle from quaternion
	var angle = 2 * acos(qt.w)

	# There are two distinct quaternions for any orientation.
	# Ensure we use the representation with the smallest angle.
	if angle > PI:
		qt = -qt
		angle = (TAU - angle)

	# Prevent divide by zero
	if angle < 0.0001:
		#return Vector3.ZERO
		angle = 0.0001

	# Axis from quaternion
	var axis = Vector3(qt.x, qt.y, qt.z) / sqrt(1-qt.w*qt.w)
	var ret = {"axis" : axis, "angle" : angle, "angular_velocity" : axis * angle}
	return ret
	
func align_with_floor(delta):
	if gravity_objs.size() == 0:
		gravity_vector = gravity_vector_default
	else:
		var gravity_obj = instance_from_id(gravity_objs.back())
		if gravity_obj:
			if gravity_obj.gravity_sphere:
				gravity_vector = global_transform.origin.direction_to(gravity_obj.global_transform.origin)
			elif gravity_obj.gravity_local_down:
				gravity_vector = -gravity_obj.global_transform.basis.y
		
	var y = -gravity_vector
	if body_align_floor_normal and is_on_floor():
		y = get_floor_normal()
	var z = global_transform.basis.z.slide(y).normalized()
	var x = y.cross(z)
			
	var a = Quat((global_transform.basis).orthonormalized())
	var b = Quat(Basis(x, y, z))
	var c = a.slerp(b, delta * body_align_rotation_speed)

	var new_bas = Basis(c).orthonormalized()
	global_transform.basis = new_bas
			
	
	floor_rotation_val = 0.0
	if floor_obj:
		if floor_obj != floor_obj_prev:
			floor_prev_basis = floor_obj.transform.basis
		else:
			var cur_basis = floor_obj.transform.basis
			floor_rotation_val = (floor_prev_basis.z).signed_angle_to(cur_basis.z, -gravity_vector)
			floor_prev_basis = floor_obj.transform.basis
	else:
		floor_rotation_val = 0.0
		floor_obj = null
		floor_prev_basis = null
		
	if is_on_floor() and floor_rotation_val != 0.0:
		rotation.y += floor_rotation_val
		
func calculate_floor_angle():
	if is_on_floor():
		return rad2deg(get_floor_angle())
	else:
		return 0.0

func calculate_floor_normal():
	var n = -gravity_vector
	if is_on_floor():
		n = get_floor_normal()
	return n


	
func walk_body(delta):
	floor_normal = calculate_floor_normal()
	floor_angle = calculate_floor_angle()
	var vel_h = Vector3.ZERO
	var vel_v = Vector3.ZERO
	
	var input_velocity = Vector3.ZERO
	if not direction.is_equal_approx(Vector3.ZERO):
		input_velocity = direction * speed_acc * delta
		
	vertical_vector = gravity_vector
	snap_vector = gravity_vector
	
	if is_on_floor():
		#if floor_angle <= slope_limit:
		if floor_angle <= slope_limit_low:
			input_velocity = input_velocity.slide(floor_normal)
			snap_vector = -floor_normal
			vertical_vector = -floor_normal
		else:
			input_velocity = input_velocity.slide(-gravity_vector)
			snap_vector = gravity_vector
			vertical_vector = gravity_vector
		
	else:
		snap_vector = Vector3.ZERO
	
	velocity += input_velocity
	
	#speed_limit
	if velocity.length() > speed_h_max:
		vel_h = velocity.slide(-gravity_vector) * 0.9
		vel_v = velocity.project(-gravity_vector)
		if half_up_speed: #IF JUMP RELEASED, HALVES VERTICAL VELOCITY
			if vel_v.dot(-gravity_vector) > 0:
				vel_v *= 0.5
			half_up_speed = false
		velocity = vel_h + vel_v
	
	#slow down horizontally when no input
	if direction.is_equal_approx(Vector3.ZERO):
		vel_h = velocity.slide(-gravity_vector)
		vel_v = velocity.project(-gravity_vector)
		vel_h *= 0.8
		velocity = vel_h + vel_v
		
	#different gravity when jump up and fall down
	var gravity_applied = vertical_vector * (delta * gravity_acc * gravity_scale)
	if velocity.dot(vertical_vector) < 0.0:
		gravity_applied = vertical_vector * (delta * gravity_acc_up * gravity_scale)
	
	if gravity_scale != gravity_scale_default:
		vel_v = velocity.project(-gravity_vector)
		vel_h = velocity.slide(-gravity_vector)
		if vel_v.length() > 2.0:
			vel_v *= 0.9
		velocity = vel_h + vel_v
		
	if reset_velocity_v == true:
		velocity = velocity.slide(-gravity_vector)
		reset_velocity_v = false
		
	#to prevent player climbing angled wall
	
	if is_on_wall():
		var colinfo = get_last_slide_collision()
		wall_normal = colinfo.normal
		wall_angle = rad2deg(-gravity_vector.angle_to(wall_normal))
	else:
		wall_normal = Vector3.ZERO
		wall_angle = 0.0
	
	#jump force
	if not applied_jump_vector.is_equal_approx(Vector3.ZERO):
		velocity = velocity.slide(-gravity_vector)
		velocity += applied_jump_vector
		applied_jump_vector = Vector3.ZERO
		snap_vector = Vector3.ZERO
		
	#limit vertical speed
	vel_h = velocity.slide(-gravity_vector)
	vel_v = velocity.project(-gravity_vector)
	if vel_v.length() > speed_v_max:
		vel_v *= 0.9
	velocity = vel_h + vel_v
	
	#Stopping player to climb steep slope
	#if is_on_floor() or is_on_wall():
	#	var slide_stop = false
	#	if wall_angle < -91.0 or wall_angle > 91.0:
	#		slide_stop = true
	#	if floor_angle > slope_limit:
	#		slide_stop = true
	#	if slide_stop:
	#		vel_h = velocity.slide(-gravity_vector)
	#		var len_vel_h = vel_h.length()
	#		if wall_angle > 91.0 or wall_angle < -91.0:
	#			snap_vector = gravity_vector.slide(wall_normal)
	#		vel_v = snap_vector * len_vel_h
	#		velocity = vel_h + vel_v
			
	
	#upward force
	if gravity_scale == gravity_scale_glide:
		velocity += upward_force
		
	velocity += gravity_applied
	
	#impulse
	if not impulse.is_equal_approx(Vector3.ZERO):
		applied_impulse += impulse
		impulse = Vector3.ZERO
		snap_vector = Vector3.ZERO
	
	velocity = move_and_slide_with_snap(velocity + applied_impulse, snap_vector, -gravity_vector, true, 4, deg2rad(slope_limit), false)
	
	#drag for impulse
	applied_impulse *= delta * impulse_drag
	
	#setting up variables
	if is_on_floor():
		jump_count = 0
		call_deferred("reset_airborne")
	else:
		airborne += delta
		if airborne > coyote_time and jump_count == 0:
			jump_count += 1
	
func fly_body(delta):
	var input_velocity = Vector3.ZERO
	if not direction.is_equal_approx(Vector3.ZERO):
		input_velocity = direction * speed_acc * delta
		
	velocity += input_velocity
	
	#speed_limit
	if velocity.length() > speed_h_max:
		velocity *= 0.9
	
	#slow down horizontally when no input
	if direction.is_equal_approx(Vector3.ZERO):
		velocity *= 0.8
		
	velocity = move_and_slide(velocity, -gravity_vector)

func swim_body(delta):
	var input_velocity = Vector3.ZERO
	if not direction.is_equal_approx(Vector3.ZERO):
		input_velocity = direction.slide(-gravity_vector) * speed_acc * delta
		
	velocity += input_velocity
	
	var vel_h = velocity.slide(-gravity_vector) 
	var vel_v = velocity.project(-gravity_vector) * 0.86
	velocity = vel_h + vel_v
		
	#speed_limit
	if velocity.length() > speed_h_max:
		vel_h = velocity.slide(-gravity_vector) * 0.9
		vel_v = velocity.project(-gravity_vector)
		velocity = vel_h + vel_v
	
	#slow down horizontally when no input
	if direction.is_equal_approx(Vector3.ZERO):
		vel_h = velocity.slide(-gravity_vector)
		vel_v = velocity.project(-gravity_vector)
		vel_h *= 0.8
		velocity = vel_h + vel_v
		
	var water_upward_force = Vector3.ZERO
	if altitude < -0.1:
		water_upward_force = (gravity_vector * altitude * 16.0 * delta)
		
	if is_drowning:
		velocity += gravity_vector * delta * 8.0
	else:
		velocity += water_upward_force
	
	velocity = move_and_slide(velocity, -gravity_vector)
	
func set_direction(par):
	direction = par
	
func get_wall_normal():
	return wall_normal
	
func get_wall_angle():
	return wall_angle
	
func body_on_ceiling():
	return is_on_ceiling()
	
func body_on_wall():
	return is_on_wall()
	
func body_on_floor():
	return is_on_floor()
	
func body_is_airborne():
	if airborne > 0.0:
		return true
	else:
		return false 
		
func body_in_water():
	return is_in_water

func overwrite_velocity_h(pdirection): #THIS FUNCTION IS NEEDED FOR WALLJUMP
	direction = pdirection
	velocity = direction * speed_h_max * get_physics_process_delta_time()

func reduce_velocity(): 
	#THIS IS WORKAROUND FOR LAND STATE, SO IT DOESN'T FEEL TOO SLIPPERY WHEN LANDING
	velocity *= 0.9
	
func clear_velocity_h():
	velocity_h = Vector3.ZERO
	prev_vel_h = Vector3.ZERO
	
func clear_velocity_v():
	velocity_v = Vector3.ZERO
	prev_vel_v = Vector3.ZERO
		
func allow_jump():
	if is_on_floor() and rad2deg(get_floor_angle()) > slope_limit_low:
		return false
	if jump_count < jump_limit:
		return true
	else:
		return false

func jump():
	applied_jump_vector = -gravity_vector * jump_force
	jump_count += 1
	reset_velocity_v = true
	
func trampoline():
	apply_central_impulse(-gravity_vector * trampoline_force)
	jump_count += 1
	reset_velocity_v = true

func set_gravity_scale_glide():
	gravity_scale = gravity_scale_glide

func reset_gravity_scale():
	gravity_scale = 1.0

func set_speed_evade():
	speed_h_max = speed_evade_max
	speed_acc = speed_evade_acc
	
func reset_speed_max():
	speed_h_max = default_speed_h_max
	speed_acc = default_speed_acc
	speed_deacc = default_speed_deacc

func signal_in_gravity_dir(par, append):
	if append:
		gravity_objs.append(par.get_instance_id())
	else:
		gravity_objs.erase(par.get_instance_id())
		

func signal_in_upward_force(force):
	upward_force += force

func signal_in_floor_slippery(sysout_id, val):
	if immune_floor_slippery:
		return
		
	if val:
		dict_floor_slippery[sysout_id] = val
	else:
		dict_floor_slippery.erase(sysout_id)
		
	if dict_floor_slippery.keys().size() > 0:
		speed_h_max = slippery_max
		speed_deacc = slippery_deacc
	else:
		speed_h_max = default_speed_h_max
		speed_deacc = default_speed_deacc

func signal_in_floor_sticky(sysout_id, val):
	if immune_floor_sticky:
		return
	if val:
		dict_floor_sticky[sysout_id] = val
	else:
		dict_floor_sticky.erase(sysout_id)
		
	if dict_floor_sticky.keys().size() > 0:
		speed_h_max = sticky_max
	else:
		speed_h_max = default_speed_h_max

func set_jump_count(par):
	jump_count = par
	
func signal_in_no_jump(no_jump):
	if immune_no_jump:
		return
	if no_jump:
		jump_limit = 0
	else:
		jump_limit = jump_limit_default

func apply_central_impulse(par):
	impulse = par

func set_mode_walk():
	if mode != mode_list.WALK:
		mode = mode_list.WALK
		emit_signal("walk_entered")
	
func set_mode_swim():
	if mode != mode_list.SWIM:
		mode = mode_list.SWIM
		emit_signal("swim_entered")
	
func set_mode_fly():
	if mode != mode_list.FLY:
		mode = mode_list.FLY
		emit_signal("fly_entered")

func set_waterlevel(par):
	water_level.translation.y = par
	
func set_waterlevel_dead():
	water_level.translation.y = water_level_dead

func set_alternate_speed(par):
	speed_h_max = par

func reset_airborne():
	airborne = 0.0

func get_body_horizontal_vector():
	return horizontal_vector

func drown(par):
	is_drowning = par

func halves_upward_speed():
	half_up_speed = true
