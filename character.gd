extends Spatial

var current_ai = 0
var timer = 0
var dir = Vector3.ZERO


onready var body = $HumanoidController
# Called when the node enters the scene tree for the first time.
func _ready():
	prepare()
	
func prepare():
	timer = rand_range(2.0,4.0)
	if current_ai == 0:
		dir = Vector3.ZERO
	else:
		var x = rand_range(-1,1)
		var z = rand_range(-1,1)
		dir = Vector3(x, 0, z).normalized()



func _physics_process(delta):
	timer -= delta
	
	if timer < 0:
		current_ai += 1
		if current_ai > 1:
			current_ai = 0
			
		prepare()
		
		
	body.set_direction(dir)
	
