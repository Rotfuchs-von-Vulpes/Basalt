package meshGenerator

import "../../skeewb"
import "../../world"

Primers :: [3 * 3 * 3]^world.Chunk

Pos :: [3]i8

BlockPos :: [3]u8

vec3 :: [3]f32

Direction :: enum {Up, Bottom, North, South, East, West}
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
Position :: enum {NorthwestUp, NorthwestDown, NortheastUp, NortheastDown, SoutheastUp, SoutheastDown, SouthwestUp, SouthwestDown}
Corner :: enum {TopLeft, BottomLeft, BottomRight, TopRight}
PositionSet :: bit_set[Position]

CubePoints :: struct {
    id: u32,
    pos: BlockPos,
    points: PositionSet,
}

CubeFacesPoints :: struct {
    id: u32,
    pos: BlockPos,
    faces: FaceSet,
    points: PositionSet,
}

Point :: struct {
    pos: vec3,
    occlusion: f32,
}

Face :: struct {
    pos: BlockPos,
    direction: Direction,
    textureID: u32,
    orientation: Orientation,
    corners: [Corner]Point,
}

toVec3 :: proc(vec: BlockPos) -> vec3 {
    return vec3{f32(vec.x), f32(vec.y), f32(vec.z)}
}

isSideExposed :: proc(primers: Primers, pos: BlockPos, offset: Pos) -> bool {
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
    return primers[idx].primer[sidePos.x][sidePos.y][sidePos.z] == 0;
}

hasSideExposed :: proc(primers: Primers, pos: BlockPos) -> bool {
    if isSideExposed(primers, pos, {-1, 0, 0}) {return true}
    if isSideExposed(primers, pos, { 1, 0, 0}) {return true}
    if isSideExposed(primers, pos, { 0,-1, 0}) {return true}
    if isSideExposed(primers, pos, { 0, 1, 0}) {return true}
    if isSideExposed(primers, pos, { 0, 0,-1}) {return true}
    if isSideExposed(primers, pos, { 0, 0, 1}) {return true}

    return false
}

filterCubes :: proc(primers: Primers) -> [dynamic]Cube {
    filtered := [dynamic]Cube{}

    for i in 0..<32 {
        for j in 0..< 32 {
            for k in 0..< 32 {
                pos := BlockPos{u8(i), u8(j), u8(k)}
                id := primers[1 * 3 * 3 + 1 * 3 + 1].primer[pos.x][pos.y][pos.z]

                if id == 0 {continue}

                if hasSideExposed(primers, pos) {append(&filtered, Cube{id, pos})}
            }
        }
    }

    return filtered
}

makeCubes :: proc(primers: Primers, cubes: [dynamic]Cube) -> [dynamic]CubeFaces {
    cubesFaces := [dynamic]CubeFaces{}

    for cube in cubes {
        pos := cube.pos
        faces := FaceSet{}

        if isSideExposed(primers, pos, {-1, 0, 0}) {faces = faces + {.West}};
        if isSideExposed(primers, pos, { 1, 0, 0}) {faces = faces + {.East}};
        if isSideExposed(primers, pos, { 0,-1, 0}) {faces = faces + {.Bottom}};
        if isSideExposed(primers, pos, { 0, 1, 0}) {faces = faces + {.Up}};
        if isSideExposed(primers, pos, { 0, 0,-1}) {faces = faces + {.South}};
        if isSideExposed(primers, pos, { 0, 0, 1}) {faces = faces + {.North}};

        append(&cubesFaces, CubeFaces{cube.id, pos, faces})
    }

    return cubesFaces;
}

