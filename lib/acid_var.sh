#
# ACID - tag variable specification
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

if [ -z "${_ACID_VAR_SH+set}" ]; then
declare -r _ACID_VAR_SH=

. thud_arr.sh
. acid_tag.sh
. acid_set.sh
. acid_git.sh

declare -r ACID_VAR_SHIFT='
    declare -r var_str="$1";    shift
    declare -A var=()
    thud_arr_parse var <<<"$var_str"
'

# Load a var.
# Args: git_dir name
# Output: var string
function acid_var_load()
{
    declare -r git_dir="$1";    shift
    declare -r name="$1";       shift
    declare git_str
    git_str=`acid_git_load "$git_dir" "acid-var.${name}."`
    declare -A var=()
    thud_arr_parse var <<<"$git_str"
    declare -A map=()
    declare tag_var
    declare set
    declare tag
    declare desc

    var[name]="$name"
    var[desc]=`acid_git_conf_get "$git_str" desc || true`
    var[type]=`acid_git_conf_get "$git_str" type || true`

    if [[ ${var[type]} == @(inclusive|exclusive) ]]; then
        while read -r -d '' tag desc; do
            if ! acid_tag_is_exact "$tag"; then
                echo "Not an exact tag: $tag" >&2
                return 1
            fi
            if [[ -n ${map[$tag]+set} ]]; then
                echo "Duplicate tag: $tag" >&2
                return 1
            fi
            set+=" $tag"
            map[$tag]="${desc:-$tag}"
        done < <(acid_git_conf_get_all_zero "$git_str" tag)
    elif [[ ${var[type]} == scope ]]; then
        for tag_var in each last; do
            read -r -d '' tag desc \
                < <(acid_git_conf_get "$git_str" "$tag_var")
            if ! acid_tag_is_exact "$tag"; then
                echo "Not an exact tag: $tag" >&2
                return 1
            fi
            if [[ -n ${map[$tag]+set} ]]; then
                echo "Duplicate tag: $tag" >&2
                return 1
            fi
            var[$tag_var]="$tag"
            set+=" $tag"
            map[$tag]="${desc:-$tag}"
        done
    elif [[ -n "${var[type]}" ]]; then
        echo "Unknown variable type: ${var[type]}" >&2
        return 1
    else
        echo "Variable type not specified" >&2
        return 1
    fi
    var[map_str]=`thud_arr_print map`
    var[set]="$set"
    thud_assert 'acid_set_is_exact "${var[set]}"'

    thud_arr_print var
}

# Check if a variable is exclusive.
# Args: var_str
function acid_var_is_exclusive()
{
    eval "$ACID_VAR_SHIFT"
    [[ ${var[type]} == @(exclusive|scope) ]]
}

# Check if a variable is the scope type.
# Args: var_str
function acid_var_is_scope()
{
    eval "$ACID_VAR_SHIFT"
    [[ ${var[type]} == scope ]]
}

fi # _ACID_VAR_SH
