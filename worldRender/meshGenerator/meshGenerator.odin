package meshGenerator

import "../../skeewb"
import "../../world"

Primers :: [3 * 3 * 3]^world.Chunk

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

Corners :: enum{UpLeft, UpRight, DownLeft, DownRight}
CornersSet :: bit_set[Corners]

Orientation :: enum {Up, Down, Right, Left}

Face :: struct {
    pos: BlockPos,
    direction: Direction,
    textureID: u32,
    orientation: Orientation,
    corners: CornersSet,
}

signPos :: proc(pos: BlockPos) -> Pos {
    return {i8(pos.x), i8(pos.y), i8(pos.z)}
}

toIndex :: proc(pos: BlockPos) -> u16 {
    return u16(pos.x) * 32 * 32 + u16(pos.y) + u16(pos.z) * 32
}

isSideExposed :: proc(primer: world.Primer, primers: Primers, pos: BlockPos, offset: Pos) -> bool {
    x := offset.x
    y := offset.y
    z := offset.z
    sidePos := pos

    chunkXOffset := 0
    chunkYOffset := 0
    chunkZOffset := 0

    if offset.x < 0 && pos.x == 0 {
        sidePos = BlockPos{31, sidePos.y, sidePos.z}
        x = 0
        chunkXOffset = -1
    }
    if offset.x > 0 && pos.x == 31 {
        sidePos = BlockPos{0, sidePos.y, sidePos.z}
        x = 0
        chunkXOffset = 1
    }
    if offset.y < 0 && pos.y == 0 {
        sidePos = BlockPos{sidePos.x, 31, sidePos.z}
        y = 0
        chunkYOffset = -1
    }
    if offset.y > 0 && pos.y == 31 {
        sidePos = BlockPos{sidePos.x, 0, sidePos.z}
        y = 0
        chunkYOffset = 1
    }
    if offset.z < 0 && pos.z == 0 {
        z = 0
        sidePos = BlockPos{sidePos.x, sidePos.y, 31}
        chunkZOffset = -1
    }
    if offset.z > 0 && pos.z == 31 {
        z = 0
        sidePos = BlockPos{sidePos.x, sidePos.y, 0}
        chunkZOffset = 1
    }

    sidePos = BlockPos{u8(i8(sidePos.x) + x), u8(i8(sidePos.y) + y), u8(i8(sidePos.z) + z)}
    idx := (chunkYOffset + 1) * 3 * 3 + (chunkXOffset + 1) * 3 + chunkZOffset + 1
    if primers[idx] == nil {return true}
    return primers[idx].primer[toIndex(sidePos)] == 0;
}

hasSideExposed :: proc(primer: world.Primer, primers: Primers, pos: BlockPos) -> bool {
    if isSideExposed(primer, primers, pos, Pos{-1, 0, 0}) {return true}
    if isSideExposed(primer, primers, pos, Pos{ 1, 0, 0}) {return true}
    if isSideExposed(primer, primers, pos, Pos{ 0,-1, 0}) {return true}
    if isSideExposed(primer, primers, pos, Pos{ 0, 1, 0}) {return true}
    if isSideExposed(primer, primers, pos, Pos{ 0, 0,-1}) {return true}
    if isSideExposed(primer, primers, pos, Pos{ 0, 0, 1}) {return true}

    return false
}

filterCubes :: proc(primer: world.Primer, primers: Primers) -> [dynamic]Cube {
    filtered := [dynamic]Cube{}

    for i in 0..<32 {
        for j in 0..< 32 {
            for k in 0..< 32 {
                pos := BlockPos{u8(i), u8(j), u8(k)}
                id := primer[toIndex(pos)]

                if id == 0 {continue}

                if hasSideExposed(primer, primers, pos) {append(&filtered, Cube{id, pos})}
            }
        }
    }

    return filtered
}

makeCubes :: proc(primer: world.Primer, primers: Primers, cubes: [dynamic]Cube) -> [dynamic]CubeFaces {
    cubesFaces := [dynamic]CubeFaces{}

    for cube in cubes {
        pos := cube.pos
        faces := FaceSet{}

        if isSideExposed(primer, primers, pos, Pos{-1, 0, 0}) {faces = faces + {.West}};
        if isSideExposed(primer, primers, pos, Pos{ 1, 0, 0}) {faces = faces + {.East}};
        if isSideExposed(primer, primers, pos, Pos{ 0,-1, 0}) {faces = faces + {.Bottom}};
        if isSideExposed(primer, primers, pos, Pos{ 0, 1, 0}) {faces = faces + {.Up}};
        if isSideExposed(primer, primers, pos, Pos{ 0, 0,-1}) {faces = faces + {.South}};
        if isSideExposed(primer, primers, pos, Pos{ 0, 0, 1}) {faces = faces + {.North}};

        append(&cubesFaces, CubeFaces{cube.id, pos, faces})
    }

    return cubesFaces;
}