makeCubePoints :: proc(cubesFaces: [dynamic]CubeFaces) -> [dynamic]CubeFacesPoints {
    cubeFacesPoints := [dynamic]CubeFacesPoints{}

    for cube in cubesFaces {
        min := cube.pos
        max := cube.pos + 1
        positions := PositionSet{}
        
        if .East  in cube.faces {positions = positions + {.NortheastDown, .NortheastUp, .SoutheastDown, .SoutheastUp}}
        if .Up    in cube.faces {positions = positions + {.NortheastUp,   .NorthwestUp, .SoutheastUp,   .SouthwestUp}}
        if .North in cube.faces {positions = positions + {.NortheastDown, .NortheastUp, .NorthwestDown, .NorthwestUp}}
        if .West   in cube.faces {positions = positions + {.NorthwestDown, .NorthwestUp,   .SouthwestDown, .SouthwestUp  }}
        if .Bottom in cube.faces {positions = positions + {.NortheastDown, .NorthwestDown, .SoutheastDown, .SouthwestDown}}
        if .South  in cube.faces {positions = positions + {.SoutheastDown, .SoutheastUp,   .SouthwestDown, .SouthwestUp  }}

        append(&cubeFacesPoints, CubeFacesPoints{cube.id, cube.pos, cube.faces, positions})
    }

    return cubeFacesPoints
}

getBlockPos :: proc(primers: Primers, pos: Pos) -> (^world.Chunk, BlockPos, bool) {
    sidePos := pos

    chunkXOffset := 0
    chunkYOffset := 0
    chunkZOffset := 0

    if pos.x < 0 {
        sidePos = {sidePos.x + 32, sidePos.y, sidePos.z}
        chunkXOffset = -1
    }
    if pos.x > 31 {
        sidePos = {sidePos.x - 32, sidePos.y, sidePos.z}
        chunkXOffset = 1
    }
    if pos.y < 0 {
        sidePos = {sidePos.x, sidePos.y + 32, sidePos.z}
        chunkYOffset = -1
    }
    if pos.y > 31 {
        sidePos = {sidePos.x, sidePos.y - 32, sidePos.z}
        chunkYOffset = 1
    }
    if pos.z < 0 {
        sidePos = {sidePos.x, sidePos.y, sidePos.z + 32}
        chunkZOffset = -1
    }
    if pos.z > 31 {
        sidePos = {sidePos.x, sidePos.y, sidePos.z - 32}
        chunkZOffset = 1
    }

    idx := (chunkYOffset + 1) * 3 * 3 + (chunkXOffset + 1) * 3 + chunkZOffset + 1
    if primers[idx] == nil {
        return primers[1 * 3 * 3 + 1 * 3 + 1], {0, 0, 0}, false
    }
    finalPos := BlockPos{u8(sidePos.x), u8(sidePos.y), u8(sidePos.z)}
    return primers[idx], finalPos, true
}

getAO :: proc(pos: BlockPos, offset: vec3, direction: Direction, primers: Primers) -> f32 {
    up: Pos

    switch direction {
        case .Up:     up = { 0, 1, 0}
        case .Bottom: up = { 0,-1, 0}
        case .North:  up = { 0, 0, 1}
        case .South:  up = { 0, 0,-1}
        case .East:   up = { 1, 0, 0}
        case .West:   up = {-1, 0, 0}
    }

    posV := Pos{i8(pos.x), i8(pos.y), i8(pos.z)}

    signX: i8 = 1
    signY: i8 = 1
    signZ: i8 = 1
    if offset.x == 0 {signX = -1}
    if offset.y == 0 {signY = -1}
    if offset.z == 0 {signZ = -1}

    cornerPrimer, cornerPos, ok := getBlockPos(primers, posV + {signX, signY, signZ})
    corner := cornerPrimer.primer[cornerPos.x][cornerPos.y][cornerPos.z]
    side1Pos, side2Pos: Pos

    if up.x != 0 {
        side1Pos = posV + {signX, signY, 0}
        side2Pos = posV + {signX, 0, signZ}
    } else if up.y != 0 {
        side1Pos = posV + {signX, signY, 0}
        side2Pos = posV + {0, signY, signZ}
    } else if up.z != 0 {
        side1Pos = posV + {signX, 0, signZ}
        side2Pos = posV + {0, signY, signZ}
    }

    side1Primer, side1Pos2, ok1 := getBlockPos(primers, side1Pos)
    side2Primer, side2Pos2, ok2 := getBlockPos(primers, side2Pos)
    side1 := side1Primer.primer[side1Pos2.x][side1Pos2.y][side1Pos2.z]
    side2 := side2Primer.primer[side2Pos2.x][side2Pos2.y][side2Pos2.z]

    if side1 != 0 && side2 != 0 {return 0}
    if corner != 0 && (side1 != 0 || side2 != 0) {return 1}
    if corner != 0 || side1 != 0 || side2 != 0 {return 2}

    return 3
}

