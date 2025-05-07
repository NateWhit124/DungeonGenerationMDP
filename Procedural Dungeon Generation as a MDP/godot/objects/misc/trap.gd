extends Area2D

@export var down_interval : float = 1
@export var up_interval : float = 1
var traps_on : bool = false : set = set_traps_on

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimatedSprite2D.animation = "spikes_down"
	$AnimatedSprite2D.frame = 4
	monitoring = false
	$DownTimer.wait_time = down_interval
	$UpTimer.wait_time = up_interval
	if traps_on:
		$DownTimer.start()

func set_traps_on(newval : bool):
	traps_on = newval
	if traps_on:
		$DownTimer.start()
	else:
		$UpTimer.stop()
		$DownTimer.stop()
		$AnimatedSprite2D.animation = "spikes_down"
		$AnimatedSprite2D.frame = 4
		monitoring = false
		$DownTimer.wait_time = down_interval
		$UpTimer.wait_time = up_interval

func _on_down_timer_timeout() -> void:
	$AnimatedSprite2D.play("spikes_up")

func _on_up_timer_timeout() -> void:
	$AnimatedSprite2D.play("spikes_down")

func _on_animated_sprite_2d_frame_changed() -> void:
	if $AnimatedSprite2D.animation == "spikes_up" && $AnimatedSprite2D.frame == 4:
		monitoring = true
	elif $AnimatedSprite2D.animation == "spikes_down" && $AnimatedSprite2D.frame == 2:
		monitoring = false

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(self, 3)

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "spikes_up":
		$UpTimer.start()
	if $AnimatedSprite2D.animation == "spikes_down":
		$DownTimer.start()
