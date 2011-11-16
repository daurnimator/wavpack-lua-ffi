-- FFI binding to WavPack

local rel_dir = assert ( debug.getinfo ( 1 , "S" ).source:match ( [=[^@(.-[/\]?)[^/\]*$]=] ) , "Current directory unknown" ) .. "./"

local assert , error = assert , error

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

ffi_add_include_dir ( rel_dir )

assert ( jit , "jit table unavailable" )
local wavpack
if jit.os == "Windows" then
	wavpack = ffi.load ( rel_dir .. "wavpackdll" ) -- Yeah, its actually called wavpackdll.dll
elseif jit.os == "Linux" or jit.os == "OSX" or jit.os == "POSIX" or jit.os == "BSD" then
	ffi_add_include_dir ( "/usr/bin/wavpack/" )
	wavpack = ffi.load ( [[libwavpack]] )
else
	error ( "Unknown platform" )
end

local cdefs = ffi_defs ( rel_dir .. "wavpack_defs.h" , { [[wavpack.h]] } , true )
-- Make WavpackContext an incomplete type instead of a void so that we can attach metamethods
local cdefs , n = cdefs:gsub ( [[typedef%s+void%s+WavpackContext%s*;]] , [[typedef struct WavpackContext WavpackContext;]] )
assert ( n == 1 , "Strange header file" )
ffi.cdef ( cdefs )


local wavpack_defs = ffi_process_defines ( [[wavpack.h]] )

local M = {
	libversion = ffi.string ( wavpack.WavpackGetLibraryVersionString() ) ;
}

local wc_methods = { }
local wc_mt = {
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
	ffi.gc ( wc , wavpack.WavpackCloseFile )
	return wc
end
M.openfile = open

function wc_methods:getinfo ( )
	local mask = wavpack.WavpackGetMode ( self )
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

		channels 			= wavpack.WavpackGetNumChannels ( self ) ;
		sample_rate 		= wavpack.WavpackGetSampleRate ( self ) ;
		bits_per_sample 	= wavpack.WavpackGetBitsPerSample ( self ) ;
		bytes_per_sample 	= wavpack.WavpackGetBytesPerSample ( self ) ;
		version 			= wavpack.WavpackGetVersion ( self ) ;
		num_samples 		= wavpack.WavpackGetNumSamples ( self ) ;
		filesize 			= wavpack.WavpackGetFileSize ( self ) ;
		ratio	 			= wavpack.WavpackGetRatio ( self ) ;
		avg_bitrate			= wavpack.WavpackGetAverageBitrate ( self , true) ;
		avg_bitrate_no_wvc	= wavpack.WavpackGetAverageBitrate ( self , false) ;
		norm 				= wavpack.WavpackGetFloatNormExp ( self ) ;
		--md5sum 			= wavpack.WavpackGetMD5Sum ( self ) ;
	}
end

function wc_methods:seek ( pos )
	local res = wavpack.WavpackSeekSample ( self , pos ) ~= 0
	if not res then
		error ( "Could not seek" )
	end
end

function wc_methods:pos ( )
	local pos = wavpack.WavpackGetSampleIndex ( self )
	if pos == -1 then return false
	else return pos end
end

-- dest should be a buffer of samples*channels of int32_t
wc_methods.unpack = wavpack.WavpackUnpackSamples

function wc_methods:instant_bitrate ( )
	local bitrate = wavpack.WavpackGetInstantBitrate ( self )
	if bitrate == 0 then return false
	else return bitrate end
end

wc_methods.num_errors = wavpack.WavpackGetNumErrors

function wc_methods:lossy_blocks ( )
	return wavpack.WavpackLossyBlocks ( self ) ~= 0
end

function wc_methods:progress ( )
	local prog = wavpack.WavpackGetProgress ( self )
	if prog == -1 then return false
	else return prog end
end

function wc_methods:lasterr ( )
	return ffi.string ( wavpack.WavpackGetErrorMessage ( self ) )
end

ffi.metatype ( "struct WavpackContext" , wc_mt )

return M