makeCorners :: proc(topLeft, bottomLeft, bottomRight, topRight: Point) -> [Corner]Point {
    return {
        .TopLeft     = topLeft,   
        .BottomLeft  = bottomLeft,   
        .BottomRight = bottomRight,   
        .TopRight    = topRight
    }
}

getFacePoints :: proc(cube: CubeFacesPoints, primers: Primers, direction: Direction) -> [Corner]Point {
    pointByVertex := [Position]Point{}

    if .SouthwestDown in cube.points {pointByVertex[.SouthwestDown] = Point{toVec3(cube.pos) + {0, 0, 0}, getAO(cube.pos, {0, 0, 0}, direction, primers)}}
    if .NorthwestDown in cube.points {pointByVertex[.NorthwestDown] = Point{toVec3(cube.pos) + {0, 0, 1}, getAO(cube.pos, {0, 0, 1}, direction, primers)}}
    if .SouthwestUp   in cube.points {pointByVertex[.SouthwestUp]   = Point{toVec3(cube.pos) + {0, 1, 0}, getAO(cube.pos, {0, 1, 0}, direction, primers)}}
    if .NorthwestUp   in cube.points {pointByVertex[.NorthwestUp]   = Point{toVec3(cube.pos) + {0, 1, 1}, getAO(cube.pos, {0, 1, 1}, direction, primers)}}
    if .SoutheastDown in cube.points {pointByVertex[.SoutheastDown] = Point{toVec3(cube.pos) + {1, 0, 0}, getAO(cube.pos, {1, 0, 0}, direction, primers)}}
    if .NortheastDown in cube.points {pointByVertex[.NortheastDown] = Point{toVec3(cube.pos) + {1, 0, 1}, getAO(cube.pos, {1, 0, 1}, direction, primers)}}
    if .SoutheastUp   in cube.points {pointByVertex[.SoutheastUp]   = Point{toVec3(cube.pos) + {1, 1, 0}, getAO(cube.pos, {1, 1, 0}, direction, primers)}}
    if .NortheastUp   in cube.points {pointByVertex[.NortheastUp]   = Point{toVec3(cube.pos) + {1, 1, 1}, getAO(cube.pos, {1, 1, 1}, direction, primers)}}

    switch direction {
        case .Up:     return makeCorners(pointByVertex[.NortheastUp],   pointByVertex[.SoutheastUp],   pointByVertex[.SouthwestUp],   pointByVertex[.NorthwestUp])
        case .Bottom: return makeCorners(pointByVertex[.NorthwestDown], pointByVertex[.SouthwestDown], pointByVertex[.SoutheastDown], pointByVertex[.NortheastDown])
        case .North:  return makeCorners(pointByVertex[.NorthwestUp],   pointByVertex[.NorthwestDown], pointByVertex[.NortheastDown], pointByVertex[.NortheastUp])
        case .South:  return makeCorners(pointByVertex[.SoutheastUp],   pointByVertex[.SoutheastDown], pointByVertex[.SouthwestDown], pointByVertex[.SouthwestUp])
        case .East:   return makeCorners(pointByVertex[.NortheastUp],   pointByVertex[.NortheastDown], pointByVertex[.SoutheastDown], pointByVertex[.SoutheastUp])
        case .West:   return makeCorners(pointByVertex[.SouthwestUp],   pointByVertex[.SouthwestDown], pointByVertex[.NorthwestDown], pointByVertex[.NorthwestUp])
    }

    panic("Alert, bit flip by cosmic rays detect.")
}

