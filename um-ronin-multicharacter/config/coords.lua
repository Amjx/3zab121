---@class Coords
---@field label string
---@field coords vector4
---@field mode? number
---@field emote? { animName?: string, scenario?: string }
---@field group? table<string> list of jobs or gangs that can use this coord
---@field camCoords? vector4 only for mode=3:
---@field fov? number only for mode=3:
---@field blurOptions? { near?: number, far?: number } only for mode =3:
---@field focusOffset? vector3 only for mode =3:
---@return table<string, Coords>

--[[
    https://docs.uyuyorumstore.com/scripts/um-ronin-multi/how-to/coords
]]
return {
    -- Mode 1 um mode examples (default mode)
    {
        label = 'main default coords',
        coords = vec4(-2081.84, 2606.33, 3.08, 117.31),
    },

    {
        label = 'main mode 1 coords 2',
        coords = vec4(-1595.47, 2101.84, 66.61, 241.39),
    },

    {
        label = 'main mode 1 coords 3',
        coords = vec4(-3259.45, 967.45, 8.83, 187.65),
    },

    {
        label = 'main mode 1 coords 4',
        coords = vec4(-1718.85, 368.22, 89.73, 70.68),
    },

    {
        label = 'main mode 1 coords 5',
        coords = vec4(-852.73, -226.99, 61.02, 354.04),
    },

    -- Mode 2 xyz mode examples
    {
        label = 'drinking 1',
        coords = vec4(343.14, -73.08, 154.83, 326.88),
        mode = 2,
    },

    {
        label = 'drinking 2',
        coords = vec4(368.14, -1636.53, 93.77, 312.08),
        mode = 2,
    },

    {
        label = 'drinking 3',
        coords = vec4(3439.25, 5442.83, 12.7, 221.3),
        mode = 2,
    },

    {
        label = 'drinking on the stab city bridge',
        coords = vec4(136.28, 3357.62, 49.89, 330.34),
        mode = 2,
    },

    {
        label = 'drinking in mirror park',
        coords = vec4(1079.36, -570.11, 56.78, 257.69),
        mode = 2,
    },

    {
        label = 'drinking on the roof',
        coords = vec4(-980.1, 662.18, 165.66, 185.35),
        mode = 2,
    },

    -- Mode 3 free cam mode examples
    {
        label = 'test free cam mode',
        coords = vec4(-2541.15, 2334.54, 33.06, 334.88),    -- Ped spawn coords
        camCoords = vec4(-2538.56, 2337.39, 33.56, 150.19), -- Camera coords
        fov = 20,                                           -- Camera FOV (optional)
        focusOffset = vec3(0.5, 0, 0.5),                    -- Focus offset (optional)
        emote = {
            animName = 'wine3',
        },
        blurOptions = {
            near = 0.5,
            far = 5.0,
        },
        mode = 3,
    },

    -- Job based coords examples
    {
        label = 'police station',
        coords = vec4(444.37, -984.33, 30.69, 71.35),
        group = { 'police', 'mrpd' },
        emote = {
            scenario = 'WORLD_HUMAN_COP_IDLES',
        },
    },

    {
        label = 'hospital',
        coords = vec4(352.82, -589.3, 43.31, 235.57),
        group = { 'ambulance', 'ems' },
        emote = {
            animName = 'wine3',
        },
    },
}
