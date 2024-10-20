local SS13 = require("SS13")
-- /obj/docking_port/stationary{
-- 	dir = 2;
-- 	dwidth = 2;
-- 	height = 13;
-- 	name = "port bay 2";
-- 	shuttle_id = "ferry_home";
-- 	width = 5
-- 	},

local id = "admin_port_2"
local name = "John Nanotrasen Crash Location"

local location = SS13.get_runner_client():get_var("mob"):get_var("loc")
local stationary = SS13.new("/obj/docking_port/stationary", location)
stationary:set_var("shuttle_id", id)
stationary:set_var("name", name)
stationary:set_var("dwidth", 2)
stationary:set_var("height", 13)
stationary:set_var("width", 5)
stationary:set_var("dir", 1)