-- reslister --
--local lfs = require'lfs'
local minigcompat = require'minigcompat'
require'binfuncs'
local bsplib = require'bsplib'
--local inspect = require'inspect'

local input_file = ...
if not input_file then
    print[[Usage: gmod_bsp_optimizer 'c:\mymap\map.bsp']]
    return
end

input_file = assert(io.open(input_file, 'r+b'))


local function main()
    print'Optimizing BSP...'
    local bsp = bsplib.open(input_file)

    for k, v in pairs(bsp:GetStaticProps().entries) do
        if bit.band(v.Flags, 1) == 0 then
            --print(v.Flags,v.FadeMinDist)
			input_file:Seek(v.Flags_Offset)
            input_file:WriteByte(bit.bor(v.Flags, 1))
        end

        if v.FadeMinDist == 0 and v.FadeMinDist == 0 then
            input_file:Seek(v.FadeMinDist_Offset)
			input_file:WriteFloat(3200)
            input_file:WriteFloat(3600)
        end
    end
end

main()