-- FFI binding to WavPack

local general 				= require"general"
local current_script_dir 	= general.current_script_dir

local rel_dir = assert ( current_script_dir ( ) , "Current directory unknown" )

local ffi 					= require"ffi"
local ffi_util 				= require"ffi_util"
local ffi_add_include_dir 	= ffi_util.ffi_add_include_dir
local ffi_defs 				= ffi_util.ffi_defs
local ffi_process_defines 	= ffi_util.ffi_process_defines

local bit					= require"bit"
local band 					= bit.band
local lshift , rshift 		= bit.lshift , bit.rshift

local function lowest_bit_set ( v )
	local c = 32
	if 0 ~= v then c = c - 1 end
	if 0 ~= band ( v , 0x0000FFFF ) then c = c - 16 end
	if 0 ~= band ( v , 0x00FF00FF ) then c = c - 8 end
	if 0 ~= band ( v , 0x0F0F0F0F ) then c = c - 4 end
	if 0 ~= band ( v , 0x33333333 ) then c = c - 2 end
	if 0 ~= band ( v , 0x55555555 ) then c = c - 1 end
	return c
end
local function bmask ( num , mask )
	return rshift ( band ( num , mask ) , lowest_bit_set ( mask ) )
end

ffi_add_include_dir ( [[U:\Programming\wavpack\wavpackdll\]] )
ffi_defs ( rel_dir .. "defs.h" , { [[wavpack.h]] } )

local wavpack
assert ( jit , "jit table unavailable" )
if jit.os == "Windows" then
	wavpack = ffi.load ( rel_dir .. "wavpackdll" ) -- Yeah, its actually called wavpackdll.dll
--elseif jit.os == "Linux" or jit.os == "OSX" or jit.os == "POSIX" or jit.os == "BSD" then
else
	error ( "Unknown platform" )
end

local wavpack_defs = ffi_process_defines( [[wavpack.h]] )

local M = {
	libversion = ffi.string ( wavpack.WavpackGetLibraryVersionString() ) ;
}

wc_methods = { }
wc_mt = {
	__index = wc_methods ;
}

local errmsg = ffi.new ( "char[80]" )
local function open ( filename )
	assert ( filename , "No filename given" )
	local flags = wavpack_defs.OPEN_WVC + wavpack_defs.OPEN_NORMALIZE
	local wc = wavpack.WavpackOpenFileInput ( filename , errmsg , flags , 15 ) -- 15 for 16 bit audio
	if wc == nil then
		error ( ffi.string ( errmsg ) )
	end
	return setmetatable ( { WavpackContext = wc } , wc_mt )
end
M.openfile = open

local function close ( self )
	assert ( wavpack.WavpackCloseFile ( self.WavpackContext ) == nil )
end
wc_mt.__gc = close

function wc_methods:getinfo ( )
	local wc = self.WavpackContext
	local mask = wavpack.WavpackGetMode ( wc )
	return {
		WVC 		= bmask ( mask , wavpack_defs.MODE_WVC ) ~= 0 ;
		lossless 	= bmask ( mask , wavpack_defs.MODE_LOSSLESS ) ~= 0 ;
		hybrid 		= bmask ( mask , wavpack_defs.MODE_HYBRID ) ~= 0 ;
		float 		= bmask ( mask , wavpack_defs.MODE_FLOAT ) ~= 0 ;
		--valid_tag 	= bmask ( mask , wavpack_defs.MODE_VALID_TAG ) ~= 0 ;
		high 		= bmask ( mask , wavpack_defs.MODE_HIGH ) ~= 0 ;
		fast 		= bmask ( mask , wavpack_defs.MODE_FAST ) ~= 0 ;
		extra 		= bmask ( mask , wavpack_defs.MODE_EXTRA ) ~= 0 ;
		xmode 		= bmask ( mask , wavpack_defs.MODE_XMODE ) ;
		--apetag 		= bpeek ( mask , wavpack_defs.MODE_APETAG ) ~= 0 ;
		selfextract = bmask ( mask , wavpack_defs.MODE_SFX ) ~= 0 ;
		veryhigh 	= bmask ( mask , wavpack_defs.MODE_VERY_HIGH ) ~= 0 ;
		MD5			= bmask ( mask , wavpack_defs.MODE_MD5 ) ~= 0 ;
		DNS 		= bmask ( mask , wavpack_defs.MODE_DNS ) ~= 0 ;

		channels 			= wavpack.WavpackGetNumChannels ( wc ) ;
		sample_rate 		= wavpack.WavpackGetSampleRate ( wc ) ;
		bits_per_sample 	= wavpack.WavpackGetBitsPerSample ( wc ) ;
		bytes_per_sample 	= wavpack.WavpackGetBytesPerSample ( wc ) ;
		version 			= wavpack.WavpackGetVersion ( wc ) ;
		num_samples 		= wavpack.WavpackGetNumSamples ( wc ) ;
		filesize 			= wavpack.WavpackGetFileSize ( wc ) ;
		ratio	 			= wavpack.WavpackGetRatio ( wc ) ;
		avg_bitrate			= wavpack.WavpackGetAverageBitrate ( wc , true) ;
		avg_bitrate_no_wvc	= wavpack.WavpackGetAverageBitrate ( wc , false) ;
		norm 				= wavpack.WavpackGetFloatNormExp ( wc ) ;
		--md5sum 			= wavpack.WavpackGetMD5Sum ( wc ) ;
	}
end

-- dest should be a buffer of samples*channels of int32_t
function wc_methods:unpack ( dest , n )
	return wavpack.WavpackUnpackSamples ( self.WavpackContext , dest , n )
end

function wc_methods:seek ( pos )
	local res = wavpack.WavpackSeekSample ( self.WavpackContext , pos ) ~= 0
	if not res then
		error ( "Could not seek" )
	end
end

function wc_methods:pos ( )
	local pos = wavpack.WavpackGetSampleIndex ( self.WavpackContext )
	if pos == -1 then return false
	else return pos end
end

function wc_methods:instant_bitrate ( )
	return wavpack.WavpackGetInstantBitrate ( self.WavpackContext )
end

function wc_methods:num_errors ( )
	return wavpack.WavpackGetNumErrors ( self.WavpackContext )
end

function wc_methods:lossy_blocks ( )
	return wavpack.WavpackLossyBlocks ( self.WavpackContext )
end

function wc_methods:progress ( )
	return wavpack.WavpackGetProgress ( self.WavpackContext )
end

function wc_methods:lasterr ( wc )
	return ffi.string ( wavpack.WavpackGetErrorMessage ( self.WavpackContext ) )
end

return M
