-- main `S` code in init.lua
local S = farming.S

local banana_seed = 321

-- I'm not sure if get_random works at all
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

local c_banana_stem, c_banana_leaf, c_banana_bow, c_banana_trager, overridables
local function calc_banana(pos, stem_h, area, actual_nodes, actual_param2s, pr)
	local nodes = {}
	local param2s = {}
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
				--~ param2s[vi] = lorient

				-- set a leaf touching the previous one on only an upper corner
				vi = vi + dir + yo
				nodes[vi] = c_banana_leaf
				--~ param2s[vi] = lorient

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
				--~ param2s[vi] = lorient
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
	--~ param2s[vi] = orient
	vi2 = vi2 + yo * pr:next(2, 3)
	nodes[vi2] = c_banana_leaf
	--~ param2s[vi2] = orient

	for i,v in pairs(nodes) do
		local current_c = actual_nodes[i]
		if overridables[current_c] then
			actual_nodes[i] = v
			actual_param2s[i] = param2s[i] or actual_param2s[i]
		end
	end
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
	description = S"Banana Pseudostem",
	tiles = {"farming_banana_stem_side.png"},
	groups = {snappy=3, flammable=2},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("farming_plus:banana_stem_bow", {
	description = S"Banana Pseudostem Bow",
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
	drop = "farming_plus:banana_stem",
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("farming_plus:banana_leaves", {
	description = S"Banana Leaves",
	drawtype = "allfaces_optional",
	tiles = {"farming_banana_leaves.png"},
	paramtype = "light",
	-- unfortunately leaves don't support rotation
	--~ paramtype2 = "facedir",
	groups = {snappy=3, leafdecay=3, flammable=2},
	drop = {
		max_items = 1,
		items = {
			{
				items = {"farming_plus:banana_sapling"},
				rarity = 20,
			},
			{
				items = {},
			},
		}
	},
	sounds = default.node_sound_leaves_defaults(),
})

minetest.register_node("farming_plus:bananas", {
	description = S"Banana Carrier",
	tiles = {"farming_bananas.png"},
	drawtype = "plantlike",
	paramtype = "light",
	groups = {fleshy=3, dig_immediate=3, flammable=2, leafdecay=3,
		leafdecay_drop=1, not_in_creative_inventory=1},
	sounds = default.node_sound_defaults(),

	drop = {
		max_items = 7,
		items = {
			{
				items = {"farming_plus:banana 3"},
				rarity = 1,
			},
			{
				items = {"farming_plus:banana 2"},
				rarity = 4,
			},
			{
				items = {"farming_plus:banana 2"},
				rarity = 4,
			},
		},
	},
})

default.register_leafdecay{
	trunks = {"farming_plus:banana_stem", "farming_plus:banana_stem_bow"},
	leaves = {"farming_plus:bananas", "farming_plus:banana_leaves",
		"farming_plus:banana_stem_bow"},
	radius = 2,
}


local function simulate_abm_time(i, c)
	return i * math.ceil(math.log(1 - math.random()) / math.log((c - 1) / c))
end

minetest.register_node("farming_plus:banana_sapling", {
	description = S"Banana Sapling",
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
	groups = {snappy = 3, flammable = 2, attached_node = 1, sapling = 1},
	sounds = default.node_sound_defaults(),

	on_construct = function(pos)
		minetest.get_node_timer(pos):start(simulate_abm_time(60, 20))
	end,
	on_timer = function(pos)
		if not default.can_grow(pos) then
			minetest.get_node_timer(pos):start(300)
			return
		end
		spawn_banana(pos)
	end,

	on_place = function(itemstack, placer, pointed_thing)
		itemstack = default.sapling_on_place(itemstack, placer, pointed_thing,
			"farming_plus:banana_sapling",
			{x = -3, y = 1, z = -3},
			{x = 3, y = 9, z = 3},
			2)

		return itemstack
	end,
})

c_banana_stem = minetest.get_content_id"farming_plus:banana_stem"
c_banana_bow = minetest.get_content_id"farming_plus:banana_stem_bow"
c_banana_leaf = minetest.get_content_id"farming_plus:banana_leaves"
c_banana_trager = minetest.get_content_id"farming_plus:bananas"
local c_banana_sapling = minetest.get_content_id"farming_plus:banana_sapling"
overridables = {
	[minetest.get_content_id"air"] = true,
	[minetest.get_content_id"ignore"] = true,
	[c_banana_sapling] = true,
	[c_banana_leaf] = true,
}


local gen_height_min = 1
local gen_height_max = 30

-- firstly, generate saplings using a decoration
minetest.register_decoration{
	deco_type = "simple",
	place_on = {"default:dirt_with_grass"},
	biomes = {"rainforest", "rainforest_swamp"},
	sidelen = 16,
	noise_params = {
		offset = 0,
		scale = 0.0003,
		spread = {x = 1000, y = 1000, z = 1000},
		seed = 329,
		octaves = 3,
		persist = 0.6
	},
	y_min = gen_height_min,
	y_max = gen_height_max,
	decoration = "farming_plus:banana_sapling",
}

-- secondly, replace the saplings with grown bananas
local mg_data = {}
local mg_param2s = {}
minetest.register_on_generated(function(minp, maxp, seed)
	if maxp.y < gen_height_min
	or minp.y >= gen_height_max then
		return
	end

	local t1 = minetest.get_us_time()
	local cnt = 0

	local vm, emin, emax = minetest.get_mapgen_object"voxelmanip"
	vm:get_data(mg_data)
	vm:get_param2_data(mg_param2s)
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

	local heightmap = minetest.get_mapgen_object"heightmap"
	local hmi = 1

	local pr = PseudoRandom(seed + 73)

	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local y = heightmap[hmi]+1
			local vi = area:index(x, y, z)
			if mg_data[vi] == c_banana_sapling then
				calc_banana({x=x, y=y, z=z}, pr:next(4, 6), area, mg_data,
					mg_param2s, pr)
				cnt = cnt+1
			end
			hmi = hmi+1
		end
	end

	if cnt == 0 then
		return
	end

	vm:set_data(mg_data)
	vm:set_param2_data(mg_param2s)

	-- light calculation unfortunately takes some time
	vm:set_lighting{day=0, night=0}
	vm:calc_lighting()
	vm:write_to_map()

	minetest.log("info",
		("[farming_plus] %d bananas generated after ca. %g seconds."):format(
		cnt, (minetest.get_us_time() - t1) / 1000000))
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
