package sky

import "vendor:sdl2"
import stb "vendor:stb/image"
import gl "vendor:OpenGL"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"

import "../skeewb"
import "../util"

mat4 :: glm.mat4x4
vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

Render :: struct{
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	texture: u32,
}

quadVertices := [?]f32{
	// positions   // texCoords
	-1.0,  1.0, // 0.0, 1.0,
	-1.0, -1.0, // 0.0, 0.0,
	 1.0, -1.0, // 1.0, 0.0,
 
	-1.0,  1.0, // 0.0, 1.0,
	 1.0, -1.0, // 1.0, 0.0,
	 1.0,  1.0, // 1.0, 1.0
}

model: mat4

sunDirection := vec3{0, 1, 0}

setup :: proc(core: ^skeewb.core_interface, camera: ^util.Camera, render: ^Render) {
	gl.GenVertexArrays(1, &render.vao)
	gl.BindVertexArray(render.vao)

	gl.GenBuffers(1, &render.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, render.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 2 * size_of(f32), 0)

	vertShader := core.resource_load("sky_vert", "basalt/assets/shaders/sky_vert.glsl")
	fragShader := core.resource_load("sky_frag", "basalt/assets/shaders/sky_frag.glsl")

	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(core.resource_string(vertShader), core.resource_string(fragShader))

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile sky shaders\n %s\n %s", a, c)
    }
	
	//gl.UseProgram(render.program)
	render.uniforms = gl.get_uniforms_from_program(render.program)
}

dayTime: f32 = 1200000
skyBlue := vec3{0.4666, 0.6588, 1.0}
fogBlue := vec3{0.6666, 0.8156, 0.9921};
skyColor := skyBlue
fogColor := fogBlue

draw :: proc(camera: ^util.Camera, render: Render, time: f32) {
	cycle := math.fract(time / dayTime)
	angle := 2 * math.PI * cycle
	brightness: f32 = clamp(math.cos(angle) * 2 + 0.5, 0, 1)
	skyColor = skyBlue
	fogColor = fogBlue
	skyColor *= brightness
	fogColor *= brightness
    pos := camera.front
	model := 
		math.matrix4_translate_f32(pos) * 
		math.matrix4_rotate_f32(0.5 * math.PI - math.atan2(math.length(pos.xz), pos.y), -math.normalize(math.cross(vec3{0, 1, 0}, camera.front))) * 
		math.matrix4_rotate_f32(-0.5 * math.PI - math.atan2(pos.z, pos.x), {0, 1, 0}) * 
		math.matrix4_scale(vec3{1, camera.viewPort.y / camera.viewPort.x, 0})
    gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])
	gl.Uniform3f(render.uniforms["skyColor"].location, skyColor.r, skyColor.g, skyColor.b)
	gl.Uniform3f(render.uniforms["fogColor"].location, fogColor.r, fogColor.g, fogColor.b)

    gl.BindVertexArray(render.vao)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

setupSun :: proc(core: ^skeewb.core_interface, camera: ^util.Camera, render: ^Render) {
	// gl.GenTextures(1, &render.texture)
	// gl.BindTexture(gl.TEXTURE_2D_ARRAY, render.texture)
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.REPEAT)
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.REPEAT)
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	// width, height, channels: i32
	// datas := []string{
	// 	core.resource_string(core.resource_load("madera", "basalt/assets/textures/default_box.png")),
	// 	core.resource_string(core.resource_load("preda", "basalt/assets/textures/default_stone.png")),
	// 	core.resource_string(core.resource_load("terra", "basalt/assets/textures/default_dirt.png")),
	// 	core.resource_string(core.resource_load("teratu", "basalt/assets/textures/default_dirt_with_grass.png")),
	// 	core.resource_string(core.resource_load("matu", "basalt/assets/textures/default_grass.png")),
	// }
	// gl.TexImage3D(gl.TEXTURE_2D_ARRAY, 0, gl.SRGB8_ALPHA8, 16, 16, i32(len(datas)), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	// for tex, idx in datas {
	// 	pixels := stb.load_from_memory(raw_data(tex), i32(len(tex)), &width, &height, &channels, 4)
	// 	gl.TexSubImage3D(gl.TEXTURE_2D_ARRAY, 0, 0, 0, i32(idx), 16, 16, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
	// 	stb.image_free(pixels)
	// }
	// gl.GenerateMipmap(gl.TEXTURE_2D_ARRAY)
	// if sdl2.GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic") {
	// 	filter: f32
	// 	gl.GetFloatv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &filter)
	// 	gl.TexParameterf(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAX_ANISOTROPY, filter)
	// }
    
	gl.GenVertexArrays(1, &render.vao)
	gl.BindVertexArray(render.vao)

	gl.GenBuffers(1, &render.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, render.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 2 * size_of(f32), 0)

	vertShader := core.resource_load("sun_vert", "basalt/assets/shaders/sun_vert.glsl")
	fragShader := core.resource_load("sun_frag", "basalt/assets/shaders/sun_frag.glsl")

	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(core.resource_string(vertShader), core.resource_string(fragShader))

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile sky shaders\n %s\n %s", a, c)
    }
	
	//gl.UseProgram(render.program)
	render.uniforms = gl.get_uniforms_from_program(render.program)
}

drawSun :: proc(camera: ^util.Camera, render: Render, time: f32) {
	cycle := math.fract(time / dayTime)
	angle := 2 * math.PI * cycle
	brightness := clamp(math.cos(angle) * 2 + 0.5, 0, 1)
	skyColor = vec3{brightness * skyBlue.r, brightness * skyBlue.g, brightness * skyBlue.b}
	fogColor = vec3{brightness * fogBlue.r, brightness * fogBlue.g, brightness * fogBlue.b}
    sunDirection = math.normalize(vec3{math.sin(angle), math.cos(angle) * math.sin(f32(math.RAD_PER_DEG) * 75), math.cos(angle) * math.cos(f32(math.RAD_PER_DEG) * 75)})
    pos := sunDirection * 1000
    right := math.normalize(math.cross(vec3{0, 1, 0}, sunDirection))
    up := math.normalize(math.cross(sunDirection, right))
    model := 
		math.matrix4_translate_f32(pos) * 
		math.matrix4_rotate_f32(0.5 * math.PI - math.atan2(math.length(pos.xz), pos.y), -right) * 
		math.matrix4_rotate_f32(-0.5 * math.PI - math.atan2(pos.z, pos.x), {0, 1, 0}) * 
		math.matrix4_scale(vec3{50, 50, 50})
    gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])

    gl.BindVertexArray(render.vao)
    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}