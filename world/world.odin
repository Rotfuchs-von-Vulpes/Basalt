package world

import "../skeewb"
import "core:math/noise"
import "core:math"
import "core:fmt"
import "../util"

Primer :: [32 * 32 * 32]u32
HeightMap :: [32 * 32]i32

emptyPrimer := Primer{0..<(32 * 32 * 32) = 0}

iVec2 :: [2]i32
iVec3 :: [3]i32

Chunk :: struct {
    x, y, z: i32,
    primer: Primer,
}

chunkMap := make(map[iVec3]Chunk)
terrainMap := make(map[iVec2]HeightMap)

// getNoised :: proc(a, b: i32, c, d: int) -> int {
//     posX := f64(a)
//     posZ := f64(b)
//     x := f64(c)
//     z := f64(d)
//     return int(math.floor(32 * (0.5 * noise.noise_2d(0, {posX + x / 32, posZ + z / 32}) + 0.5)))
// }

Noise :: struct {
    seed: i64,
    octaves: int,
    lacunarity: f64,
    persistence: f32,
    scale: f64,
}

pow :: proc(n: f32, exp: int) -> f32 {
    tmp := n
    for i in 1..<exp {tmp *= n}
    return tmp
}

seed: i64 = 1;
continentalness := Noise{seed, 8, 2.25, 0.5, 0.01}
erosion := Noise{seed + 1, 4, 2, 0.375, 0.25}
peaksAndValleys := Noise{seed + 2, 12, 2, 0.75, 0.375}

peake :: proc(n: f32) -> f32 {
    return n * n * 0.25
}

erode :: proc(n: f32) -> f32 {
    return math.clamp(n, 0, 1)
}

mix :: proc(continent, eroding, peaking: f32) -> f32 {
    return continent < 0.5 ? continent : continent + erode(eroding) * peake(peaking);
}

getNoised :: proc(n: Noise, x, z: f64) -> f32 {
    noised: f32 = 0

    for i in 0..<n.octaves {
        noised += pow(n.persistence, i) * noise.noise_2d(n.seed + i64(i), {n.lacunarity * n.scale * x, n.lacunarity * n.scale * z})
    }

    return 0.5 * noised + 0.5
}

getTerrain :: proc(x, z: i32, i, j: int) -> i32 {
    posX := f64(x) + f64(i) / 32
    posZ := f64(z) + f64(j) / 32
    continent := getNoised(continentalness, posX, posZ)
    eroding := getNoised(erosion, posX, posZ)
    peaking := getNoised(peaksAndValleys, posX, posZ)
    earlyTerrain := mix(continent, eroding, peaking)

    return i32(31 * earlyTerrain)
}

getNewChunk :: proc(x, y, z: i32, heightMap: HeightMap) -> Chunk {
    primer := Primer{0..<(32 * 32 * 32) = 0}
    
    for i in 0..<32 {
        for j in 0..<32 {
            height := int(heightMap[i * 32 + j])
            for k in 0..<height {
                primer[i * 32 * 32 + j * 32 + k] = 1
            }
        }
    }

    return Chunk{x, y, z, primer}
}

getHeightMap :: proc(x, z: i32) -> HeightMap {
    heightMap: HeightMap = {}

    for i in 0..<32 {
        for j in 0..<32 {
            height := getTerrain(x, z, i, j)
            heightMap[i * 32 + j] = height
        }
    }

    return heightMap
}

chopp :: proc(heightMap: ^HeightMap) -> [dynamic]HeightMap {
    heightsMaps: [dynamic]HeightMap = {HeightMap{0..<(32 * 32) = 0}}

    for height, idx in heightMap {
        tmp := height
        if tmp > 31 {
            if len(heightsMaps) == 1 {append(&heightsMaps, HeightMap{0..<(32 * 32) = 0})}
            heightsMaps[0][idx] = 32
            heightsMaps[1][idx] = tmp - 32
        } else {
            heightsMaps[0][idx] = tmp
        }
    }

    return heightsMaps
}

evalTerrain :: proc(x, z: i32) -> [dynamic]HeightMap {
    pos := iVec2{x, z}
    terrain, ok, _ := util.map_force_get(&terrainMap, pos)
    if ok {
        terrain^ = getHeightMap(x, z)
    }
    return chopp(terrain)
}

eval :: proc(x, y, z: i32, terrain: HeightMap) -> Chunk {
    pos := iVec3{x, y, z}
    chunk, ok, _ := util.map_force_get(&chunkMap, pos)
    if ok {
        chunk^ = getNewChunk(x, y, z, terrain)
    }
    return chunk^
}

peak :: proc(x, y, z: i32, radius: i32) -> [dynamic]Chunk {
    chunksToView := [dynamic]Chunk{}
    radiusP := radius + 1

    for i := -radiusP; i <= radiusP; i += 1 {
        for j := -radiusP; j <= radiusP; j += 1 {
            terrains := evalTerrain(x + i, z + j)
            defer delete(terrains)
            for terrain, height in terrains {
                chunk := eval(x + i, i32(height), z + j, terrain);
                if (i != -radiusP && i != radiusP) && (j != -radiusP && j != radiusP) {append(&chunksToView, chunk)}
            }
        }
    }

    return chunksToView
}

nuke :: proc() {
    delete(chunkMap)
}
