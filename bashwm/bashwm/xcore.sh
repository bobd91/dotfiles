#!/usr/bin/env bash

require io xvars

x_open_display() {
	local address display
	IFS=: read -r address display <<< $DISPLAY

	_x_readxauth "$address" $display
	_x_connect "$address" $display
	_x_setup
}

x_send_create_window() {
	local wid=$1
	local x=$2
	local y=$3
	local width=$4
	local height=$5
	local border_width=$6
	local class=$7
	local visual=$8
	local mask=${9:-0}
	local bit_count=${ _x_count_bits $mask; }

	{
	_x_beginrequest $X_CreateWindow
	write8 0
	write16 $(( 8 + bit_count ))
	write32 $wid
	write32 ${x_screen_0['root']}
	writei16 $x
	writei16 $y
	write16 $width
	write16 $height
	write16 $border_width
	write16 $class
	write32 $visual
	write32 $mask
	local v
	shift 9
	for (( v=0 ; v<bit_count ; v++ )); do
		write32 $1
		shift
	done
	} >&${_x_fd}
}

x_send_change_window_attributes() {
	local windowid=$1
	local mask=$2
	local bit_count=${ _x_count_bits $mask; }

	{
	_x_beginrequest $X_ChangeWindowAttributes
	write8 0
	write16 $(( 3 + bit_count ))
	write32 $windowid
	write32 $mask
	local i
	shift 2
	for (( i=0 ; i<bit_count ; i++ )); do
		write32 $1
		shift
	done
	} >&${_x_fd}
}

x_send_get_window_attributes() {
	local windowid=$1
	local handler=$2

	{
	_x_beginrequest $X_GetWindowAttributes \
			_x_read_get_window_attributes $windowid "$handler"
	write8 0
	write16 2
	write32 $windowid
	} >&${_x_fd}
}

x_send_destroy_window() {
	local windowid=$1

	{
	_x_beginrequest $X_DestroyWindow
	write8 0
	write16 2
	write32 $windowid
	} >&${_x_fd}
}

x_send_map_window() {
	local windowid=$1

	{
	_x_beginrequest $X_MapWindow
	write8 0
	write16 2
	write32 $windowid
	} >&${_x_fd}
}

x_send_unmap_window() {
	local windowid=$1

	{
	_x_beginrequest $X_UnmapWindow
	write8 0
	write16 2
	write32 $windowid
	} >&${_x_fd}
}

x_send_configure_window() {
	local windowid=$1
	local stack_mode=$2
	local mask=$3
	local x=$4
	local y=$5
	local width=$6
	local height=$7
	local border_width=$8
	local sibling=$9

	width=$(( width - (2 * border_width) ))
	height=$(( height - (2 * border_width) ))

	local bit_count=${ _x_count_bits $mask; }

	{
	_x_beginrequest $X_ConfigureWindow
	write8 0
	write16 $(( 3 + bit_count ))
	write32 $windowid
	write16 $mask
	writepad 2

	(( mask & X_CWX )) && writei16 $x 32
	(( mask & X_CWY )) && writei16 $y 32
	(( mask & X_CWWidth )) && write32 $width
	(( mask & X_CWHeight )) && write32 $height
	(( mask & X_CWBorderWidth )) && write32 $border_width
	(( mask & X_CWSibling )) && write32 $sibling
	(( mask & X_CWStackMode )) && write32 $stack_mode

	} >&${_x_fd}
}

x_send_synthetic_configure_notify() {
	local windowid=$1
	local stack_mode=$2
	local x=$3
	local y=$4
	local width=$5
	local height=$6
	local border_width=$7
	local sibling=$8

	(( stack_mode != X_Above )) && sibling=$X_None

	{
	_x_beginrequest $X_SendEvent
	write8 0
	write16 11
	write32 $windowid
	write32 $X_StructureNotifyMask

	write8 $X_ConfigureNotify
	write8 32
	write16 0
	write32 $windowid
	write32 $windowid
	write32 $sibling
	writei16 $x
	writei16 $y
	write16 $width
	write16 $height
	write16 $border_width
	write8 0
	writepad 5
	} >&${_x_fd}
}

