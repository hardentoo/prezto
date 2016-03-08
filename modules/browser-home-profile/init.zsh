#
# Browser-Home-Profile (bhp) maintains profile & associated
# cache directory in a tmpfs (or zram backed) filesystem
#
# $Header: browser-home-profile/init.zsh                 Exp $
# $Aythor: (c) 2012-6 -tclover <tokiclover@gmail.com>    Exp $
# $License: MIT (or 2-clause/new/simplified BSD)         Exp $
# $Version: 1.1 2016/03/06 21:09:26                      Exp $
#

functions -u bhp pr-{begin,end,error,warn,info} yesno
#
# Setup a few environment variables for pr-*() helper family
#
PR_COL="$(tput cols)"
# the following should be set before calling pr-end()
#PR_LEN=${PR_LEN}

#
# Set up (terminal) colors
#
if [ -t 1 ] && yesno ${COLOR:-Yes}; then
	autoload colors zsh/terminfo
	if (( ${terminfo[colors]} >= 8 )) { colors }
fi

#
# Initialize the temporary directory with an anonymous function
#
function {
	local PROFILE browser name=bhp compressor profile tmpdir zsh_hook

	zstyle -s ':prezto:module:BHP' browser 'browser'
	zstyle -s ':prezto:module:BHP' profile 'profile'
	zstyle -s ':prezto:module:BHP' compressor 'compressor'
	zstyle -b ':prezto:module:BHP' zsh-hook 'zsh_hook'
	zstyle -s ':prezto:module:BHP' tmpdir 'tmpdir'

	setopt LOCAL_OPTIONS EXTENDED_GLOB

	#
	# Set up web-browser if any
	#
	function {
		local BROWSERS MOZ_BROWSERS set brs dir
		MOZ_BROWSERS='aurora firefox icecat seamonkey'
		BROWSERS='conkeror chrom epiphany midory opera otter qupzilla vivaldi'

		case ${1} {
			(*aurora|firefox*|icecat|seamonkey)
				BROWSER=${1} PROFILE=mozilla/${1}; return;;
			(conkeror*|*chrom*|epiphany|midory|opera*|otter*|qupzilla|vivaldi*)
				BROWSER=${1} PROFILE=config/${1} ; return;;
		}

		for set ("mozilla:${MOZ_BROWSERS}" "config:${BROWSERS}")
			for brs (${=set#*:}) {
				set=${set%:*}
				for dir (${HOME}/.${set}/*${brs}*(N/))
					if [[ -d ${dir} ]] {
						BROWSER=${brs} PROFILE=${set}/${brs}
						return
					}
			}
		return 111
	} "${browser:-$BROWSER}"

	if (( ${?} != 0 )) {
		pr-error "No web-browser found."
		return 112
	}

	#
	# Handle (Mozilla) specific profiles
	#
	case ${PROFILE} {
		(mozilla*)
		function {
			if [[ -n ${1} ]] && [[ -d ${HOME}/.${PROFILE}/${1} ]] {
				PROFILE=${PROFILE}/${1}
				return
			}
			PROFILE="${PROFILE}/$(sed -nre "s|^[Pp]ath=(.*$)|\1|p" \
				${HOME}/.${PROFILE}/profiles.ini)"
			[[ -n ${PROFILE} ]] && [[ -d ${HOME}/.${PROFILE} ]]
		} "${profile}"

		if (( ${?} != 0 )) {
			pr-error "No firefox profile directory found"
			return 113
		}
		;;
	}

:	${compressor:=lz4 -1 -}
:	${profile:=${PROFILE:t}}
:	${tmpdir:=${TMPDIR:-/tmp/$USER}}
	local ext=.tar.${compressor[(w)1]}
	zstyle ':prezto:module:BHP' compressor ${compressor}
	zstyle ':prezto:module:BHP' browser ${browser}
	zstyle ':prezto:module:BHP' PROFILE ${PROFILE}

	if (( ${zsh_hook} )) {
		autoload -Uz add-zsh-hook
		add-zsh-hook zshexit fhp
	}

	[[ -d ${tmpdir} ]] || mkdir -p -m 1700 ${tmpdir} ||
		{ pr-error "No suitable directory found"; return 114; }

	local char dir DIR
	for dir (${HOME}/.${PROFILE} ${HOME}/.cache/${PROFILE#config/}) {
		[[ -d ${dir} ]] || continue
		grep -q ${dir} /proc/mounts && continue
		pr-begin "Setting up directory..."

		pushd -q ${dir:h} || continue
		if [[ ! -f ${profile}${ext} ]] || [[ ! -f ${profile}.old${ext} ]] {
			tar -Ocp ${profile} | ${=compressor} ${profile}${ext} ||
				{ pr-error "Failed to pack a tarball"; continue; }
		}
		popd -q

		case ${dir} {
			(*.cache/*) char=c;;
			(*) char=p;;
		}
		DIR=$(mktmp -p ${tmpdir}  -d bh${char}-XXXXXX)
		sudo mount --bind ${DIR} ${dir} ||
			pr-error "Failed to mount ${DIR}"
		pr-end ${?}
	}

	#
	# Finaly, decompress the browser-home-profile
	#
	if zstyle -t ':prezto:module:BHP' decompress; then
		bhp
	fi
}

#
# vim:fenc=utf-8:ft=zsh:ci:pi:sts=2:sw=2:ts=2:
#
