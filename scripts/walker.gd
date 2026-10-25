class_name Walker
extends CharacterBody3D
## Spielfigur in Ego-Perspektive für Station und Schiff.

const SPEED := 3.4
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var move_input := Vector2.ZERO   # x = seitwärts, y = vorwärts (+ = vor)
var look_delta := Vector2.ZERO
var _bob := 0.0

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.88, 0)
	add_child(cs)
	cam = Camera3D.new()
	cam.position = Vector3(0, 1.62, 0)
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	floor_snap_length = 0.3

func place(xf: Transform3D) -> void:
	global_position = xf.origin
	var f := -xf.basis.z
	yaw = atan2(-f.x, -f.z)
	pitch = 0.0
	velocity = Vector3.ZERO
	_apply_rot()

func _apply_rot() -> void:
	rotation = Vector3(0, yaw, 0)
	cam.rotation = Vector3(pitch, 0, 0)

func step(dt: float) -> void:
	yaw -= look_delta.x * 0.006
	pitch = clampf(pitch - look_delta.y * 0.005, -1.2, 1.2)
	look_delta = Vector2.ZERO
	_apply_rot()
	var mv := move_input
	if Input.is_physical_key_pressed(KEY_W): mv.y += 1
	if Input.is_physical_key_pressed(KEY_S): mv.y -= 1
	if Input.is_physical_key_pressed(KEY_A): mv.x -= 1
	if Input.is_physical_key_pressed(KEY_D): mv.x += 1
	if Input.is_physical_key_pressed(KEY_LEFT): yaw += dt * 2.0
	if Input.is_physical_key_pressed(KEY_RIGHT): yaw -= dt * 2.0
	mv = mv.limit_length(1.0)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var want := (fwd * mv.y + right * mv.x) * SPEED
	velocity.x = move_toward(velocity.x, want.x, dt * 20.0)
	velocity.z = move_toward(velocity.z, want.z, dt * 20.0)
	if not is_on_floor():
		velocity.y -= 9.8 * dt
	else:
		velocity.y = -0.5
	move_and_slide()
	if global_position.y < -5.0:
		global_position.y = 0.5
	var sp := Vector2(velocity.x, velocity.z).length()
	_bob += dt * sp * 2.6
	cam.position.y = 1.62 + sin(_bob) * 0.025 * clampf(sp / SPEED, 0.0, 1.0)

func look_dir() -> Vector3:
	return -cam.global_basis.z
