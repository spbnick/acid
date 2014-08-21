#
# ACID - miscellaneous functions
#
# Copyright (c) 2014 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.

if [ -z "${_ACID_MISC_SH+set}" ]; then
declare -r _ACID_MISC_SH=

# Check if a directory is a git repository,
# i.e. can be used as a GIT_DIR value.
# Args: dir
function acid_is_git_dir()
{
    declare -r dir="$1"
    GIT_DIR="$dir" git rev-parse --resolve-git-dir="$dir" >&/dev/null
}

# Escape a string to use literally in a regular expression.
# Args: str
function acid_regexp_escape()
{
    declare -r str="$1";    shift
    declare esc=""
    declare i
    declare c
    for ((i=0; i < ${#str}; i++)); do
        c=${str:i:1}
        if [[ $c == [A-Za-z0-9_-] ]]; then
            esc+="$c"
        else
            esc+="\\$c"
        fi
    done
    printf "%s" "$esc"
}

fi # _ACID_MISC_SH
