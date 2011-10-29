-- A test for luajit ffi based wavpack bindings

local ioopen = io.open

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

local size = info.num_samples * info.channels
local dest = ffi.new ( "int32_t[?]" , size )
print ( "Decoded " , wc:unpack ( dest , info.num_samples ) )

local out_buff = ffi.new ( "int16_t[?]" , size )
for i=0,size-1 do
	out_buff [ i ] = dest [ i ]
end

local out = assert ( ioopen ( 'samples.raw' , 'wb' ) )
out:write ( ffi.string ( out_buff , ffi.sizeof ( out_buff ) ) )
out:close ( )
