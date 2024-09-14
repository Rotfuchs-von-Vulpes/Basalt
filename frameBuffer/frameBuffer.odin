package frameBuffer

import gl "vendor:OpenGL"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"

import "../skeewb"
import "../util"
import "../sky"

mat4 :: glm.mat4x4
vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

Render :: struct{
	id: u32,
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	texture: u32,
	depth: u32,
}

quadVertices := [?]f32{
	// positions   // texCoords
	-1.0,  1.0,  0.0, 1.0,
	-1.0, -1.0,  0.0, 0.0,
	 1.0, -1.0,  1.0, 0.0,

	-1.0,  1.0,  0.0, 1.0,
	 1.0, -1.0,  1.0, 0.0,
	 1.0,  1.0,  1.0, 1.0
}

setup :: proc(core: ^skeewb.core_interface, camera: ^util.Camera, render: ^Render) {
    gl.GenFramebuffers(1, &render.id)
	gl.BindFramebuffer(gl.FRAMEBUFFER, render.id)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.GenTextures(1, &render.texture)
	gl.BindTexture(gl.TEXTURE_2D, render.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, render.texture, 0)
	
	gl.ActiveTexture(gl.TEXTURE1)
	gl.GenTextures(1, &render.depth)
	gl.BindTexture(gl.TEXTURE_2D, render.depth)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT32, i32(camera.viewPort.x), i32(camera.viewPort.y), 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
	gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, raw_data([]f32{1, 1, 1, 1}))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)

	gl.FramebufferTexture(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, render.depth, 0)

	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != u32(gl.FRAMEBUFFER_COMPLETE) {
		skeewb.console_log(.ERROR, "Framebuffer is not complete!")
		core.quit(-1)
	}

	gl.GenVertexArrays(1, &render.vao)
	gl.GenBuffers(1, &render.vbo)
	gl.BindVertexArray(render.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, render.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 2 * size_of(quadVertices[0]))

	vertShader := core.resource_load("quad_vert", "basalt/assets/shaders/quad_vert.glsl")
	fragShader := core.resource_load("quad_frag", "basalt/assets/shaders/quad_frag.glsl")

	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(core.resource_string(vertShader), core.resource_string(fragShader))

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile fbo shaders\n %s\n %s", a, c)
    }
	
	render.uniforms = gl.get_uniforms_from_program(render.program)
	gl.Uniform1i(render.uniforms["screenTexture"].location, 0)
}

draw :: proc(render: Render) {
	gl.Disable(gl.DEPTH_TEST)

	gl.BindVertexArray(render.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, render.texture)
	// gl.ActiveTexture(gl.TEXTURE1)
	// gl.BindTexture(gl.TEXTURE_2D, render.depth)

	//gl.Uniform1i(render.uniforms["depthTexture"].location, 1)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
}
