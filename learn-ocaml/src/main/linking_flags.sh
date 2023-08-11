#!/bin/sh
set -ue

# This script is called by dune to generate the linking flags for static builds
# (on the limited set of supported platforms). It only returns an empty set of
# flags for the default dynamic linking mode.

LC_ALL=C

help_exit() {
    echo "Usage: $0 descriptiveID dynamic|static linux|macosx [extra-libs]" >&2
    exit 2
}

echo2() {
    echo "$*" >&2
    echo "$*"
}

[ $# -lt 3 ] && help_exit

descID="$1"
shift

echo2 ";; $descID"
echo2 ";; generated by $0"

case "$1" in
    dynamic) echo2 "()"; exit 0;;
    static) ;;
    *) echo "Invalid linking mode '$1'." >&2; help_exit
esac

shift
case "$1" in
    macosx) shift; EXTRA_LIBS="curses $*";;
    linux) shift; EXTRA_LIBS="$*";;
    --) shift; EXTRA_LIBS="$*";;
    *) echo "Not supported %{ocamlc-config:system} '$1'." >&2; help_exit
esac

## Static linking configuration ##

# The linked C libraries list may need updating on changes to the dependencies.
#
# To get the correct list for manual linking, the simplest way is to set the
# flags to `-verbose`, while on the normal `autolink` mode, then extract them
# from the gcc command-line.
# The Makefile contains a target to automate this: `make detect-libs`.

case $(uname -s) in
    Linux)
        case $(. /etc/os-release && echo $ID) in
            alpine)
                COMMON_LIBS="camlstr ssl_stubs ssl crypto cstruct_stubs bigstringaf_stubs lwt_unix_stubs unix c"
                # `m` and `pthread` are built-in musl
                echo2 '(-noautolink'
                echo2 ' -cclib -Wl,-Bstatic'
                echo2 ' -cclib -static-libgcc'
                for l in $EXTRA_LIBS $COMMON_LIBS; do
                    echo2 " -cclib -l$l"
                done
                echo2 ' -cclib -static)'
                ;;
            *)
                echo2 "Error: static linking is only supported in Alpine, to avoids glibc constraints (use scripts/static-build.sh to build through an Alpine Docker container)" >&2
                exit 3
        esac
        ;;
    Darwin)
        COMMON_LIBS="camlstr ssl_stubs /usr/local/opt/openssl/lib/libssl.a /usr/local/opt/openssl/lib/libcrypto.a cstruct_stubs bigstringaf_stubs lwt_unix_stubs unix"
        # `m` and `pthread` are built-in in libSystem
        echo2 '(-noautolink'
        for l in $EXTRA_LIBS $COMMON_LIBS; do
            if [ "${l%.a}" != "${l}" ]; then echo2 " -cclib $l"
            else echo2 " -cclib -l$l"
            fi
        done
        echo2 ')'
        ;;
    *)
        echo "Static linking is not supported for your platform. See $0 to contribute." >&2
        exit 3
esac
