-- main `S` code in init.lua
local S = farming.S

-- TODO: hopefully it doesn't look too swastika
local function calc_banana(pos, stem_h, area, nodes, param2s, pr)
	local set = minetest.set_node
	local orient = math.random(0, 3)
	for i = 0, stem_h do
		set({x=pos.x, y=pos.y+i, z=pos.z},
			{name="farming_plus:banana_stem"})
	end
	local haveleaves = {{},{},{},{}}
	-- beware loop order for leaf_rot
	local leaf_rot = false
	for lorient = 0,3 do
		for i = 2, stem_h+2 do
			-- put leaves with a 1 to 2 vertical air hole between them
			if not haveleaves[lorient+1][i-1]
			and (i > stem_h or math.random() > 0.5
				or (i >= 4 and not haveleaves[lorient+1][i-2])
			) then
				haveleaves[lorient+1][i] = true
				local dir = minetest.facedir_to_dir(lorient)
				local lp = vector.add(pos, dir)
				lp.y = lp.y + i
				if lorient == orient then
					if i == stem_h then
						-- place next to bananas
						local ndir = minetest.facedir_to_dir((lorient+1) % 4)
						lp = vector.add(lp, ndir)
					elseif i == stem_h+1 then
						-- place onto the next bow
						lp = vector.add(lp, dir)
					end
				end
				-- set a leaf where it's near the stem
				set(lp, {name="farming_plus:banana_leaf", param2=lorient})

				-- set a leaf touching the previous one on only an upper corner
				lp = vector.add(lp, dir)
				lp.y = lp.y+1
				set(lp, {name="farming_plus:banana_leaf", param2=lorient})

				-- set a leaf next to it, alternatingly left and right
				local lnorient
				if leaf_rot then
					lnorient = (lorient + 1) % 4
				else
					lnorient = (lorient + 3) % 4
				end
				leaf_rot = not leaf_rot
				local ndir = minetest.facedir_to_dir(lnorient)
				lp = vector.add(lp, ndir)
				set(lp, {name="farming_plus:banana_leaf", param2=lorient})
			end
		end
	end

	-- put the bow, banana and top leaves
	local p = {x=pos.x, y=pos.y+stem_h+1, z=pos.z}
	set(p, {name="farming_plus:banana_stem_bow", param2=orient})
	local dir = minetest.facedir_to_dir(orient)
	local p2 = vector.add(p, dir)
	set(p2, {name="farming_plus:banana_stem_bow", param2=(orient + 2) % 4})
	p2.y = p2.y-1
	set(p2, {name="farming_plus:bananas"})
	p.y = p.y+1
	set(p, {name="farming_plus:banana_leaf", param2=orient})
	p2.y = p2.y+1 + math.random(2)
	set(p2, {name="farming_plus:banana_leaf", param2=orient})
end

local function spawn_banana(pos)
	local stem_h = math.random(4, 6)
	calc_banana(pos, stem_h)
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
