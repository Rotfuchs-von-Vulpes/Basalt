package meshGenerator

import "../../skeewb"
import "../../world"

Pos :: struct {
    x, y, z: i8
}

BlockPos :: struct {
    x, y, z: u8
}

Direction :: enum{Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

Cube :: struct {
    id: u32,
    pos: BlockPos,
}

CubeFaces :: struct {
    id: u32,
    pos: BlockPos,
    faces: FaceSet,
}

Orientation :: enum {Up, Down, Right, Left}

Face :: struct {
    pos: BlockPos,
    direction: Direction,
    textureID: u32,
    orientation: Orientation
}

toIndex :: proc(pos: BlockPos) -> u16 {
    return u16(pos.x) * 32 * 32 + u16(pos.y) + u16(pos.z) * 32
}

isSideExposed :: proc(chunk: world.Chunk, pos: BlockPos, offset: Pos) -> bool {
    if offset.x < 0 && pos.x == 0 {
        sidePos := BlockPos{31, u8(i8(pos.y) + offset.y), u8(i8(pos.z) + offset.z)}
        return world.chunks[world.chunkMap[{chunk.x - 1, 0, chunk.z}]].primer[toIndex(sidePos)] == 0
    }
    if offset.y < 0 && pos.y == 0 {
        return true
    }
    if offset.z < 0 && pos.z == 0 {
        sidePos := BlockPos{u8(i8(pos.x) + offset.x), u8(i8(pos.y) + offset.y), 31}
        return world.chunks[world.chunkMap[{chunk.x, 0, chunk.z - 1}]].primer[toIndex(sidePos)] == 0
    }
    if offset.x > 0 && pos.x == 31 {
        sidePos := BlockPos{0, u8(i8(pos.y) + offset.y), u8(i8(pos.z) + offset.z)}
        return world.chunks[world.chunkMap[{chunk.x + 1, 0, chunk.z}]].primer[toIndex(sidePos)] == 0
    }
    if offset.y > 0 && pos.y == 31 {
        return true
    }
    if offset.z > 0 && pos.z == 31 {
        sidePos := BlockPos{u8(i8(pos.x) + offset.x), u8(i8(pos.y) + offset.y), 0}
        // if world.chunkMap[{chunk.x, 0, chunk.z + 1}] == 0 {skeewb.console_log(.INFO, "aaaa")}
        return world.chunks[world.chunkMap[{chunk.x, 0, chunk.z + 1}]].primer[toIndex(sidePos)] == 0
    }

    sidePos := BlockPos{u8(i8(pos.x) + offset.x), u8(i8(pos.y) + offset.y), u8(i8(pos.z) + offset.z)}
    return chunk.primer[toIndex(sidePos)] == 0;
}

hasSideExposed :: proc(chunk: world.Chunk, pos: BlockPos) -> bool {
    if isSideExposed(chunk, pos, Pos{-1, 0, 0}) {return true}
    if isSideExposed(chunk, pos, Pos{ 1, 0, 0}) {return true}
    if isSideExposed(chunk, pos, Pos{ 0,-1, 0}) {return true}
    if isSideExposed(chunk, pos, Pos{ 0, 1, 0}) {return true}
    if isSideExposed(chunk, pos, Pos{ 0, 0,-1}) {return true}
    if isSideExposed(chunk, pos, Pos{ 0, 0, 1}) {return true}

    return false
}

filterCubes :: proc(chunk: world.Chunk) -> [dynamic]Cube {
    filtered := [dynamic]Cube{}

    for i in 0..<32 {
        for j in 0..< 32 {
            for k in 0..< 32 {
                pos := BlockPos{u8(i), u8(j), u8(k)}
                id := chunk.primer[toIndex(pos)]

                if id == 0 {continue}

                if hasSideExposed(chunk, pos) {append(&filtered, Cube{id, pos})}
            }
        }
    }

    return filtered
}

makeCubes :: proc(chunk: world.Chunk, cubes: [dynamic]Cube) -> [dynamic]CubeFaces {
    cubesFaces := [dynamic]CubeFaces{}

    for cube in cubes {
        pos := cube.pos
        faces := FaceSet{}

        if isSideExposed(chunk, pos, Pos{-1, 0, 0}) {faces = faces + {.West}};
        if isSideExposed(chunk, pos, Pos{ 1, 0, 0}) {faces = faces + {.East}};
        if isSideExposed(chunk, pos, Pos{ 0,-1, 0}) {faces = faces + {.Bottom}};
        if isSideExposed(chunk, pos, Pos{ 0, 1, 0}) {faces = faces + {.Up}};
        if isSideExposed(chunk, pos, Pos{ 0, 0,-1}) {faces = faces + {.South}};
        if isSideExposed(chunk, pos, Pos{ 0, 0, 1}) {faces = faces + {.North}};

        append(&cubesFaces, CubeFaces{cube.id, pos, faces})
    }

    return cubesFaces;
}

makeFaces :: proc(cubesFaces: [dynamic]CubeFaces) -> [dynamic]Face {
    faces := [dynamic]Face{}

    for cube in cubesFaces {
        if .Up     in cube.faces {append(&faces, Face{cube.pos, .Up,     cube.id, .Up})}
        if .Bottom in cube.faces {append(&faces, Face{cube.pos, .Bottom, cube.id, .Up})}
        if .North  in cube.faces {append(&faces, Face{cube.pos, .North,  cube.id, .Up})}
        if .South  in cube.faces {append(&faces, Face{cube.pos, .South,  cube.id, .Up})}
        if .West   in cube.faces {append(&faces, Face{cube.pos, .West,   cube.id, .Up})}
        if .East   in cube.faces {append(&faces, Face{cube.pos, .East,   cube.id, .Up})}
    }

    return faces
}

makeVertices :: proc(faces: [dynamic]Face) -> ([dynamic]u32, [dynamic]f32) {
    vertices := [dynamic]f32{}
    indices := [dynamic]u32{}

    for face in faces {
        pos := face.pos
        posX := f32(pos.x)
        posY := f32(pos.y)
        posZ := f32(pos.z)

        switch face.direction {
            case .Up:
                append(&vertices, posX + 0, posY + 1, posZ + 0, 0, 1, 0, 0, 1)
                append(&vertices, posX + 0, posY + 1, posZ + 1, 0, 1, 0, 0, 0)
                append(&vertices, posX + 1, posY + 1, posZ + 1, 0, 1, 0, 1, 0)
                append(&vertices, posX + 1, posY + 1, posZ + 0, 0, 1, 0, 1, 1)
            case .Bottom:
                append(&vertices, posX + 0, posY + 0, posZ + 0, 0,-1, 0, 0, 1)
                append(&vertices, posX + 1, posY + 0, posZ + 0, 0,-1, 0, 1, 1)
                append(&vertices, posX + 1, posY + 0, posZ + 1, 0,-1, 0, 1, 0)
                append(&vertices, posX + 0, posY + 0, posZ + 1, 0,-1, 0, 0, 0)
            case .North:
                append(&vertices, posX + 0, posY + 0, posZ + 1, 0, 0, 1, 0, 1)
                append(&vertices, posX + 1, posY + 0, posZ + 1, 0, 0, 1, 1, 1)
                append(&vertices, posX + 1, posY + 1, posZ + 1, 0, 0, 1, 1, 0)
                append(&vertices, posX + 0, posY + 1, posZ + 1, 0, 0, 1, 0, 0)
            case .South:
                append(&vertices, posX + 0, posY + 0, posZ + 0, 0, 0,-1, 1, 1)
                append(&vertices, posX + 0, posY + 1, posZ + 0, 0, 0,-1, 1, 0)
                append(&vertices, posX + 1, posY + 1, posZ + 0, 0, 0,-1, 0, 0)
                append(&vertices, posX + 1, posY + 0, posZ + 0, 0, 0,-1, 0, 1)
            case .East:
                append(&vertices, posX + 1, posY + 0, posZ + 0, 1, 0, 0, 1, 1)
                append(&vertices, posX + 1, posY + 1, posZ + 0, 1, 0, 0, 1, 0)
                append(&vertices, posX + 1, posY + 1, posZ + 1, 1, 0, 0, 0, 0)
                append(&vertices, posX + 1, posY + 0, posZ + 1, 1, 0, 0, 0, 1)
            case .West:
                append(&vertices, posX + 0, posY + 0, posZ + 0,-1, 0, 0, 0, 1)
                append(&vertices, posX + 0, posY + 0, posZ + 1,-1, 0, 0, 1, 1)
                append(&vertices, posX + 0, posY + 1, posZ + 1,-1, 0, 0, 1, 0)
                append(&vertices, posX + 0, posY + 1, posZ + 0,-1, 0, 0, 0, 0)
        }
        n := u32(len(vertices) / 8)
        append(&indices, n - 4, n - 3, n - 2, n - 2, n - 1, n - 4)
    }

    return indices, vertices
}

generateMesh :: proc(chunk: world.Chunk) -> ([dynamic]u32, [dynamic]f32) {
    cubes := filterCubes(chunk)
    cubesFaces := makeCubes(chunk, cubes)
    faces := makeFaces(cubesFaces)
    indices, vertices := makeVertices(faces)

    return indices, vertices
}
