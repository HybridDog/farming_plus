-- main `S` code in init.lua
local S = farming.S

local banana_seed = 321

-- TODO: test if get_random works at all
local function get_random(pos)
	return PseudoRandom(math.abs(pos.x + pos.y * 3 + pos.z * 5) + banana_seed)
end

local function facedir_to_offset(dir, zoff)
	if dir == 0 then
		return zoff
	end
	if dir == 1 then
		return 1
	end
	if dir == 2 then
		return -zoff
	end
	return -1
end

-- TODO: hopefully it doesn't look too swastika
local c_banana_stem, c_banana_leaf, c_banana_bow, c_banana_trager
local function calc_banana(pos, stem_h, area, nodes, param2s, pr)
	local yo = area.ystride
	local zo = area.zstride
	local orient = pr:next(0, 3)
	local vp = area:indexp(pos)
	local vi = vp
	for _ = 0, stem_h do
		nodes[vi] = c_banana_stem
		vi = vi + yo
	end
	local haveleaves = {{},{},{},{}}
	-- beware loop order for leaf_rot
	local leaf_rot = false
	for lorient = 0,3 do
		for i = 2, stem_h+2 do
			-- put leaves with a 1 to 2 vertical air hole between them
			if not haveleaves[lorient+1][i-1]
			and (i > stem_h or pr:next(1, 2) == 2
				or (i >= 4 and not haveleaves[lorient+1][i-2])
			) then
				haveleaves[lorient+1][i] = true
				local dir = facedir_to_offset(lorient, zo)
				local vi = vp + dir + i * yo
				if lorient == orient then
					if i == stem_h then
						-- place next to bananas
						local ndir = facedir_to_offset((lorient+1) % 4, zo)
						vi = vi + ndir
					elseif i == stem_h+1 then
						-- place onto the next bow
						vi = vi + dir
					end
				end
				-- set a leaf where it's near the stem
				nodes[vi] = c_banana_leaf
				param2s[vi] = lorient

				-- set a leaf touching the previous one on only an upper corner
				vi = vi + dir + yo
				nodes[vi] = c_banana_leaf
				param2s[vi] = lorient

				-- set a leaf next to it, alternatingly left and right
				local lnorient
				if leaf_rot then
					lnorient = (lorient + 1) % 4
				else
					lnorient = (lorient + 3) % 4
				end
				leaf_rot = not leaf_rot
				local ndir = facedir_to_offset(lnorient, zo)
				vi = vi + ndir
				nodes[vi] = c_banana_leaf
				param2s[vi] = lorient
			end
		end
	end

	-- put the bow, banana and top leaves
	nodes[vi] = c_banana_bow
	param2s[vi] = orient
	local dir = facedir_to_offset(orient, zo)
	local vi2 = vi + dir
	nodes[vi2] = c_banana_bow
	param2s[vi2] = (orient + 2) % 4
	vi2 = vi2 - yo
	nodes[vi2] = c_banana_trager
	vi = vi + yo
	nodes[vi] = c_banana_leaf
	param2s[vi] = orient
	vi2 = vi2 + yo * pr:next(2, 3)
	nodes[vi2] = c_banana_leaf
	param2s[vi2] = orient
end

local function spawn_banana(pos)
	local t1 = minetest.get_us_time()

	local pr = get_random(pos)
	local stem_h = math.random(4, 6)

	-- the maximum width represents 1 bow + 2 banana nodes
	local vwidth = 3
	-- the stem grows from 0 to <stem_h>, above there's a bow and at max 2
	-- leaves
	local vheight = stem_h + 3

	local manip = minetest.get_voxel_manip()
	local emin, emax = manip:read_from_map(
		{x = pos.x - vwidth, y = pos.y, z = pos.z - vwidth},
		{x = pos.x + vwidth, y = pos.y + vheight, z = pos.z + vwidth}
	)
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local nodes = manip:get_data()
	local param2s = manip:get_param2_data()

	calc_banana(pos, stem_h, area, nodes, param2s, pr)

	manip:set_data(nodes)
	manip:set_param2_data(param2s)
	manip:write_to_map()

	minetest.log("info", "[farming_plus] a banana plant grew at " ..
		minetest.pos_to_string(pos) .. " in " ..
		(minetest.get_us_time() - t1) / 1000000 .. " s")
end