x_send_get_geometry() {
	local windowid=$1
	local handler=$2

	{
	_x_beginrequest $X_GetGeometry _x_read_get_geometry $windowid "$handler"
	write8 0
	write16 2
	write32 $windowid
	} >&${_x_fd}
}

x_send_query_tree() {
	local handler=$2

	{
	_x_beginrequest $X_QueryTree _x_read_query_tree "$handler"
	write8 0
	write16 2
	write32 ${x_screen_0['root']}
	} >&${_x_fd}
}

x_send_intern_atom() {
	local name=$1
	local handler=$2
	local name_len=${#name}
	local name_pad=$(pad4 name_len)
	local req_len=$(( 2 + (name_len + name_pad) / 4 ))
	
	{
	_x_beginrequest $X_InternAtom _x_read_intern_atom $name "$handler"
	write8 0
	write16 $req_len 
	write16 $name_len
	writepad 2
	writechars $name_len $name
	writepad $name_pad
	} >&${_x_fd}
}

x_send_get_atom_name() {
	local atom=$1
	local handler=$2

	{
	_x_beginrequest $X_GetAtomName _x_read_get_atom_name $atom "$handler"
	write8 0
	write16 2
	write32 $atom
	} >&${_x_fd}
}

# Cannot pass a string to set WM_CLASS as there has to be a Null byte between
# 'instance' and 'class' and Bash does not allow Null bytes in strings
# Pass an array of bytes instead
x_send_change_property() {
	local windowid=$1
	local mode=$2
	local prop_atom=$3
	local prop_type=$4
	local prop_bits=$5
	local prop_count=$6

	shift 6
	local prop_value=( "$@" )

	local bytes=$(( prop_count * prop_bits / 8 ))
	local pad=${ pad4 $bytes; }
	local req_len=$(( 6 + (bytes + pad) / 4 ))
	local i

	(( prop_bits==8 || prop_bits==16 || prop_bits==32 )) ||
		die 'Change Property: invalid format %s' $prop_bits

	{
	_x_beginrequest $X_ChangeProperty
	write8 $mode
	write16 $req_len
	write32 $windowid
	write32 $prop_atom
	write32 $prop_type
	write8 $prop_bits
	writepad 3
	write32 $prop_count

	local write_type=$prop_type
	# Ensure write type for CLASS writes byte array
	(( prop_atom == XA_WM_CLASS )) && write_type='' 

	case $write_type in
		$XA_STRING) writechars $prop_count $prop_value
			;;
		$XA_UTF8_STRING) writeutf8 $prop_count $prop_value
			;;
		*)	for (( i=0 ; i<$prop_count ; i++ )); do
				writei$prop_bits ${prop_value[i]}
			done
			;;
	esac
	writepad $pad
	} >&${_x_fd}
}

x_send_delete_property() {
	local windowid=$1
	local atom=$2

	{
	_x_beginrequest $X_DeleteProperty
	write8 0
	write16 3
	write32 $windowid
	write32 $atom
	} >&${_x_fd}
}

x_send_get_property() {
	local windowid=$1
	local atom=$2
	local atom_type=$3
	local length=$4
	local handler=$5
	# Set when value is returned over multiple calls
	local start=${6:-0}
	local val=$7

	{
	_x_beginrequest $X_GetProperty _x_read_get_property $windowid $atom "$handler" $start "$val"
	write8 0
	write16 6
	write32 $windowid
	write32 $atom
	write32 $atom_type
	write32 $start
	write32 $length
	} >&${_x_fd}	
}

x_send_protocol_message() {
	local windowid=$1
	local protocol=$2

	{
	_x_beginrequest $X_SendEvent
	write8 0
	write16 11
	write32 $windowid
	write32 $X_NoEventMask

	write8 $X_ClientMessage
	write8 32
	write16 0
	write32 $windowid
	write32 $XA_WM_PROTOCOLS
	write32 $protocol
	writepad 16
	} >&${_x_fd}
}

x_send_grab_key() {
	local keycode=$1
	local mask=$2

	{
	_x_beginrequest $X_GrabKey
	write8 0
	write16 4
	write32 ${x_screen_0['root']}
	write16 $mask
	write8 $keycode
	write8 1
	write8 1
	writepad 3
	} >&${_x_fd}
}

