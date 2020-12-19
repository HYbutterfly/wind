local game = {}

game.classic = {
	rookie = {min = 5000, max = 300000}, 			-- 新手场
	junior = {min = 150000, max = math.huge}, 		-- 初级场
	elite = {min = 1000000, max = math.huge}, 		-- 精英场
	master = {min = 8000000, max = math.huge}, 		-- 大师场
}

game.noshuffle = {
	rookie = {min = 5000, max = 400000}, 			-- 新手场
	junior = {min = 250000, max = math.huge}, 		-- 初级场
	elite = {min = 2000000, max = math.huge}, 		-- 精英场
	master = {min = 12000000, max = math.huge}, 	-- 大师场
	supreme = {min = 60000000, max = math.huge}		-- 至尊场
}









return game