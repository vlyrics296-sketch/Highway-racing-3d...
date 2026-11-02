extends Node3D

const LANES := [-3.2, 0.0, 3.2]
const SEGMENT_LENGTH := 100.0
const SEGMENT_COUNT := 6

var player: Node3D
var camera: Camera3D
var road_segments: Array[Node3D] = []
var traffic: Array[Node3D] = []
var coins: Array[Node3D] = []
var speed := 34.0
var base_speed := 34.0
var distance := 0.0
var score := 0
var coin_count := 0
var game_over := false
var lane_target := 1
var steer := 0.0
var nitro_time := 0.0
var spawn_timer := 0.0
var coin_timer := 0.0
var hud: Label
var score_label: Label
var speed_label: Label
var message_label: Label
var left_button: Button
var right_button: Button
var brake_button: Button
var nitro_button: Button
var left_held := false
var right_held := false
var brake_held := false
var nitro_held := false

func _ready() -> void:
	_make_environment()
	_make_road()
	_make_player()
	_make_camera()
	_make_lighting()
	_make_ui()
	for i in range(7):
		_spawn_traffic(-55.0 - i * 48.0)
	for i in range(10):
		_spawn_coin(-35.0 - i * 24.0)

func _process(delta: float) -> void:
	if game_over:
		return
	var desired_speed := base_speed
	if brake_held:
		desired_speed = 13.0
	if nitro_held and nitro_time <= 0.0:
		nitro_time = 2.8
	if nitro_time > 0.0:
		nitro_time -= delta
		desired_speed = 58.0
	speed = move_toward(speed, desired_speed, 28.0 * delta)
	var input_dir := float(right_held or Input.is_action_pressed("move_right")) - float(left_held or Input.is_action_pressed("move_left"))
	if input_dir != 0.0:
		lane_target = clampi(lane_target + int(sign(input_dir)), 0, 2)
	var target_x := LANES[lane_target]
	player.position.x = move_toward(player.position.x, target_x, 8.5 * delta)
	player.rotation.z = lerp(player.rotation.z, -(target_x - player.position.x) * 0.08, 8.0 * delta)
	player.position.z -= speed * delta
	distance += speed * delta
	for segment in road_segments:
		if segment.position.z - player.position.z > SEGMENT_LENGTH:
			segment.position.z -= SEGMENT_LENGTH * SEGMENT_COUNT
	for car in traffic:
		car.position.z += (speed - 17.0) * delta
		if car.position.z > player.position.z + 15.0:
			car.queue_free()
			traffic.erase(car)
			_spawn_traffic(player.position.z - randf_range(170.0, 300.0))
		elif absf(car.position.x - player.position.x) < 1.65 and absf(car.position.z - player.position.z) < 4.1:
			_end_game()
	for coin in coins:
		coin.rotate_y(2.8 * delta)
		coin.position.z += (speed - 17.0) * delta
		if absf(coin.position.x - player.position.x) < 1.45 and absf(coin.position.z - player.position.z) < 3.0:
			coin_count += 1
			score += 100
			coin.queue_free()
			coins.erase(coin)
		elif coin.position.z > player.position.z + 12.0:
			coin.queue_free()
			coins.erase(coin)
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_traffic(player.position.z - randf_range(180.0, 260.0))
		spawn_timer = randf_range(1.7, 2.8)
	coin_timer -= delta
	if coin_timer <= 0.0:
		_spawn_coin(player.position.z - randf_range(100.0, 180.0))
		coin_timer = 1.0
	camera.position = camera.position.lerp(Vector3(player.position.x * 0.42, 7.5, player.position.z + 13.5), 4.0 * delta)
	camera.look_at(Vector3(player.position.x * 0.65, 1.0, player.position.z - 9.0), Vector3.UP)
	_update_hud()

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.30, 0.52)
	sky_mat.sky_horizon_color = Color(0.78, 0.83, 0.88)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

func _make_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

func _mat(color: Color, metallic := 0.0, roughness := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh

func _make_road() -> void:
	var asphalt := _mat(Color(0.105, 0.115, 0.13), 0.05, 0.88)
	var line_mat := _mat(Color(0.92, 0.91, 0.78), 0.0, 0.8)
	var grass := _mat(Color(0.16, 0.34, 0.17), 0.0, 1.0)
	var rail := _mat(Color(0.55, 0.60, 0.64), 0.72, 0.3)
	for n in range(SEGMENT_COUNT):
		var seg := Node3D.new()
		seg.position.z = -n * SEGMENT_LENGTH
		add_child(seg)
		_box(seg, Vector3(11.5, 0.18, SEGMENT_LENGTH), Vector3(0, -0.12, -SEGMENT_LENGTH / 2), asphalt)
		_box(seg, Vector3(36, 0.12, SEGMENT_LENGTH), Vector3(0, -0.28, -SEGMENT_LENGTH / 2), grass)
		for x in [-1.6, 1.6]:
			for z in range(0, 10):
				_box(seg, Vector3(0.12, 0.025, 5.2), Vector3(x, 0.0, -z * 10.0 - 5.0), line_mat)
		for x in [-5.9, 5.9]:
			_box(seg, Vector3(0.18, 0.75, SEGMENT_LENGTH), Vector3(x, 0.35, -SEGMENT_LENGTH / 2), rail)
		road_segments.append(seg)

func _make_car(parent: Node3D, color: Color, is_player := false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var body_mat := _mat(color, 0.62, 0.26)
	var glass := _mat(Color(0.045, 0.09, 0.13), 0.35, 0.16)
	var tire := _mat(Color(0.018, 0.02, 0.024), 0.0, 0.95)
	_box(root, Vector3(1.85, 0.62, 3.7), Vector3(0, 0.72, 0), body_mat)
	_box(root, Vector3(1.42, 0.68, 1.75), Vector3(0, 1.28, -0.25), glass)
	_box(root, Vector3(1.92, 0.13, 0.85), Vector3(0, 1.02, -1.28), body_mat)
	for x in [-0.94, 0.94]:
		for z in [-1.18, 1.18]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.38
			cylinder.bottom_radius = 0.38
			cylinder.height = 0.22
			wheel.mesh = cylinder
			wheel.position = Vector3(x, 0.42, z)
			wheel.rotation.z = PI / 2
			wheel.material_override = tire
			root.add_child(wheel)
	if is_player:
		var spoiler := _box(root, Vector3(1.9, 0.12, 0.35), Vector3(0, 1.25, 1.55), body_mat)
		spoiler.rotation.x = -0.08
	return root

func _make_player() -> void:
	player = _make_car(self, Color(0.82, 0.055, 0.035), true)
	player.position = Vector3(0, 0, 0)

func _make_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 7.5, 13.5)
	camera.fov = 72
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0, 1, -9), Vector3.UP)

