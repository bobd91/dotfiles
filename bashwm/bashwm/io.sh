#!/usr.bin.env bash

write_b() {
	printf '%b' "\x$1" || die 'Write failure: %d\n' $?
}

write_s() {
	printf '%s' "$1" || die 'Write failure: %d\n' $?
}

write8() {
	local t=00
	(( $1 )) && printf -v t '%02x' "$(( $1 & 16#ff ))"
	write_b $t
}

writei8() {
	local i=$1
	local b=${2:-8}

	(( b == 16 || b == 32 )) && writepad $(( b / 8 - 1 ))

	(( i > 16#7f )) && (( i &= 16#7f ))
	# write8 will handle negative numbers correctly
	write8 $i
}

write16() {
	local val=$1

	write8 $(( val >> 8 ))
	write8 $val
}

writei16() {
	local i=$1
	local b=${2:-16}

	(( b == 32 )) && writepad 2

	if (( i < 0 )); then
		(( i &= 16#ffff ))
	else
		(( i &= 16#7fff ))
	fi
	write16 $i
}

write32() {
	local val=$1

	write8 $(( val >> 24 ))
	write8 $(( val >> 16 ))
	write8 $(( val >> 8 ))
	write8 $val
}

writei32() {
	local i=$1

	if (( i < 0 )); then
		(( i &= 16#ffffffff ))
	else
		(( i &= 16#7fffffff ))
	fi
	write32 $i
}

writepad() {
	local i
	for (( i=0 ; i<$1 ; i++ )); do
		write8 0
	done
}

pad4() {
	local l=$1
	echo $(( (4 - (l % 4)) % 4 ))
}

writepad4() {
	writepad ${ pad4 $1; }
}


writechars() {
	#local len=$1
	write_s "$2"
}

writeutf8() {
	#local len=$1
	local LC_TYPE=C.UTF8
	write_s "$2"
}

writebytes() {
	local len=$1
	local bytes=$2
	local byte_count=$(( ${#bytes}/2 ))
	local i b

	for (( i=0 ; i<byte_count ; i++ )); do
		b=$(( i*2 ))
		write_b "${bytes:b:2}"
	done
	# If len > byte_count pad with nulls
	for (( i=byte_count ; i<len ; i++ )); do
		write_b 00
	done
}

read8() {
	local _t

	IFS= read -r -d '' -n 1 _t
	if [[ -n $_t ]]; then
		printf -v "$1" '%d' "'$_t"
	else
		printf -v "$1" "0"
	fi
}

readi8() {
	local _i8

	read8 _i8
	(( _i8 > 16#7f )) && (( _i8 -= 16#100 ))
	printf -v "$1" '%d' $_i8
}

read16() {
	local _b1 _b2

	read8 _b1
	read8 _b2
	printf -v "$1" '%d' "$(( _b2 + (_b1 << 8) ))"
}

readi16() {
	local _i16

	read16 _i16

	(( _i16 > 16#7fff )) && (( _i16 -= 16#10000 ))

	printf -v "$1" '%d' $_i16
}

read32() {
	local _b1 _b2 _b3 _b4

	read8 _b1
	read8 _b2
	read8 _b3
	read8 _b4
	printf -v "$1" '%d' $(( _b4 + (_b3 << 8) + (_b2 << 16) + (_b1 << 24) ))
}

readi32() {
	local _i32

	read32 _i32
	(( _i32 > 16#7fffffff )) && (( _i32 -= 16#100000000 ))
	printf -v "$1" '%d' $_i32
}

readstr() {
	local _s1
	read8 _s1
	readchars $_s1 $1
}

readstring() {
	local _s

	IFS= read -r -d '' _s
	printf -v "$1" "$_s"
}

readchars() {
	local _n=$1
	local _s

	(( $_n )) || return

	IFS= read -r -d '' -n $_n _s
	(( _n == ${#_s} )) || readpad $(( $_n - ${#_s} - 1))
	printf -v "$2" "$_s"
}

readbytes() {
	local _i _c _b _s

	(( $1 )) || return

	for (( _i=0 ; _i<$1 ; _i++ )); do
		read8 _c
		printf -v _b '%02x' $_c
		_s+=$_b
	done

	printf -v "$2" $_s
}

readutf8() {
	local LC_CTYPE=C.UTF8
	local _utf8

	readchars $1 _utf8
	printf -v "$2" '%s' $_utf8
}

readpad() {
	local _pad i

	for (( i=0 ; i<$1 ; i++ )); do
		read8 _pad
	done
}

readpad4() {
	readpad ${ pad4 $1; }
}
