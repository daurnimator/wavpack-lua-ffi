-- FFI binding to WavPack

local general 				= require"general"
local current_script_dir 	= general.current_script_dir

local rel_dir = assert ( current_script_dir ( ) , "Current directory unknown" )

local ffi 					= require"ffi"
local ffi_util 				= require"ffi_util"
local ffi_add_include_dir 	= ffi_util.ffi_add_include_dir
local ffi_defs 				= ffi_util.ffi_defs

ffi_add_include_dir ( [[U:\Programming\wavpack\wavpackdll]] )
ffi_defs ( rel_dir .. "defs.h" , { [[wavpack.h]] } )

local wavpack
assert ( jit , "jit table unavailable" )
if jit.os == "Windows" then
	wavpack = ffi.load ( rel_dir .. "wavpackdll" ) -- Yeah, its actually called wavpackdll.dll
--elseif jit.os == "Linux" or jit.os == "OSX" or jit.os == "POSIX" or jit.os == "BSD" then
else
	error ( "Unknown platform" )
end