makeFaces :: proc(cubesFaces: [dynamic]CubeFaces) -> [dynamic]Face {
    faces := [dynamic]Face{}

    for cube in cubesFaces {
        if .Up     in cube.faces {append(&faces, Face{cube.pos, .Up,     cube.id, .Up, CornersSet{}})}
        if .Bottom in cube.faces {append(&faces, Face{cube.pos, .Bottom, cube.id, .Up, CornersSet{}})}
        if .North  in cube.faces {append(&faces, Face{cube.pos, .North,  cube.id, .Up, CornersSet{}})}
        if .South  in cube.faces {append(&faces, Face{cube.pos, .South,  cube.id, .Up, CornersSet{}})}
        if .West   in cube.faces {append(&faces, Face{cube.pos, .West,   cube.id, .Up, CornersSet{}})}
        if .East   in cube.faces {append(&faces, Face{cube.pos, .East,   cube.id, .Up, CornersSet{}})}
    }

    return faces
}

getAO :: proc(pos: BlockPos, offset: Pos, normal: Pos, primer: world.Primer, primers: Primers) -> f32 {
    corner := !isSideExposed(primer, primers, pos, Pos{offset.x, normal.y, offset.z})
    side1  := !isSideExposed(primer, primers, pos, Pos{normal.x, offset.y, offset.z})
    side2  := !isSideExposed(primer, primers, pos, Pos{offset.x, offset.y, normal.z})

    if side1 && side2 {
      return 0
    }
    return f32(3 - (int(side1) + int(side2) + int(corner)))
}

toFlipe :: proc(a00, a01, a10, a11: f32) -> bool {
	return a00 + a11 > a01 + a10;
}

