package worldRender

import gl "vendor:OpenGL"

import "../world"
import mesh "meshGenerator"

ChunkBuffer :: struct{
    x, z: i32,
	VAO, VBO, EBO: u32,
    length: i32
}

setupChunk :: proc(chunk: world.Chunk) -> ChunkBuffer {
    indices, vertices := mesh.generateMesh(chunk)
    VAO, VBO, EBO: u32
    
	gl.GenVertexArrays(1, &VAO)
	gl.BindVertexArray(VAO)

	gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(vertices[0]), raw_data(vertices), gl.STATIC_DRAW)
	
	gl.GenBuffers(1, &EBO)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)*size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)

	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 8 * size_of(f32), 0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 8 * size_of(f32), 3 * size_of(f32))
	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 8 * size_of(f32), 6 * size_of(f32))

    return ChunkBuffer{chunk.x, chunk.z, VAO, VBO, EBO, i32(len(indices))}
}

setupManyChunks :: proc(chunks: [dynamic]world.Chunk) -> [dynamic]ChunkBuffer {
    chunksBuffers: [dynamic]ChunkBuffer

    for chunk in chunks {
        append(&chunksBuffers, setupChunk(chunk))
    }

    return chunksBuffers;
}