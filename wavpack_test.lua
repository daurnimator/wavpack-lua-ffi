-- A test for luajit ffi based wavpack bindings

local ioopen = io.open


package.path = "./?/init.lua;" .. package.path
package.loaded [ "WavPack" ] = dofile ( "init.lua" )
local wavpack = require"WavPack"
local ffi = require"ffi"

print ( "WavPack Library, Version " .. wavpack.libversion )

local inputfile = arg[1] or [[W:\Random Downloaded\[07] The Mountain Goats - No Children.wv]]

local wc = wavpack.openfile ( inputfile )
local info = wc:getinfo ( )
for k , v in pairs ( info ) do print ( k , v ) end

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
