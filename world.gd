extends Spatial

var count = 0

onready var lbl_fps = $FPS
onready var lbl_count = $instance_count

onready var i_root = $Navigation/instance_root
onready var char_i = preload("res://character.tscn")

func _ready():
	randomize()

func _process(_delta):
	lbl_fps.text = "FPS : " + str(Engine.get_frames_per_second())
	if Input.is_action_just_released("ui_accept"):
		for i in 5:
			var o = char_i.instance()
			var x = rand_range(-10,10)
			var z = rand_range(-10,10)
			var offset = Vector3(x, 0, z)
			i_root.add_child(o)
			o.global_transform.origin += offset
			update_count()
		
func update_count():
	count += 1
	lbl_count.text = "count : " + str(count)

	