x_send_query_pointer() {
	local windowid=$1
	local handler=$2

	{
	_x_beginrequest $X_QueryPointer _x_read_query_pointer $windowid "$handler"
	writepad 1
	write16 2
	write32 $windowid
	}>&${_x_fd}
}

x_send_set_input_focus() {
	local windowid=$1
	local timestamp=$2

	{
	_x_beginrequest $X_SetInputFocus
	write8 $X_PointerRoot
	write16 3
	write32 $windowid
	write32 $timestamp
	} >&${_x_fd}
}

x_send_query_extension() {
	local name=$1
	local handler=$2

	local name_len=${#name}
	local pad=$(pad4 $name_len)
	
	{
	_x_beginrequest $X_QueryExtension _x_read_query_extension $name "$handler"
	write8 0
	write16 $(( 2 + (name_len + pad) / 4 ))
	write16 $name_len
	writepad 2
	writechars $name_len $name
	writepad $pad
	} >&${_x_fd}
}

x_send_get_keyboard_mapping() {
	local handler=$1

	local min_keycode=${x_server['min_keycode']}
	local max_keycode=${x_server['max_keycode']}

	{
	_x_beginrequest $X_GetKeyboardMapping \
			_x_read_get_keyboard_mapping "$handler"
	write8 0
	write16 2
	write8 $min_keycode
	write8 $(( 1 + max_keycode - min_keycode ))
	writepad 2
	} >&${_x_fd}
}

# Loop round processing X Server events and replies
# and executing any commands queued via x_when_... functions
# Client can force exit from loop by calling x_exit <return code> 
x_event_loop() {
	log 'in event loop\n'
	while [[ -z $_x_exit_code ]]; do
		# While no input to read 
		# Process any commands to run when server has caught up
		while ! _x_pending_input; do
			_x_process_queue 'server_sync' || break
		done

		# While no input to read or replies expected
		# Process client sync queue or, if nothing queued
		# Process idle queue
		while ! (_x_pending_input || _x_pending_replies); do
			_x_process_queue 'sync' || 
			_x_process_queue 'idle' || 
			break
		done

		# Read next reply/event and dispatch
		_x_process_input
	done

	return $_x_exit_code
}

x_exit() {
	_x_exit_code=${1:-0}
}

# Execute command when server has processed all requests currenly pending
x_when_server_sync() {
	_x_server_sync_queue+=( "$_x_server_seqno $_x_client_seqno ${@@Q}" )
}

# Execute command when client has processed all server events/replies
x_when_sync() {
	_x_sync_queue+=( ${@@Q} )
}

# Execute command when client has nothing else left to do
x_when_idle() {
	_x_idle_queue+=( ${@@Q} )
}

########################
# Utilities used here and/or in extensions
########################

# Always called when output is redirected to _x_fd
# Increment seqno, register reply handler (if required) and write opcode
_x_beginrequest() {
	local opcode=$1
	shift

	(( _x_client_seqno >= 16#ffff )) && _x_client_seqno=0
	(( _x_client_seqno++ ))

	log 'Request %s, opcode %s, reply_handler %s\n' \
		$_x_client_seqno $opcode "$*"

	(( $# )) && _x_pending_replies[_x_client_seqno]=$*

	write8 $opcode
}

# Echo major opcode for named extension
_x_extension_opcode() {
	local name=$1

	local -n extension=_x_extension_$name
	echo ${extension['opcode']}
}

# Echo count of bits in given mask
_x_count_bits() {
	local mask=$1
	local count=0
	while (( mask )); do
		(( count+=mask&1, mask>>=1 ))
	done
	echo $count
}

########################
# Private functions and variables
########################

_x_readxauth() {
	local addr=${1:-$HOSTNAME}
	local display=$2
	local proto=256
	local length=1
	local xauth_proto xauth_addr xauth_display xauth_name xauth_data

	{
	while read -t 0 &&
			[[ $length != 0 && ($xauth_proto != $proto ||
				$xauth_addr != $addr ||
				$xauth_display != $display) ]]; do
		read16 xauth_proto
		read16 length
		readchars $length xauth_addr
		read16 length
		readchars $length xauth_display
		read16 xauth_name_length 
		readchars $xauth_name_length xauth_name
		read16 xauth_data_length
		readbytes $xauth_data_length xauth_data
	done
	} < "${XAUTHORITY:-~/.Xauthority}"

	x_server['xauth_name']="$xauth_name"
	x_server['xauth_data']="$xauth_data"
}

_x_connect() {
	local addr=$1
	local display=$2

	local use_addr=${addr:-'127.0.0.1'}

	if [[ $use_addr == '127.0.0.1' || $use_addr == 'localhost' ]]; then
		connect_unixsocket _x_fd /tmp/.X11-unix/X$display && return
	fi

	exec {_x_fd}<>/dev/tcp/$use_addr/$(( 6000+$display )) ||
		die 'Failed to connect to X DISPLAY %s:%d\n' \
			"$addr" $display
}

_x_setup() {
	
	_x_send_setup
	_x_read_setup_leader

	if (( ${x_server['setup_success']} != 1 )); then
		_x_read_setup_failure
		die 'Setup Failed: %s\n' \
			"${x_server['setup_failure_reason']}" 
			${x_server['setup_success']}
	fi

	_x_read_setup_ok
}

_x_send_setup() {
	local name_len=${#x_server['xauth_name']}
	# data is 02x formatted bytes
	local data_len=$(( ${#x_server['xauth_data']} / 2 ))

	{
	write8 ${x_server['byte_order']}
	writepad 1
	write16 ${x_server['wm_proto_major']}
	write16 ${x_server['wm_proto_minor']}
	write16 $name_len
	write16 $data_len
	writepad 2
	writechars $name_len "${x_server['xauth_name']}"
	writepad4 $name_len
	writebytes $data_len "${x_server['xauth_data']}"
	writepad4 $data_len
	} >&${_x_fd}
}

_x_read_setup_leader() {
	{
	read8 x_server['setup_success']
	read8 x_server['setup_length']
	read16 x_server['proto_major']
	read16 x_server['proto_minor']
	read16 x_server['extra_length']
	} <&${_x_fd}
}

_x_read_setup_failure() {
	{
	readchars ${x_server['setup_length']} x_server['setup_failure_reason']
	readpad "$(( x_server['extra_length'] * 4 - x_server['setup_length'] ))"
	} <&${_x_fd}
}

_x_read_setup_ok() {
	local s d depth no_of_visuals v class bits_per_rgb colormaps
	local red_mask green_mask blue_mask

	{
	read32 x_server['release_number']
	read32 x_server['resource_id_base']
	read32 x_server['resource_id_mask']
	read32 x_server['motion_buffer_size']
	read16 x_server['vendor_length']
	read16 x_server['max_request_length']
	read8 x_server['no_of_screens']
	read8 x_server['no_of_formats']
	read8 x_server['image_byte_order']
	read8 x_server['bitmap_byte_order']
	read8 x_server['bitmap_scanline_unit']
	read8 x_server['bitmap_scanline_pad']
	read8 x_server['min_keycode']
	read8 x_server['max_keycode']
	readpad 4
	readchars ${x_server['vendor_length']} x_server['vendor'] 
	readpad4 ${x_server['vendor_length']}
	readpad $(( 8 * x_server['no_of_formats'] ))

	for (( s=0 ; s<x_server['no_of_screens'] ; s++ )); do
		declare -Ag x_screen_$s
		local -n screen=x_screen_$s
		read32 screen['root']
		read32 screen['colormap']
		read32 screen['white_pixel']
		read32 screen['black_pixel']
		read32 screen['input_masks']
		read16 screen['width_pixels']
		read16 screen['height_pixels']
		read16 screen['width_mm']
		read16 screen['height_mm']
		read16 screen['min_maps']
		read16 screen['max_maps']
		read32 screen['visual_id']
		read8 screen['backing_stores']
		read8 screen['save_unders']
		read8 screen['root_depth']
		read8 screen['no_of_depths']

		# Not sure that this detail will ever be needed
		for (( d=0 ; d<screen['no_of_depths'] ; d++ )); do
			readpad 2
			read16 no_of_visuals
			readpad $(( 4 + no_of_visuals * 24 ))
		done
	done
	} <&${_x_fd}
}

_x_read_get_window_attributes() {
	#local unused=$1
	shift
	local windowid=$1
	local handler=$2
	local class map_stat override_redirect

	{
	readpad 8
	read16 class
	readpad 12
	read8 map_state
	read8 override_redirect
	readpad 16
	} <&${_x_fd}

	"$handler" $windowid $class $map_state $override_redirect
}

_x_read_get_geometry() {
	#local unused=$1
	local windowid=$2
	local handler=$3
	local x y width height border_width

	{
	readpad 8
	readi16 x
	readi16 y
	read16 width
	read16 height
	read16 border_width
	readpad 10
	} <&${_x_fd}

	"$handler" $windowid $x $y $width $height $border_width
}

_x_read_query_tree() {
	#local unused=$1
	local handler=$2
	local num_windows windowid

	{
	readpad 12
	read16 num_windows
	readpad 14

	local windows=()
	local i
	for (( i=0 ; i<num_windows ; i++ )); do
		read32 windowid
		windows+=( $windowid )
	done
	} <&${_x_fd}

	"$handler" "${windows[@]}"
}

_x_read_intern_atom() {
	#local unused=$1
	local name=$2
	local handler=$3

	{
	readpad 4
	read32 atom
	readpad 20
	} <&${_x_fd}

	"$handler" $name $atom
}

_x_read_get_atom_name() {
	#local unused=$1 
	local atom=$2
	local handler=$3
	local reply_length name_length name

	{
	read32 reply_length
	read16 name_length
	readpad 22
	readchars $name_length name
	readpad4 $name_length
	} <&${_x_fd}

	"$handler" $atom $name
}

_x_read_get_property() {
	local format=$1
	local windowid=$2
	local atom=$3
	local handler=$4
	local start=$5
	local val=$6
	local reply_len atom_type length bytes_after
	local item byte_count i

	{
	read32 reply_len
	read32 atom_type
	read32 bytes_after
	read32 length
	readpad 12

	(( format==8 || format==16 || format==32 )) || 
		die 'Get Property: invalid format %s' $format

	if (( $length )); then
		case $atom_type in
			$XA_STRING)
				if (( atom == XA_WM_CLASS )); then
					# Special handling for WM_CLASS 
					# 2 Null terminated strings
					readstring item
					val+="${item@Q}"
					readchars $((length - ${#item} - 1)) item
					val+=" ${item@Q}"
				else
					readchars $length item
					val+="$item"
				fi
				;;
			$XA_UTF8_STRING)
				readutf8 $length item
				val+="$item"
				;;
			*)
				for (( i=0 ; i < length ; i++ )); do
					readi${format} item
					val+=" $item"
				done
				val=${val:1}
				;;
		esac

		byte_count=$(( length * format / 8 ))
		readpad4 $byte_count
	fi
	} <&${_x_fd}

	if (( bytes_after )); then
		(( start += byte_count ))
		(( bytes_after -= byte_count ))
		x_send_get_property $windowid $atom $atom_type $bytes_after \
			"$handler" $start "$val"
	else
		"$handler" $windowid $atom "$val"
	fi
}

_x_read_query_pointer() {
	local same_screen=$1
	local windowid=$2
	local handler=$3
	local reply_length root child
	local root_x root_y win_x win_y mask

	{
	read32 reply_length
	read32 root
	read32 child
	readi16 root_x
	readi16 root_y
	readi16 win_x
	readi16 win_y
	read16 mask
	readpad 6
	}<&${_x_fd}
	
	# We don't support multiple X screens
	(( same_screen )) || 
		die 'QueryPointer returned position on another X screen\n'
	
	"$handler" $windowid $root $child $root_x $root_y $win_x $win_y $mask
}

_x_read_query_extension() {
	#local unused=$1
	local name=$2
	local handler="$3"
	local present opcode event error

	{
	readpad 4
	read8 present
	read8 opcode
	read8 event
	read8 error
	readpad 20
	} <&${_x_fd}

	if (( present )); then
		declare -Ag "_x_extension_$name=( \
			opcode $opcode \
			event $event \
			error $error)"
	fi

	"$handler" $name $present
}

_x_read_get_keyboard_mapping() {
	local keysyms_per=$1
	local handler=$2

	local min_keycode=${x_server['min_keycode']}
	local max_keycode=${x_server['max_keycode']}
	local keycodes=$(( 1 + max_keycode - min_keycode ))
	local key_mappings=$(( keysyms_per * keycodes ))
	local reply_length keycode keycodesym
	local _key_map=()

	{
	read32 reply_length
	(( reply_length == key_mappings )) ||
		die 'Got %s keboard mappings, expected %s\n' \
			$reply_length $key_mappings
	readpad 24

	for (( keycode=min_keycode ; keycode<=max_keycode ; keycode++ )); do
		# only interested in the first keysym
		read32 keycodesym
		readpad $(( 4 * (keysyms_per - 1) ))
		(( keycodesym != X_NoSymbol )) && 
				_key_map[$keycode]=$keycodesym
	done
	} <&${_x_fd}

	# Pass key map by name
	"$handler" _key_map
}

_x_process_input() {
	local input_type input_code handler

	<&${_x_fd} read8 input_type
	input_code=$(( input_type & 16#7F ))

	local handler=${_x_event_readers[$input_code]:-_x_discard_event}

	log 'process input: %s %s\n' $input_code $handler
	
	$handler $input_code
}

_x_pending_input() {
	<&${_x_fd} read -t 0
}

_x_pending_replies() {
	(( ${#_x_pending_replies[@]} ))
}

_x_process_queue() {
	local queue_name=$1
	local -n queue=_x_${queue_name}_queue

	local keys=${!queue[@]}

	(( ${#keys[@]} )) || return 1

	local key=${keys[0]}
	local -a cmd="( ${queue[key]} )"

	if [[ $queue_name == 'server_sync' ]]; then
		(( cmd[0] > $_x_server_seqno || 
				cmd[1] <= $_x_server_seqno )) || 
				return 1
		"${cmd[@]:2}"
	else
		"${cmd[@]}"
	fi

	unset 'queue[$key]'
	return 0
}

_x_discard_event() {
	# discard unwanted event data
	{
	readpad 1
	read16 _x_server_seqno
	readpad 28
	} <&${_x_fd}
}

_x_read_error() {
	local code data major_op_code minor_op_code

	{
	read8 code
	read16 _x_server_seqno
	read32 data
	read16 major_op_code
	read8 minor_op_code
	readpad 21
	} <&${_x_fd}

	unset '_x_pending_replies[$_x_server_seqno]'

	"${x_event_handlers[X_Error]}" $code $data $major_op_code $minor_op_code
}

_x_read_reply() {
	local reply_byte 

	{
	read8 reply_byte
	read16 _x_server_seqno
	} <&${_x_fd}

	local reply_info=${_x_pending_replies[_x_server_seqno]}
	unset '_x_pending_replies[$_x_server_seqno]'

	if [[ $reply_info ]]; then
		local handler=${reply_info%% *}
		local args="${reply_info#* }"
		
		log 'Reply handler %s, args %s\n' "$handler" "$args"

		$handler $reply_byte $args
	else
		log 'Unexpected reply for request %s\n' $_x_server_seqno
	fi
}

_x_read_key_press() {
	local keycode keymask keycode_cmd keycmd mask cmd

	{
	read8 keycode
	read16 _x_server_seqno
	readpad 24
	read16 keymask
	readpad 2
	} <&${_x_fd}

	"${x_event_handlers[X_KeyPress]}" $keycode $keymask
}

_x_read_enter_notify() {
	local detail timestamp windowid mode flags window

	{
	read8 detail
	read16 _x_server_seqno
	read32 timestamp
	readpad 4
	read32 windowid
	readpad 14
	read8 mode
	read8 flags
	} <&${_x_fd}

	"${x_event_handlers[X_EnterNotify]}" $windowid $timestamp $detail $mode $flags
}

_x_read_focus_in() {
	local detail windowid mode 

	{
	read8 detail
	read16 _x_server_seqno
	read32 windowid
	read8 mode
	readpad 23
        } <&${_x_fd}

	"${x_event_handlers[X_FocusIn]}" $windowid $detail $mode
}

_x_read_create_notify() {
	local windowid x y width height border_width override_redirect

	{
	readpad 1
	read16 _x_server_seqno
	readpad 4
	read32 windowid
	readi16 x
	readi16 y
	read16 width
	read16 height
	read16 border_width
	read8 override_redirect
	readpad 9
	} <&${_x_fd}

	"${x_event_handlers[X_CreateNotify]}" \
		$windowid $x $y $width $height $border_width $override_redirect
}

_x_read_destroy_notify() {
	local event windowid window

	{
	readpad 1
	read16 _x_server_seqno
	read32 event
	read32 windowid
	readpad 20
	} <&${_x_fd}

	"${x_event_handlers[X_DestroyNotify]}" $windowid $event
}

_x_read_unmap_notify() {
	local windowid event

	{
	readpad 1
	read16 _x_server_seqno
	read32 event
	read32 windowid
	readpad 20
	} <&${_x_fd}

	"${x_event_handlers[X_UmnapNotify]}" $windowid $event
}

_x_read_map_request() {
	local windowid

	{
	readpad 1
	read16 _x_server_seqno
	readpad 4
	read32 windowid
	readpad 20
	} <&${_x_fd}

	"${x_event_handlers[X_MapRequest]}" $windowid
}

_x_read_configure_notify() {
	local event window above x y width height border_width 
	local override_redirect

	{
	readpad 1
	read16 _x_server_seqno
	read32 event
	read32 windowid
	read32 above
	readi16 x
	readi16 y
	read16 width
	read16 height
	read16 border_width
	read8 override_redirect
	readpad 5
	} <&${_x_fd}

	"${x_event_handlers[X_ConfigureNotify]}" $windowid $event \
		$x $y $width $height $border_width $override_redirect
}

_x_read_configure_request() {
	local stack_mode parent window windowid sibling
	local x y width height border_width value_mask n

	{
	read8 stack_mode
	read16 _x_server_seqno
	read32 parent
	read32 windowid
	read32 sibling
	readi16 x
	readi16 y
	read16 width
	read16 height
	read16 border_width
	read16 value_mask
	readpad 4
	} <&${_x_fd}

	"${x_event_handlers[X_ConfigureRequest]}" $windowid $stack_mode \
		$value_mask $x $y $width $height $border_width $sibling 
}

_x_read_property_notify() {
	local windowid atom state

	{
	readpad 1
	read16 _x_server_seqno
	read32 windowid
	read32 atom
	readpad 4
	read8 state
	readpad 15
	} <&${_x_fd}

	"${x_event_handlers[X_PropertyNotify]}" $windowid $atom $state
}

_x_read_client_message() {
	local format windowid atom i num_values 
	local values=()

	{
	read8 format
	read16 _x_server_seqno
	read32 windowid
	read32 atom

	(( format==8 || format==16 || format==32 )) ||
		die 'Client Message: invalid format %s\n' $format

	num_values=$(( 160 / format ))
	for (( i=0 ; i<num_values ; i++ )); do
		readi$format value
		values[i]=$value
	done
	} <&${_x_fd}

	"${x_event_handlers[X_ClientMessage]}" $windowid $atom "${values[@]}"
}

_x_event_readers[X_Error]=_x_read_error
_x_event_readers[X_Reply]=_x_read_reply
_x_event_readers[X_KeyPress]=_x_read_key_press
_x_event_readers[X_EnterNotify]=_x_read_enter_notify
_x_event_readers[X_FocusIn]=_x_read_focus_in
_x_event_readers[X_CreateNotify]=_x_read_create_notify
_x_event_readers[X_DestroyNotify]=_x_read_destroy_notify
_x_event_readers[X_UnmapNotify]=_x_read_unmap_notify
_x_event_readers[X_MapRequest]=_x_read_map_request
_x_event_readers[X_ConfigureNotify]=_x_read_configure_notify
_x_event_readers[X_ConfigureRequest]=_x_read_configure_request
_x_event_readers[X_PropertyNotify]=_x_read_property_notify
_x_event_readers[X_ClientMessage]=_x_read_client_message

x_event_handlers=()

# 0x42=msb first
declare -Ag x_server=( \
	byte_order $(( 16#42 )) \
	wm_proto_major 11 \
	wm_proto_minor 0 )

X_ReturnZero=$(( 16#100 ))

X_WM_NormalState=0
X_WM_WithdrawnState=1
X_WM_IconicState=3

X_WM_PMinSize=16
X_WM_PMaxSize=32

X_NET_WM_StateRemove=0
X_NET_WM_StateAdd=1
X_NET_WM_StateToggle=2
