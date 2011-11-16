-- A test for luajit ffi based wavpack bindings

local FILE = arg[1]

package.path = "./?/init.lua;" .. package.path
package.loaded [ "WavPack" ] = dofile ( "init.lua" )
local wavpack = require"WavPack"

local ffi = require"ffi"

print ( "WavPack Library, Version " .. wavpack.libversion )

local wc = wavpack.openfile ( FILE )
local info = wc:getinfo ( )
print ( )
for k , v in pairs ( info ) do print ( "" , k , v ) end
print ( )

local size = info.num_samples * info.channels
local dest = ffi.new ( "int32_t[?]" , size )
print ( "Decoded" , wc:unpack ( dest , info.num_samples ) )

local out_buff = ffi.new ( "int16_t[?]" , size )
for i=0,size-1 do
	out_buff [ i ] = dest [ i ]
end

local outfilename = "samples.raw"
print ( "Writing samples out to " .. outfilename )
local out = assert ( io.open ( outfilename , "wb" ) )
out:write ( ffi.string ( out_buff , ffi.sizeof ( out_buff ) ) )
out:close ( )
