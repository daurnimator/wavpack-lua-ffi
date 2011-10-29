-- A test for luajit ffi based wavpack bindings

local general 				= require"general"
local pretty 				= general.pretty_print
local current_script_dir 	= general.current_script_dir
local rel_dir = assert ( current_script_dir ( ) , "Current directory unknown" )
package.path = package.path .. ";" .. rel_dir .. "../?/init.lua"

local wavpack = require"WavPack"
local ffi = require"ffi"

print ( "WavPack Library, Version " .. wavpack.libversion )

local inputfile = arg[1] or [[W:\Random Downloaded\[07] The Mountain Goats - No Children.wv]]

local wc = wavpack.openfile ( inputfile )
local info = wc:getinfo ( )
pretty ( info )

dest = ffi.new ( "int32_t[?]" , info.num_samples * info.channels )
wc:unpack ( dest , info.num_samples )
