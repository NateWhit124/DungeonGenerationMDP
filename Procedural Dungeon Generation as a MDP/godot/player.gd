extends CharacterBody2D

const SPEED = 150.0
const ROOM_TRANSLATIONS : Dictionary = {
	"up" : Vector2(0,-224),
	"down" : Vector2(0,224),
	"left" : Vector2(-384,0),
	"right" : Vector2(384,0),
}
@export var camera_nodepath : NodePath
@export var total_health : float = 10 : set = set_total_health
@export var attack_power : float = 1.0 : set = set_attack_power

var camera_ref : Camera2D
var health : float = 3 : set = set_health
var is_stunned : bool = false : set = set_is_stunned
var knockback_target : Vector2
var is_attacking : bool = false
var attack_interval : float = 1.0
var is_moving_rooms : bool = false
var flip_h : bool = false : set = set_flip_h

var openable_chest : StaticBody2D = null : set = set_openable_chest

func _ready() -> void:
	$AttackTimer.wait_time = attack_interval
	health = total_health
	%HealthBar.max_value = total_health
	%HealthBar.value = health
	%AttackValue.text = "%.1f" % attack_power
	if camera_nodepath:
		camera_ref = get_node(camera_nodepath)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		attack()
	if Input.is_action_just_pressed("interact") && openable_chest != null:
		%OpenChestLabel.hide()
		var new_item : Item = openable_chest.open()
		var old_value = get(new_item.affects_property)
		set(new_item.affects_property, old_value + new_item.effect_amount)

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction and !is_stunned:
		velocity = direction * SPEED
		if direction.x < 0: flip_h = true
		else: flip_h = false
	elif is_stunned:
		velocity = velocity.move_toward(Vector2(0,0),SPEED/5.0)
		if velocity == Vector2(0,0):
			is_stunned = false
	else:
		velocity = velocity.move_toward(Vector2(0,0),SPEED)
	
	move_and_slide()

func attack():
	$AnimatedSprite2D.play("attack")
	$AttackTimer.start()

func take_damage(from, amount):
	if !is_stunned:
		velocity += max(2,amount) * SPEED * (global_position - from.global_position).normalized()
		health -= amount
		is_stunned = true

func set_total_health(newval : float):
	total_health = newval
	%HealthBar.max_value = total_health
	%HealthValue.text = "%.1f / %.1f" % [health, total_health]

func set_health(newval : float):
	health = newval
	%HealthBar.value = health
	%HealthValue.text = "%.1f / %.1f" % [health, total_health]

func set_attack_power(newval : float):
	attack_power = newval
	if is_node_ready():
		%AttackValue.text = "%.1f" % attack_power

func set_is_stunned(newval : bool):
	is_stunned = newval
	if is_stunned:
		$AnimatedSprite2D.material.set_shader_parameter("do_flash",true)
	else:
		$AnimatedSprite2D.material.set_shader_parameter("do_flash",false)

func set_flip_h(newval : bool):
	if flip_h != newval:
		$HurtBox1/CollisionShape2D2.position.x = -$HurtBox1/CollisionShape2D2.position.x
		$HurtBox2/CollisionShape2D2.position.x = -$HurtBox2/CollisionShape2D2.position.x
		$HitBox/CollisionShape2D.position.x = -$HitBox/CollisionShape2D.position.x
		$AnimatedSprite2D.offset.x = -$AnimatedSprite2D.offset.x
	flip_h = newval
	$AnimatedSprite2D.flip_h = flip_h

func set_openable_chest(chest : StaticBody2D):
	openable_chest = chest
	if openable_chest != null:
		%OpenChestLabel.show()
	else:
		%OpenChestLabel.hide()

func _on_animated_sprite_2d_frame_changed() -> void:
	if $AnimatedSprite2D.animation == "attack":
		if $AnimatedSprite2D.frame == 4:
			$HurtBox1.monitoring = true
		elif $AnimatedSprite2D.frame == 5:
			$HurtBox2.monitoring = true
	else:
		$HurtBox1.monitoring = false
		$HurtBox2.monitoring = false

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "attack":
		is_attacking = false
		$AnimatedSprite2D.play("idle")

func _on_hurt_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		area.get_parent().take_damage(self, attack_power)

func _on_room_debounce_timer_timeout() -> void:
	is_moving_rooms = false