makePoinsAndFaces :: proc(cubesPoints: [dynamic]CubeFacesPoints, primers: Primers) -> [dynamic]Face {
    faces := [dynamic]Face{}

    for cube in cubesPoints {
        if .Up     in cube.faces {append(&faces, Face{cube.pos, .Up,     cube.id, .Up, getFacePoints(cube, primers, .Up,    )})}
        if .Bottom in cube.faces {append(&faces, Face{cube.pos, .Bottom, cube.id, .Up, getFacePoints(cube, primers, .Bottom,)})}
        if .North  in cube.faces {append(&faces, Face{cube.pos, .North,  cube.id, .Up, getFacePoints(cube, primers, .North, )})}
        if .South  in cube.faces {append(&faces, Face{cube.pos, .South,  cube.id, .Up, getFacePoints(cube, primers, .South, )})}
        if .East   in cube.faces {append(&faces, Face{cube.pos, .East,   cube.id, .Up, getFacePoints(cube, primers, .East,  )})}
        if .West   in cube.faces {append(&faces, Face{cube.pos, .West,   cube.id, .Up, getFacePoints(cube, primers, .West,  )})}
    }

    return faces
}

toFlipe :: proc(a00, a01, a10, a11: f32) -> bool {
	return a00 + a11 < a01 + a10;
}

makeVertices :: proc(faces: [dynamic]Face, primers: Primers) -> ([dynamic]u32, [dynamic]f32) {
    vertices := [dynamic]f32{}
    indices := [dynamic]u32{}

    for face in faces {
        // toFlip: bool
        normal: vec3
        switch face.direction {
            case .Up:     normal = { 0, 1, 0}
            case .Bottom: normal = { 0,-1, 0}
            case .North:  normal = { 0, 0, 1}
            case .South:  normal = { 0, 0,-1}
            case .East:   normal = { 1, 0, 0}
            case .West:   normal = {-1, 0, 0}
        }
        ppPos := face.corners[.TopLeft].pos
        pmPos := face.corners[.BottomLeft].pos
        mmPos := face.corners[.BottomRight].pos
        mpPos := face.corners[.TopRight].pos
        a00 := face.corners[.TopLeft].occlusion
        a01 := face.corners[.BottomLeft].occlusion
        a10 := face.corners[.BottomRight].occlusion
        a11 := face.corners[.TopRight].occlusion
        append(&vertices, ppPos.x, ppPos.y, ppPos.z, normal.x, normal.y, normal.z, 0, 0, face.corners[.TopLeft].occlusion)
        append(&vertices, pmPos.x, pmPos.y, pmPos.z, normal.x, normal.y, normal.z, 0, 1, face.corners[.BottomLeft].occlusion)
        append(&vertices, mmPos.x, mmPos.y, mmPos.z, normal.x, normal.y, normal.z, 1, 1, face.corners[.BottomRight].occlusion)
        append(&vertices, mpPos.x, mpPos.y, mpPos.z, normal.x, normal.y, normal.z, 1, 0, face.corners[.TopRight].occlusion)
        toFlip := toFlipe(a01, a00, a10, a11)
        n := u32(len(vertices) / 9)
        if toFlip {
            append(&indices, n - 4, n - 3, n - 2, n - 2, n - 1, n - 4)
        } else {
            append(&indices, n - 1, n - 4, n - 3, n - 3, n - 2, n - 1)
        }
    }

    return indices, vertices
}

generateMesh :: proc(chunk: world.Chunk) -> ([dynamic]u32, [dynamic]f32) {
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

    cubes := filterCubes(primers)
    cubesFaces := makeCubes(primers, cubes)
    delete(cubes)
    cubesPoints := makeCubePoints(cubesFaces)
    delete(cubesFaces)
    faces := makePoinsAndFaces(cubesPoints, primers)
    delete(cubesPoints)
    indices, vertices := makeVertices(faces, primers)
    delete(faces)

    return indices, vertices
}
