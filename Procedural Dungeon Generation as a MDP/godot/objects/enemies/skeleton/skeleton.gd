extends CharacterBody2D

@export var SPEED : float = 50.0
@export var total_health : float = 3
@export var attack_strength : float = 1.0

var health : float = 3 : set = set_health
var player_ref : CharacterBody2D = null
var attack_interval : float = 1.0
var is_attacking : bool = false
var flip_h : bool = false : set = set_flip_h
var is_stunned : bool = false : set = set_is_stunned
var is_dead : bool = false

func _ready() -> void:
	$AttackTimer.wait_time = attack_interval
	health = total_health

func _physics_process(delta: float) -> void:
	var direction : Vector2
	
	if player_ref:
		direction = (player_ref.global_position - global_position).normalized()
	if direction && !is_attacking and !is_stunned and !is_dead:
		velocity = direction * SPEED
		$AnimatedSprite2D.play("move")
		if direction.x < 0: flip_h = true
		else: flip_h = false
	elif is_stunned:
		velocity = velocity.move_toward(Vector2(0,0),SPEED/5.0)
		if velocity == Vector2(0,0):
			is_stunned = false
	else:
		velocity = velocity.move_toward(Vector2(0,0), SPEED)
		if !is_attacking and !is_dead: $AnimatedSprite2D.play("idle")

	move_and_slide()

func attack():
	$AnimatedSprite2D.play("attack")
	$AttackTimer.start()

func take_damage(from, amount):
	if !is_stunned && !is_dead:
		velocity += 500 * float(amount)/float(total_health) * (global_position - from.global_position).normalized()
		health -= amount
		if !is_dead: $AnimatedSprite2D.play("take_damage")
		is_stunned = true

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
	flip_h = newval
	$AnimatedSprite2D.flip_h = flip_h

func set_health(newval : float):
	health = newval
	if health <= 0:
		die()

func die():
	is_dead = true
	is_stunned = false
	is_attacking = false
	$AnimatedSprite2D.play("death")
	

func _on_detection_area_area_entered(body: Node2D) -> void:
	if body.is_in_group("player_hitbox"):
		player_ref = body.get_parent()

func _on_detection_area_area_exited(body: Node2D) -> void:
	if body.is_in_group("player_hitbox"):
		player_ref = null

func _on_attack_range_area_entered(body: Node2D) -> void:
	if !is_dead && body.is_in_group("player_hitbox"):
		if !is_attacking:
			is_attacking = true
			attack()

func _on_attack_range_area_exited(body: Node2D) -> void:
	if body.is_in_group("player_hitbox"):
		is_attacking = false

func _on_hurt_box_area_entered(body: Node2D) -> void:
	if body.is_in_group("player_hitbox"):
		body.get_parent().take_damage(self, attack_strength)

func _on_animated_sprite_2d_frame_changed() -> void:
	if $AnimatedSprite2D.animation == "attack":
		if $AnimatedSprite2D.frame == 6:
			$HurtBox1.monitoring = true
		elif $AnimatedSprite2D.frame == 7:
			$HurtBox2.monitoring = true
	else:
		$HurtBox1.monitoring = false
		$HurtBox2.monitoring = false

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "death":
		var fade_tween = create_tween()
		fade_tween.tween_property($AnimatedSprite2D, "modulate:a", 0, 1.0)
		await fade_tween.finished
		queue_free()

func _on_attack_timer_timeout() -> void:
	if is_attacking and !is_dead:
		attack()