minetest.register_node("farming_plus:banana_stem", {
	tiles = {"farming_banana_stem_top.png", "farming_banana_stem_top.png",
		"farming_banana_stem_side.png"},
	groups = {snappy=3, flammable=2, not_in_creative_inventory=1},
	drop = "default:mese",
	sounds = default.node_sound_leaves_defaults(),
	on_place = function(_,_, pt)
		spawn_banana(pt.above)
	end
})

minetest.register_node("farming_plus:banana_stem_bow", {
	tiles = {"farming_banana_stem_side.png"},
	drawtype = "nodebox",
	node_box = {
	type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0, 0.5},
			{-0.5, 0, 0, 0.5, 0.5, 0.5},
		},
	},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {snappy=3, flammable=2, not_in_creative_inventory=1},
	drop = "default:mese",
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("farming_plus:banana_leaf", {
	drawtype = "allfaces_optional",
	tiles = {"farming_banana_leaves.png"},
	paramtype = "light",
	groups = {snappy=3, leafdecay=3, flammable=2, not_in_creative_inventory=1},
	drop = {
		max_items = 1,
		items = {
			{
				items = {'farming_plus:banana_sapling'},
				rarity = 20,
			},
			{
				items = {},
			},
		}
	},
	sounds = default.node_sound_leaves_defaults(),
})

-- TODO: make it look like many bananas
minetest.register_node("farming_plus:bananas", {
	description = S"Banana Träger",
	tiles = {"farming_banana.png"},
	drawtype = "torchlike",
	paramtype = "light",
	groups = {fleshy=3,dig_immediate=3,flammable=2,leafdecay=3,
		leafdecay_drop=1, not_in_creative_inventory=1},
	sounds = default.node_sound_defaults(),

	-- TODO: variable drop count
	drop = "farming_plus:banana 5",
})

c_banana_stem = minetest.get_content_id"farming_plus:banana_stem"
c_banana_bow = minetest.get_content_id"farming_plus:banana_stem_bow"
c_banana_leaf = minetest.get_content_id"farming_plus:banana_leaf"
c_banana_trager = minetest.get_content_id"farming_plus:bananas"


-- TODO: generate, sapling, textures

minetest.register_node("farming_plus:banana_sapling", {
	description = S("Banana Tree Sapling"),
	drawtype = "plantlike",
	tiles = {"farming_banana_sapling.png"},
	inventory_image = "farming_banana_sapling.png",
	wield_image = "farming_banana_sapling.png",
	paramtype = "light",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-0.3, -0.5, -0.3, 0.3, 0.35, 0.3}
	},
	groups = {snappy = 2, dig_immediate = 3, flammable = 2,
		attached_node = 1, sapling = 1},
	sounds = default.node_sound_defaults(),
})

minetest.register_node("farming_plus:banana_leaves", {
	drawtype = "allfaces_optional",
	tiles = {"farming_banana_leaves.png"},
	paramtype = "light",
	groups = {snappy=3, leafdecay=3, flammable=2, not_in_creative_inventory=1},
	drop = {
		max_items = 1,
		items = {
			{
				items = {'farming_plus:banana_sapling'},
				rarity = 20,
			},
		}
	},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_abm({
	nodenames = {"farming_plus:banana_sapling"},
	interval = 60,
	chance = 20,
	action = function(pos, node)
		farming.generate_tree(pos, "default:tree", "farming_plus:banana_leaves", {"default:dirt", "default:dirt_with_grass"}, {["farming_plus:banana"]=20})
	end
})

minetest.register_on_generated(function(minp, maxp, blockseed)
	if math.random(1, 100) > 5 then
		return
	end
	local tmp = {x=(maxp.x-minp.x)/2+minp.x, y=(maxp.y-minp.y)/2+minp.y, z=(maxp.z-minp.z)/2+minp.z}
	local pos = minetest.find_node_near(tmp, maxp.x-minp.x, {"default:dirt_with_grass"})
	if pos then
		farming.generate_tree({x=pos.x, y=pos.y+1, z=pos.z}, "default:tree", "farming_plus:banana_leaves",  {"default:dirt", "default:dirt_with_grass"}, {["farming_plus:banana"]=10})
	end
end)

minetest.register_node("farming_plus:banana", {
	description = S("Banana"),
	tiles = {"farming_banana.png"},
	inventory_image = "farming_banana.png",
	wield_image = "farming_banana.png",
	drawtype = "torchlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	groups = {fleshy=3,dig_immediate=3,flammable=2,leafdecay=3,leafdecay_drop=1},
	sounds = default.node_sound_defaults(),

	on_use = minetest.item_eat(6),
})
