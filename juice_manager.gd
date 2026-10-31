class_name JuiceManager
extends RefCounted

## Small, reusable presentation effects for gameplay feedback.

const FREEZE_RECOVERY_DURATION := 0.12
const FREEZE_STEPS := 8

static var _flash_shader: Shader
static var _freeze_active := false


static func flash_white(sprite: CanvasItem, duration: float) -> Tween:
	if not is_instance_valid(sprite):
		return null

	var original_material: Material = sprite.material
	var flash_material := ShaderMaterial.new()
	flash_material.shader = _get_flash_shader()
	flash_material.set_shader_parameter("flash_amount", 1.0)
	sprite.material = flash_material

	var tween := sprite.create_tween()
	tween.tween_property(flash_material, "shader_parameter/flash_amount", 0.0, maxf(duration, 0.01))
	tween.tween_callback(func() -> void:
		if is_instance_valid(sprite) and sprite.material == flash_material:
			sprite.material = original_material
	)
	return tween


static func squash_and_stretch(node: Node2D, target_scale: Vector2, duration: float) -> Tween:
	if not is_instance_valid(node):
		return null

	var original_scale := node.scale
	var effect_duration := maxf(duration, 0.02)
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", target_scale, effect_duration * 0.4)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", original_scale, effect_duration * 0.6)
	return tween


## Brief hit-stop. The timers must ignore Engine.time_scale (4th argument),
## otherwise they never fire while time_scale is 0 and the game freezes forever.
static func freeze_frame(duration: float) -> void:
	if _freeze_active:
		return

	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return

	_freeze_active = true
	Engine.time_scale = 0.0
	await scene_tree.create_timer(maxf(duration, 0.01), true, false, true).timeout

	var step_duration := FREEZE_RECOVERY_DURATION / float(FREEZE_STEPS)
	for step in range(1, FREEZE_STEPS + 1):
		await scene_tree.create_timer(step_duration, true, false, true).timeout
		var progress := float(step) / float(FREEZE_STEPS)
		Engine.time_scale = smoothstep(0.0, 1.0, progress)

	Engine.time_scale = 1.0
	_freeze_active = false


static func _get_flash_shader() -> Shader:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = """
shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex_color.rgb, vec3(1.0), flash_amount), tex_color.a);
}
"""
	return _flash_shader
