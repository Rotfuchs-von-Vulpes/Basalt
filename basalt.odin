package basalt

import "core:fmt";
import "core:time"
import math "core:math/linalg";
import glm "core:math/linalg/glsl"
import "skeewb"
import "base:runtime"
import "vendor:sdl2"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"

import "world"
import "worldRender"

vert_raw :: #load("assets/shaders/test_vert.glsl")
frag_raw :: #load("assets/shaders/test_frag.glsl")

@(export)
load :: proc"c"(core: ^skeewb.core_interface) -> skeewb.module_desc {
	context = runtime.default_context()

	core.event_listen("start", skeewb.event_callback(start));
	core.event_listen("loop", skeewb.event_callback(loop));
	core.event_listen("quit", skeewb.event_callback(quit));

	return (skeewb.module_desc) {
		modid = "basalt",
		version = {0, 0, 1},
		interface = nil,
	}
}

start_tick: time.Tick

window: ^sdl2.Window
gl_context: sdl2.GLContext
program: u32
VBO: u32
VAO: u32
EBO: u32
texture: u32
uniforms: map[string]gl.Uniform_Info
mesh: [dynamic]f32
indi: [dynamic]u32

screenWidth: i32 = 854
screenHeight: i32 = 480

start :: proc"c"(core: ^skeewb.core_interface) {
	context = runtime.default_context()

	start_tick = time.tick_now()

	sdl2.Init(sdl2.INIT_EVERYTHING)

	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))


	window = sdl2.CreateWindow("testando se muda alguma coisa", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, screenWidth, screenHeight, sdl2.WINDOW_RESIZABLE | sdl2.WINDOW_OPENGL)
	if (window == nil) {
		skeewb.console_log(.ERROR, "could not create a window sdl error: %s", sdl2.GetError())
		core.quit(-1)
	}
	skeewb.console_log(.INFO, "successfully created a window")

	gl_context = sdl2.GL_CreateContext(window);
	if (gl_context == nil) {
		skeewb.console_log(.ERROR, "could not create an OpenGL context sdl error: %s", sdl2.GetError())
		core.quit(-1)
	}
	skeewb.console_log(.INFO, "successfully created an OpenGL context")

	sdl2.GL_SetSwapInterval(-1)

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)
	
	gl.Enable(gl.DEPTH_TEST)
	// gl.Enable(gl.CULL_FACE)
	// gl.CullFace(gl.BACK)
	// gl.Enable(gl.BLEND)
	// gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	vertShader := core.resource_load("vert", "basalt/assets/shaders/test_vert.glsl")
	fragShader := core.resource_load("frag", "basalt/assets/shaders/test_frag.glsl")

	shaderSuccess : bool
	program, shaderSuccess = gl.load_shaders_source(core.resource_string(vertShader), core.resource_string(fragShader))

    if !shaderSuccess {
        len: i32
        info: [^]u8
        gl.GetShaderInfoLog(program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile shaders\n %s\n %s", a, c)
    }

	gl.GenVertexArrays(1, &VAO)
	gl.BindVertexArray(VAO)

	chunk := world.getNewChunk(0, 0)
	indi, mesh = worldRender.generateMesh(chunk)
    
	gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, len(mesh)*size_of(mesh[0]), raw_data(mesh), gl.STATIC_DRAW)
	
	gl.GenBuffers(1, &EBO);
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indi)*size_of(indi[0]), raw_data(indi), gl.STATIC_DRAW); 

	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(f32), 0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 8 * size_of(f32), 3 * size_of(f32))
	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 8 * size_of(f32), 6 * size_of(f32))

	
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	stb.set_flip_vertically_on_load(1);
	width, height, channels: i32
	data := core.resource_string(core.resource_load("madera", "basalt/assets/textures/default_box.png"))
	pixels := stb.load_from_memory(raw_data(data), cast(i32) len(data), &width, &height, &channels, 4)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8 , width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
	gl.GenerateMipmap(gl.TEXTURE_2D)
	// if sdl2.GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic") {
	// 	gl.TexParameterf(gl.TEXTURE_2D, )
	// }

	gl.ClearColor(0.1, 0.1, 0.1, 1.0)
    
	gl.UseProgram(program)

	uniforms = gl.get_uniforms_from_program(program)
}

loop :: proc"c"(core: ^skeewb.core_interface) {
	//context = runtime.default_context()
	
	duration := time.tick_since(start_tick)
	t := f32(time.duration_seconds(duration))

	event : sdl2.Event
		
	for sdl2.PollEvent(&event) {
		if event.type == sdl2.EventType.QUIT {
			core.quit(0)
		}
	}
	
	model := glm.mat4{
		  1,   0,   0, 0,
		  0,   1,   0, 0,
		  0,   0,   1, 0,
		  0,   0,   0, 1,
	}
		
	view := glm.mat4LookAt({16, 2, 16}, {0, 0, 0}, {0, 1, 0})
	proj := glm.mat4Perspective(45, f32(screenWidth) / f32(screenHeight), 0.1, 100.0)

	gl.UniformMatrix4fv(uniforms["model"].location, 1, false, &model[0, 0])
	gl.UniformMatrix4fv(uniforms["view"].location, 1, false, &view[0, 0])
	gl.UniformMatrix4fv(uniforms["projection"].location, 1, false, &proj[0, 0])

	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.UseProgram(program)

	// gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
	gl.ActiveTexture(gl.TEXTURE0);
	gl.BindTexture(gl.TEXTURE_2D, texture);
	gl.BindVertexArray(VAO);
	gl.DrawElements(gl.TRIANGLES, i32(len(indi)), gl.UNSIGNED_INT, nil)

	sdl2.GL_SwapWindow(window)
}

quit :: proc"c"(core: ^skeewb.core_interface){
	context = runtime.default_context()
	delete(uniforms)
	gl.DeleteProgram(program)
	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteBuffers(1, &EBO)
	sdl2.GL_DeleteContext(gl_context)
	sdl2.DestroyWindow(window)
	sdl2.Quit()
}
