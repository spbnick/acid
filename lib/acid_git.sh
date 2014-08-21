#
# ACID - a git-based object
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

if [ -z "${_ACID_GIT_SH+set}" ]; then
declare -r _ACID_GIT_SH=

. thud_arr.sh
. acid_misc.sh

declare -r ACID_GIT_SHIFT='
    declare -r git_str="$1";    shift
    declare -A git=()
    thud_arr_parse git <<<"$git_str"
'

# Load a git-based object.
# Args: dir conf_pfx
# Output: git string
function acid_git_load()
{
    declare -r dir="$1";        shift
    declare -r conf_pfx="$1";   shift
    thud_assert 'acid_is_git_dir "$dir"'
    declare -A git=(
        [git_dir]="`readlink -f \"\$dir\"`"
        [git_conf_pfx]="$conf_pfx"
        [git_conf_regexp_pfx]="`acid_regexp_escape \"\$conf_pfx\"`"
    )
    thud_arr_print git
}

# Output variable's (last) configuration value.
# Args: git_str name
function acid_git_conf_get()
{
    eval "$ACID_GIT_SHIFT"
    declare -r name="$1";  shift
    GIT_DIR="${git[git_dir]}" git config --get "${git[git_conf_pfx]}$name"
}

# Output variable's (last) boolean configuration value.
# Args: git_str name
function acid_git_conf_get_bool()
{
    eval "$ACID_GIT_SHIFT"
    declare -r name="$1";  shift
    GIT_DIR="${git[git_dir]}" git config --bool --get "${git[git_conf_pfx]}$name"
}

# Output all values of a configuration variable, zero-terminated.
# Args: git_str name
function acid_git_conf_get_all_zero()
{
    eval "$ACID_GIT_SHIFT"
    declare -r name="$1";  shift
    GIT_DIR="${git[git_dir]}" git config --null \
        --get-all "${git[git_conf_pfx]}$name"
}

# Output all values of a configuration variable, newline-terminated.
# Args: git_str name
function acid_git_conf_get_all()
{
    acid_git_conf_get_all_zero "$@" | tr \\0 \\n
}

# Output (stripped) name/value pairs of all configuration items
# matching a regexp with prefix added and optionally a value regexp,
# zero-terminated, values on new lines.
# Args: git_str regexp_sfx [value_regexp]
function acid_git_conf_get_regexp_zero()
{
    eval "$ACID_GIT_SHIFT"
    declare -r regexp_sfx="$1";  shift
    declare -r value_regexp="${1-}"
    GIT_DIR="${git[git_dir]}" git config --null \
        --get-regexp "^${git[git_conf_regexp_pfx]}$regexp_sfx" \
        "$value_regexp" |
            # Cut-off prefix length number of leading characters
            sed -ze "s/^.\\{${#git[git_conf_pfx]}\\}//"
}

# Output (stripped) name/value pairs of all configuration items matching a
# regexp with prefix added and optionally a value regexp, newline-terminated,
# values on the same lines.
# Args: git_str regexp_sfx [value_regexp]
function acid_git_conf_get_regexp()
{
    acid_git_conf_get_regexp_zero "$@" | sed -ze 's/\n/ /' | tr \\0 \\n
}

# List configuration variable names matching a regexp with prefix added and
# optionally a value regexp, newline-terminated.
# Args: git_str regexp_sfx [value_regexp]
function acid_git_conf_list_regexp()
{
    acid_git_conf_get_regexp_zero "$@" | sed -ze 's/\n.*//' | tr \\0 \\n
}

# Check if a configuration variable exists, which matches a regexp with prefix
# added and optionally a value regexp.
# Args: git_str regexp_sfx [value_regexp]
function acid_git_conf_exists_regexp()
{
    acid_git_conf_get_regexp "$@" | grep -q '.'
}

# Check if a configuration variable with exact (prefixed) name and optionally
# a value matching a regexp exists.
# Args: git_str name [value_regexp]
function acid_git_conf_exists()
{
    acid_git_conf_exists_regexp "$1" "`acid_regexp_escape \"\$2\"`\$" "${3-}"
}

# Check if a branch exists.
# Args: git_str branch_name
function acid_git_branch_exists()
{
    eval "$ACID_GIT_SHIFT"
    declare -r branch_name="$1"
    GIT_DIR="${git[git_dir]}" \
        git show-ref --quiet --verify "refs/heads/$branch_name"
}

# Output branch names, one per line.
# Args: git_str
function acid_git_branch_list()
{
    eval "$ACID_GIT_SHIFT"
    GIT_DIR="${git[git_dir]}" \
        git for-each-ref --format='%(refname)' refs/heads/ |
            # Cut off the initial "refs/heads/"
            cut -c 12-
}

fi # _ACID_GIT_SH
