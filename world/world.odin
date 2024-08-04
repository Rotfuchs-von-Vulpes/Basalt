package world

Primer :: [32 * 32 * 32]u32

Chunk :: struct {
    index: u64,
    x: i32,
    z: i32,
    primer: Primer,
    north: u64,
    south: u64,
    east: u64,
    west: u64,
}

chunks := [dynamic]Chunk{}

getNewChunk :: proc(x: i32, z: i32) -> Chunk {
    primer := Primer{0..<(32 * 32 * 32) = 1}
    // primer := Primer{0=1, 1..<(32 * 32 * 32) = 0}
    chunk := Chunk{u64(len(chunks)), x, z, primer, 0, 0, 0, 0}

    append(&chunks, chunk)

    return chunk
}
