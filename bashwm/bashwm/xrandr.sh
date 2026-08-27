#!/usr/bin/env bash

require io xcore xrrvars

x_send_rr_query_version() {
	local handler=$1

	_x_rr_major_opcode=${ _x_extension_opcode $X_RANDR_NAME; }

	{
	_x_rr_beginrequest $X_RRQueryVersion _x_read_rr_query_version "$handler"
	write16 3
	write32 $X_RANDR_MAJOR
	write32 $X_RANDR_MINOR
	} >&${_x_fd}
}

x_send_rr_get_monitors() {
	local handler=$1

	{
	_x_rr_beginrequest $X_RRGetMonitors _x_read_rr_get_monitors "$handler"
	write16 3
	write32 ${x_screen_0['root']}
	write8 1
	writepad 3
	} >&${_x_fd}
}


_x_rr_beginrequest() {
	local rr_opcode=$1

	_x_beginrequest $_x_rr_major_opcode "${@:2}"
	write8 $rr_opcode
}

_x_read_rr_query_version() {
	#local unused=$1
	local handler=$2

	local major minor
	local RR_MINOR_REQD=2

	{
	readpad 4
	read32 major
	read32 minor
	readpad 16
	} <&${_x_fd}

	log 'RRVersion: want %s.%s, got %s.%s\n' \
		$X_RANDR_MAJOR $RR_MINOR_REQD $major $minor

	if (( major < X_RANDR_MAJOR || 
			(major == X_RANDR_MAJOR && 
				minor < RR_MINOR_REQD) )); then
		"$handler" $X_RRUnsupported
	else
		"$handler" $X_RROk
	fi
}

_x_read_rr_get_monitors() {
	#local unused=$1
	local handler=$2
	local reply_length timestamp nmonitors tnoutputs

	{
	read32 reply_length
	read32 timestamp
	read32 nmonitors
	read32 tnoutputs
	readpad 12

	# Would be nice to use timestamp to skip get_monitors responses when
	# there is no change but the timestamp doesn't get updated on
	# randr set/del monitor

	local monitors=()
	local m name_atom primary auto noutputs x y 
	local width height width_mm height_mm outputs output
	for (( m=0 ; m<nmonitors ; m++ )); do
		read32 name_atom
		read8 primary
		read8 auto
		read16 noutputs
		read16 x
		read16 y
		read16 width
		read16 height
		read32 width_mm
		read32 height_mm

		outputs=" "
		for (( o=0 ; o<noutputs ; o++ )); do
			read32 output
			outputs+="$output "
		done
		monitors[m]="$name_atom $primary $auto $x $y \
			$width $height $width_mm $height_mm $outputs"
	done
	} <&${_x_fd}

	"$handler" "${monitors[@]}"
}

X_RROk=0
X_RRUnsupported=1