func _spawn_traffic(z_pos: float) -> void:
	var lane := randi_range(0, 2)
	var colors := [Color(0.08,0.28,0.78), Color(0.78,0.72,0.12), Color(0.18,0.52,0.28), Color(0.58,0.58,0.62)]
	var car := _make_car(self, colors[randi_range(0, colors.size()-1)])
	car.position = Vector3(LANES[lane], 0, z_pos)
	traffic.append(car)

func _spawn_coin(z_pos: float) -> void:
	var coin := Node3D.new()
	add_child(coin)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.58
	cylinder.bottom_radius = 0.58
	cylinder.height = 0.12
	mesh.mesh = cylinder
	mesh.rotation.x = PI / 2
	mesh.material_override = _mat(Color(1.0, 0.68, 0.04), 0.8, 0.2)
	coin.add_child(mesh)
	coin.position = Vector3(LANES[randi_range(0,2)], 1.35, z_pos)
	coins.append(coin)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui_root := Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_root)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.025, 0.04, 0.55)
	panel.position = Vector2(18, 18)
	panel.size = Vector2(310, 112)
	ui_root.add_child(panel)
	hud = Label.new()
	hud.position = Vector2(32, 26)
	hud.add_theme_font_size_override("font_size", 24)
	ui_root.add_child(hud)
	score_label = Label.new()
	score_label.position = Vector2(32, 60)
	score_label.add_theme_font_size_override("font_size", 19)
	ui_root.add_child(score_label)
	speed_label = Label.new()
	speed_label.position = Vector2(32, 88)
	speed_label.add_theme_font_size_override("font_size", 17)
	ui_root.add_child(speed_label)
	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 34)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	ui_root.add_child(message_label)
	left_button = _add_button(ui_root, "◀", Vector2(30, -145), Vector2(100, 100))
	right_button = _add_button(ui_root, "▶", Vector2(145, -145), Vector2(100, 100))
	brake_button = _add_button(ui_root, "BRAKE", Vector2(-250, -145), Vector2(105, 85))
	nitro_button = _add_button(ui_root, "NITRO", Vector2(-130, -145), Vector2(105, 85))
	left_button.button_down.connect(func(): left_held = true)
	left_button.button_up.connect(func(): left_held = false)
	right_button.button_down.connect(func(): right_held = true)
	right_button.button_up.connect(func(): right_held = false)
	brake_button.button_down.connect(func(): brake_held = true)
	brake_button.button_up.connect(func(): brake_held = false)
	nitro_button.button_down.connect(func(): nitro_held = true)
	nitro_button.button_up.connect(func(): nitro_held = false)
	_update_hud()

func _add_button(parent: Control, label_text: String, offset: Vector2, button_size: Vector2) -> Button:
	var b := Button.new()
	b.text = label_text
	b.size = button_size
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _button_style(Color(0.02,0.04,0.07,0.72)))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.12,0.42,0.72,0.9)))
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position = offset
	parent.add_child(b)
	return b

func _button_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 18
	s.corner_radius_top_right = 18
	s.corner_radius_bottom_left = 18
	s.corner_radius_bottom_right = 18
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.7,0.85,1,0.65)
	return s

func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	hud.text = "HIGHWAY RACING 3D"
	score_label.text = "Score: %d    Coins: %d" % [score + int(distance / 2.0), coin_count]
	speed_label.text = "Speed: %d km/h" % int(speed * 3.2)

func _end_game() -> void:
	game_over = true
	message_label.text = "CRASH!\nScore: %d\nTap RESTART" % [score + int(distance / 2.0)]
	var restart := Button.new()
	restart.text = "RESTART"
	restart.size = Vector2(180, 70)
	restart.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	restart.position += Vector2(-90, 105)
	restart.add_theme_font_size_override("font_size", 24)
	restart.pressed.connect(_restart)
	message_label.get_parent().add_child(restart)

func _restart() -> void:
	get_tree().reload_current_scene()
