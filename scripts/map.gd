@tool

extends StaticBody3D

signal values_changed

# Map settings
@export var map_size: int = 256 : # Size of the map
	set(value):
		if value < 1:
			map_size = 1
		else:
			map_size = value
		values_changed.emit()
@export_range (0.0001, 20.0) var noise_scale: float = 0.3 :  # Controls the zoom of the noise
	set(value):
		if value <= 0:
			noise_scale = 0.0001
		else:
			noise_scale = value
		values_changed.emit()
@export var seed: int = 0 : # Seed for randomness
	set(value):
		seed = value
		values_changed.emit()
@export var normalize: bool = false :
	set(value):
		normalize = value
		values_changed.emit()
@export var apply_terrain: bool = false :
	set(value):
		apply_terrain = value
		values_changed.emit()
@export var amplitude: float = 1 :
	set(value):
		if value < 1:
			amplitude = 1
		else:
			amplitude = value
		values_changed.emit()
@export_range (0.000001, 1.0) var frequency: float = 0.01 : # Control to zoom in the noise
	set(value):
		frequency = value
		values_changed.emit()
@export var octaves: int = 1 :
	set(value):
		if value < 1:
			octaves = 1
		else:
			octaves = value
		values_changed.emit()
@export var persistance: float = 0.5 :
	set(value):
		persistance = value
		values_changed.emit()
@export var lacunarity: float = 2 :
	set(value):
		if value < 1:
			lacunarity = 1
		else:
			lacunarity = value
		values_changed.emit()

# FastNoiseLite settings
@export var noise:FastNoiseLite = FastNoiseLite.new()

@export var generate_:bool :
	set(value):
		if value:
			generate_mesh()

func _ready() -> void:
	pass
	
func generate_mesh() -> void:
	print("Generating Mesh...")

	var height_map = generate_noise_map()
	display_noise_map(height_map)

# Generate a 2D noise map
func generate_noise_map() -> Array:
	var noise_map: Array = []
	
	# Configure FastNoiseLite
	if seed > 0:
		noise.seed = seed
	else:
		noise.seed = randi() % 10000000

	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.set_fractal_octaves(octaves)
	noise.set_fractal_lacunarity(lacunarity)
	noise.set_fractal_gain(persistance)
	
	for x in range(map_size):
		var row: PackedFloat32Array = PackedFloat32Array()
		for y in range(map_size):
			
			var sampleX: float = float(x) / noise_scale
			var sampleY: float = float(y) / noise_scale
			
			var height = noise.get_noise_2d(sampleX, sampleY)
			if normalize:
				# Normalize the height value from [-1, 1] to [0, 1]
				height = (height + 1.0) * 0.5
			row.append(height)
		noise_map.append(row)
	
	return noise_map

func display_noise_map(noise_map: Array):
	var img = Image.create(map_size, map_size, false, Image.FORMAT_RGB8)
	
	for x in range(map_size):
		for y in range(map_size):
			var height = noise_map[x][y]
			
			var color = Color.BLACK.lerp(Color.WHITE, height)
			if apply_terrain:
				color = get_color_from_height(height)
			#var color = Color(adjusted_value, adjusted_value, adjusted_value)
			
			img.set_pixel(x, y, color)
	img.generate_mipmaps()

	# Create an ImageTexture and display it in a TextureRect
	var texture = ImageTexture.create_from_image(img)
	
	# Create a ShaderMaterial or StandardMaterial3D
	var shader_material = ShaderMaterial.new()
	shader_material.shader = Shader.new()

	shader_material.shader.code = """
	shader_type spatial;

	uniform sampler2D noise_texture: filter_nearest;

	void fragment() {
		vec4 tex_color = texture(noise_texture, UV);  // Use mesh UV coordinates
		ALBEDO = tex_color.rgb;
	}
	"""
	
	# Apply the generated texture to the shader
	shader_material.set_shader_parameter("noise_texture", texture)
	
	# Assign the ShaderMaterial to the MeshInstance3D
	$MeshInstance3D.material_override = shader_material
	# Scale the plane based on the noise map dimensions
	$MeshInstance3D.scale = Vector3(map_size, 1, map_size)

func get_color_from_height(height: float) -> Color:
	# Define color regions (adjust heights and colors as needed)
	var regions = [
			{ "height": 0, "color": Color(0.2, 0.4, 0.8) },  # Water
			{ "height": 0.1, "color": Color(0.9, 0.8, 0.5) },  # Sand
			{ "height": 0.5, "color": Color.FOREST_GREEN },  # Grass
			{ "height": 1, "color": Color.DARK_GREEN },  # Hills
		]
		
	if normalize:
		regions = [
			{ "height": 0.3, "color": Color(0.2, 0.4, 0.8) },  # Water
			{ "height": 0.35, "color": Color(0.9, 0.8, 0.5) },  # Sand
			{ "height": 0.7, "color": Color.FOREST_GREEN },  # Grass
			{ "height": 1, "color": Color.DARK_GREEN },  # Hills
		]
	
	for region in regions:
		if height <= region["height"]:
			return region["color"]
	return Color(0, 0, 0)  # Default color if none matches

func _on_values_changed() -> void:
	generate_mesh()
