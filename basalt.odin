package basalt

import "core:fmt"
import "core:time"
import "core:mem"
import math "core:math/linalg"
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
VAO: u32
texture: u32
uniforms: map[string]gl.Uniform_Info

chunks: [dynamic]worldRender.ChunkBuffer
cameraChunkX: i32 = 0
cameraChunkZ: i32 = 0
viewDistance: i32 = 6

screenWidth: i32 = 854
screenHeight: i32 = 480
deltaTime: f32 = 0.0
lastFrame: f32 = 0.0

tracking_allocator: ^mem.Tracking_Allocator

start :: proc"c"(core: ^skeewb.core_interface) {
	context = runtime.default_context()

	tracking_allocator = new(mem.Tracking_Allocator)
	mem.tracking_allocator_init(tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(tracking_allocator)
	

	start_tick = time.tick_now()

	sdl2.Init(sdl2.INIT_EVERYTHING)

	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))


	window = sdl2.CreateWindow("AAAAAAAAAAAAAAAAAAA", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, screenWidth, screenHeight, sdl2.WINDOW_RESIZABLE | sdl2.WINDOW_OPENGL)
	if (window == nil) {
		skeewb.console_log(.ERROR, "could not create a window sdl error: %s", sdl2.GetError())
		core.quit(-1)
	}
	skeewb.console_log(.INFO, "successfully created a window")

	sdl2.SetRelativeMouseMode(true)

	gl_context = sdl2.GL_CreateContext(window);
	if (gl_context == nil) {
		skeewb.console_log(.ERROR, "could not create an OpenGL context sdl error: %s", sdl2.GetError())
		core.quit(-1)
	}
	skeewb.console_log(.INFO, "successfully created an OpenGL context")

	sdl2.GL_SetSwapInterval(-1)

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)
	
	gl.Enable(gl.DEPTH_TEST)
	gl.Enable(gl.CULL_FACE)
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

	chunks = worldRender.setupManyChunks(world.peak(cameraChunkX, 0, cameraChunkZ, viewDistance))
	
	gl.GenTextures(1, &texture)
	gl.BindTexture(gl.TEXTURE_2D, texture)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	width, height, channels: i32
	data := core.resource_string(core.resource_load("madera", "basalt/assets/textures/default_box.png"))
	pixels := stb.load_from_memory(raw_data(data), cast(i32) len(data), &width, &height, &channels, 4)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
	gl.GenerateMipmap(gl.TEXTURE_2D)
	if sdl2.GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic") {
		filter: f32
		gl.GetFloatv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &filter)
		gl.TexParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAX_ANISOTROPY, filter)
	}

	gl.ClearColor(0.1, 0.1, 0.1, 1.0)
    
	gl.UseProgram(program)

	uniforms = gl.get_uniforms_from_program(program)
}

toFront := false
toBehind := false
toRight := false
toLeft := false

cameraPos := glm.vec3{1, 33, 1}
cameraFront := glm.vec3{0.0, 0.0, -1.0}
cameraUp := glm.vec3{0.0, 1.0, 0.0}
cameraRight := math.cross(cameraFront, cameraUp)
moved := true

yaw: f32 = -90.0;
pitch: f32 = 0.0;

lastChunkX := cameraChunkX
lastChunkZ := cameraChunkZ