makeVertices :: proc(faces: [dynamic]Face, primer: world.Primer, primers: Primers) -> ([dynamic]u32, [dynamic]f32) {
    vertices := [dynamic]f32{}
    indices := [dynamic]u32{}

    for face in faces {
        pos := face.pos
        posX := f32(pos.x)
        posY := f32(pos.y)
        posZ := f32(pos.z)

        vertexAo: [4]f32
        toFlip: bool
        switch face.direction {
            case .Up:
                vertexAo = {
                    getAO(pos, Pos{-1, 1,-1}, Pos{ 0, 1, 0}, primer, primers),
                    getAO(pos, Pos{-1, 1, 1}, Pos{ 0, 1, 0}, primer, primers),
                    getAO(pos, Pos{ 1, 1, 1}, Pos{ 0, 1, 0}, primer, primers),
                    getAO(pos, Pos{ 1, 1,-1}, Pos{ 0, 1, 0}, primer, primers),
                }
                append(&vertices, posX + 0, posY + 1, posZ + 0, 0, 1, 0, 0, 1, vertexAo[0])
                append(&vertices, posX + 0, posY + 1, posZ + 1, 0, 1, 0, 0, 0, vertexAo[1])
                append(&vertices, posX + 1, posY + 1, posZ + 1, 0, 1, 0, 1, 0, vertexAo[2])
                append(&vertices, posX + 1, posY + 1, posZ + 0, 0, 1, 0, 1, 1, vertexAo[3])
                toFlip = toFlipe(vertexAo[3], vertexAo[0], vertexAo[2], vertexAo[1])
            case .Bottom:
                vertexAo = {
                    getAO(pos, Pos{-1,-1,-1}, Pos{ 0,-1, 0}, primer, primers),
                    getAO(pos, Pos{ 1,-1,-1}, Pos{ 0,-1, 0}, primer, primers),
                    getAO(pos, Pos{ 1,-1, 1}, Pos{ 0,-1, 0}, primer, primers),
                    getAO(pos, Pos{-1,-1, 1}, Pos{ 0,-1, 0}, primer, primers),
                }
                append(&vertices, posX + 0, posY + 0, posZ + 0, 0,-1, 0, 0, 1, vertexAo[0])
                append(&vertices, posX + 1, posY + 0, posZ + 0, 0,-1, 0, 1, 1, vertexAo[1])
                append(&vertices, posX + 1, posY + 0, posZ + 1, 0,-1, 0, 1, 0, vertexAo[2])
                append(&vertices, posX + 0, posY + 0, posZ + 1, 0,-1, 0, 0, 0, vertexAo[3])
                toFlip = toFlipe(vertexAo[1], vertexAo[0], vertexAo[2], vertexAo[3])
            case .North:
                vertexAo = {
                    getAO(pos, Pos{-1,-1, 1}, Pos{ 0, 0, 1}, primer, primers),
                    getAO(pos, Pos{ 1,-1, 1}, Pos{ 0, 0, 1}, primer, primers),
                    getAO(pos, Pos{ 1, 1, 1}, Pos{ 0, 0, 1}, primer, primers),
                    getAO(pos, Pos{-1, 1, 1}, Pos{ 0, 0, 1}, primer, primers),
                }
                append(&vertices, posX + 0, posY + 0, posZ + 1, 0, 0, 1, 0, 1, vertexAo[0])
                append(&vertices, posX + 1, posY + 0, posZ + 1, 0, 0, 1, 1, 1, vertexAo[1])
                append(&vertices, posX + 1, posY + 1, posZ + 1, 0, 0, 1, 1, 0, vertexAo[2])
                append(&vertices, posX + 0, posY + 1, posZ + 1, 0, 0, 1, 0, 0, vertexAo[3])
                toFlip = toFlipe(vertexAo[1], vertexAo[0], vertexAo[2], vertexAo[3])
            case .South:
                vertexAo = {
                    getAO(pos, Pos{-1,-1,-1}, Pos{ 0, 0,-1}, primer, primers),
                    getAO(pos, Pos{-1, 1,-1}, Pos{ 0, 0,-1}, primer, primers),
                    getAO(pos, Pos{ 1, 1,-1}, Pos{ 0, 0,-1}, primer, primers),
                    getAO(pos, Pos{ 1,-1,-1}, Pos{ 0, 0,-1}, primer, primers),
                }
                append(&vertices, posX + 0, posY + 0, posZ + 0, 0, 0,-1, 1, 1, vertexAo[0])
                append(&vertices, posX + 0, posY + 1, posZ + 0, 0, 0,-1, 1, 0, vertexAo[1])
                append(&vertices, posX + 1, posY + 1, posZ + 0, 0, 0,-1, 0, 0, vertexAo[2])
                append(&vertices, posX + 1, posY + 0, posZ + 0, 0, 0,-1, 0, 1, vertexAo[3])
                toFlip = toFlipe(vertexAo[3], vertexAo[0], vertexAo[2], vertexAo[1])
            case .East:
                vertexAo = {
                    getAO(pos, Pos{ 1,-1,-1}, Pos{ 1, 0, 0}, primer, primers),
                    getAO(pos, Pos{ 1, 1,-1}, Pos{ 1, 0, 0}, primer, primers),
                    getAO(pos, Pos{ 1, 1, 1}, Pos{ 1, 0, 0}, primer, primers),
                    getAO(pos, Pos{ 1,-1, 1}, Pos{ 1, 0, 0}, primer, primers),
                }
                append(&vertices, posX + 1, posY + 0, posZ + 0, 1, 0, 0, 1, 1, vertexAo[0])
                append(&vertices, posX + 1, posY + 1, posZ + 0, 1, 0, 0, 1, 0, vertexAo[1])
                append(&vertices, posX + 1, posY + 1, posZ + 1, 1, 0, 0, 0, 0, vertexAo[2])
                append(&vertices, posX + 1, posY + 0, posZ + 1, 1, 0, 0, 0, 1, vertexAo[3])
                toFlip = toFlipe(vertexAo[3], vertexAo[0], vertexAo[2], vertexAo[1])
            case .West:
                vertexAo = {
                    getAO(pos, Pos{-1,-1,-1}, Pos{-1, 0, 0}, primer, primers),
                    getAO(pos, Pos{-1,-1, 1}, Pos{-1, 0, 0}, primer, primers),
                    getAO(pos, Pos{-1, 1, 1}, Pos{-1, 0, 0}, primer, primers),
                    getAO(pos, Pos{-1, 1,-1}, Pos{-1, 0, 0}, primer, primers),
                }
                append(&vertices, posX + 0, posY + 0, posZ + 0,-1, 0, 0, 0, 1, vertexAo[0])
                append(&vertices, posX + 0, posY + 0, posZ + 1,-1, 0, 0, 1, 1, vertexAo[1])
                append(&vertices, posX + 0, posY + 1, posZ + 1,-1, 0, 0, 1, 0, vertexAo[2])
                append(&vertices, posX + 0, posY + 1, posZ + 0,-1, 0, 0, 0, 0, vertexAo[3])
                toFlip = toFlipe(vertexAo[1], vertexAo[0], vertexAo[2], vertexAo[3])
        }
        n := u32(len(vertices) / 9)
        if !toFlip {
            append(&indices, n - 4, n - 3, n - 2, n - 2, n - 1, n - 4)
        } else {
            append(&indices, n - 1, n - 4, n - 3, n - 3, n - 2, n - 1)
        }
    }

    return indices, vertices
}

generateMesh :: proc(chunk: world.Chunk) -> ([dynamic]u32, [dynamic]f32) {
    primer := chunk.primer
    x := chunk.pos.x
    y := chunk.pos.y
    z := chunk.pos.z
    
    primers: Primers

    for i: i32 = 0; i < 3; i += 1 {
        for j: i32 = 0; j < 3; j += 1 {
            for k: i32 = 0; k < 3; k += 1 {
                pos := [3]i32{x + i - 1, y + k - 1, z + j - 1}
                primers[k * 3 * 3 + i * 3 + j] = &world.chunkMap[pos]
            }
        }
    }

    cubes := filterCubes(primer, primers)
    cubesFaces := makeCubes(primer, primers, cubes)
    delete(cubes)
    faces := makeFaces(cubesFaces)
    delete(cubesFaces)
    indices, vertices := makeVertices(faces, primer, primers)
    delete(faces)

    return indices, vertices
}