loop :: proc"c"(core: ^skeewb.core_interface) {
	context = runtime.default_context()
	
	duration := time.tick_since(start_tick)
	t := f32(time.duration_seconds(duration))

	event: sdl2.Event
		
	for sdl2.PollEvent(&event) {
		if event.type == .QUIT {
			core.quit(0)
		} else if event.type == .KEYUP {
			#partial switch (event.key.keysym.sym) {
				case .ESCAPE:
					core.quit(0)
				case .W:
					toFront = false
				case .S:
					toBehind = false
				case .A:
					toLeft = false
				case .D:
					toRight = false
			}
		} else if event.type == .KEYDOWN {
			#partial switch (event.key.keysym.sym) {
				case .ESCAPE:
					core.quit(0)
				case .W:
					toFront = true
				case .S:
					toBehind = true
				case .A:
					toLeft = true
				case .D:
					toRight = true
			}
		} else if event.type == .MOUSEMOTION {
			xpos :=  f32(event.motion.xrel)
			ypos := -f32(event.motion.yrel)
		
			sensitivity: f32 = 0.1
			xoffset := xpos * sensitivity
			yoffset := ypos * sensitivity
		
			yaw += xoffset
			pitch += yoffset

			if pitch >= 89 {
				pitch = 89
			}
			if pitch <= -89 {
				pitch = -89
			}

			yawRadians := yaw * math.RAD_PER_DEG
			pitchRadians := pitch * math.RAD_PER_DEG
		
			cameraFront = {
				math.cos(yawRadians) * math.cos(pitchRadians),
				math.sin(pitchRadians),
				math.sin(yawRadians) * math.cos(pitchRadians)
			}
			cameraFront = math.vector_normalize(cameraFront)
			
			cameraUp = {
				-math.sin(pitchRadians) * math.cos(yawRadians),
				 math.cos(pitchRadians),
				-math.sin(pitchRadians) * math.sin(yawRadians)
			}
			cameraUp = math.vector_normalize(cameraUp)

			cameraRight = math.cross(cameraFront, cameraUp)
		}
	}

	cameraSpeed: f32 = 0.125
	scale: glm.vec3 = {0, 0, 0}

	if toFront != toBehind {
		if toFront {
			scale += cameraFront
		} else {
			scale -= cameraFront
		}
	}

	if toLeft != toRight {
		if toLeft {
			scale -= cameraRight
		} else {
			scale += cameraRight
		}
	}

	if math.length(scale) > 0 {scale = math.vector_normalize(scale) * cameraSpeed}
	cameraPos += scale;
	
	chunkX := i32(math.floor(cameraPos.x / 32))
	chunkZ := i32(math.floor(cameraPos.z / 32))

	if (chunkX != lastChunkX) {
		cameraChunkX = chunkX
		lastChunkX = chunkX
		moved = true
	}
	if (chunkZ != lastChunkZ) {
		cameraChunkZ = chunkZ
		lastChunkZ = chunkZ
		moved = true
	}
	if moved {
		skeewb.console_log(.INFO, "moved!")
		chunks = worldRender.setupManyChunks(world.peak(cameraChunkX, 0, cameraChunkZ, viewDistance))
		moved = false
	}

	view := glm.mat4LookAt({0, 0, 0}, cameraFront, cameraUp)
	proj := glm.mat4Perspective(45, f32(screenWidth) / f32(screenHeight), 0.1, 1000)

	gl.UniformMatrix4fv(uniforms["view"].location, 1, false, &view[0, 0])
	gl.UniformMatrix4fv(uniforms["projection"].location, 1, false, &proj[0, 0])

	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
	gl.UseProgram(program)

	gl.ActiveTexture(gl.TEXTURE0);
	gl.BindTexture(gl.TEXTURE_2D, texture);

	for chunk in chunks {
		pos := [3]f32{f32(chunk.x) * 32 - cameraPos.x, - cameraPos.y, f32(chunk.z) * 32 - cameraPos.z}
		model := math.matrix4_translate_f32(pos)
		gl.UniformMatrix4fv(uniforms["model"].location, 1, false, &model[0, 0])
	
		gl.BindVertexArray(chunk.VAO);
		gl.DrawElements(gl.TRIANGLES, chunk.length, gl.UNSIGNED_INT, nil)
	}

	sdl2.GL_SwapWindow(window)
}

quit :: proc"c"(core: ^skeewb.core_interface){
	context = runtime.default_context()

	free(tracking_allocator)
	mem.tracking_allocator_destroy(tracking_allocator)

	worldRender.nuke()
	world.nuke()

	delete(uniforms)
	gl.DeleteProgram(program)
	gl.DeleteVertexArrays(1, &VAO)
	delete(chunks)

	sdl2.GL_DeleteContext(gl_context)
	sdl2.DestroyWindow(window)
	sdl2.Quit()
}
