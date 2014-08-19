#
# ACID - set operations
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

#
# A set is a whitespace-separated list of elements (tags).
# There are two main kinds of sets: exact sets and glob sets. Exact sets can
# only contain exact tags. Glob sets can also contain glob tags. A prefix
# (pfx) set is a glob set, where each tag is an exact tag with '*' appended.
# See acid_tag.sh.
#

if [ -z "${_ACID_SET_SH+set}" ]; then
declare -r _ACID_SET_SH=

. acid_tag.sh

declare -r ACID_SET_IFS=$' \t\n'
declare -r ACID_SET_CS_EXACT="$ACID_SET_IFS$ACID_TAG_CS_EXACT"
declare -r ACID_SET_CS="$ACID_TAG_CS_GLOB$ACID_SET_IFS$ACID_TAG_CS_EXACT"

# Check if a string is a valid set.
# Args: str
function acid_set_is_valid()
{
    [[ $1 != *[^$ACID_SET_CS]* ]]
}

# Check if a string is an exact set.
# Args: str
function acid_set_is_exact()
{
    [[ $1 != *[^$ACID_SET_CS_EXACT]* ]]
}

# Check if a string is a glob set.
# Args: str
function acid_set_is_glob()
{
    [[ $1 != *[^$ACID_SET_CS]* && $1 == *[$ACID_TAG_CS_GLOB]* ]]
}

# Check if a string is a prefix glob set.
# Args: set
function acid_set_is_pfx()
{
    declare -r spc="[$ACID_SET_IFS]"
    declare -r tag="[$ACID_TAG_CS_EXACT]+\\*"
    [[ $1 =~ ^$spc*($tag($spc+$tag)*)?$spc*$ ]]
}

# Check if a set is empty.
# Args: set
function acid_set_is_empty()
{
    declare -r set="$1"
    thud_assert 'acid_set_is_valid "$set"'
    # Set is empty if there are no non-separator characters
    [[ $set != *[^$ACID_SET_IFS]* ]]
}

# Check if a set consits of one element.
# Args: set
function acid_set_is_singleton()
{
    declare -r set="$1"
    thud_assert 'acid_set_is_valid "$set"'
    [[ $set =~ ^[$ACID_SET_IFS]*[^$ACID_SET_IFS]+[$ACID_SET_IFS]*$ ]]
}

# Convert a set string to an indexed array.
# Args: _iarr_var _set
function acid_set_to_iarr()
{
    declare -r _iarr_var="$1";  shift
    declare -r _set="$1";       shift
    thud_assert 'thud_is_idx_arr "$_iarr_var"'
    thud_assert 'acid_set_is_valid "$_set"'
    IFS="$ACID_SET_IFS" read -r -d '' -a "$_iarr_var" <<<"$_set"
}

# Convert a set string to an associative array.
# Args: _aarr_var _set
function acid_set_to_aarr()
{
    declare -r _aarr_var="$1";  shift
    declare -r _set="$1";       shift
    declare -a _iarr=()
    declare _init_expr
    thud_assert 'thud_is_ass_arr "$_aarr_var"'
    thud_assert 'acid_set_is_valid "$_set"'
    IFS="$ACID_SET_IFS" read -r -d '' -a _iarr <<<"$_set"
    printf -v _init_expr '[%q]=true ' "${_iarr[@]}"
    eval "$_aarr_var+=($_init_expr)"
}

# Convert an indexed array to a set string.
# Args: _iarr_var
function acid_set_from_iarr()
{
    declare -r _iarr_var="$1";  shift
    thud_assert 'thud_is_idx_arr "$_iarr_var"'
    IFS="$ACID_SET_IFS" eval "printf '%s' \"\${$_iarr_var[*]}\""
}

# Convert an associative array to a set string.
# Args: _aarr_var
function acid_set_from_aarr()
{
    declare -r _aarr_var="$1";  shift
    thud_assert 'thud_is_ass_arr "$_aarr_var"'
    IFS="$ACID_SET_IFS" eval "printf '%s' \"\${!$_aarr_var[*]}\""
}

# Output a set with any repeated tags removed.
# Args: set
function acid_set_uniq()
{
    declare -r set="$1"
    declare -A aarr=()
    thud_assert 'acid_set_is_valid "$set"'
    acid_set_to_aarr aarr "$set"
    acid_set_from_aarr aarr
}

# Output a set filtered by a tag predicate.
# Args: set p [p_arg...]
function acid_set_filter()
{
    declare -r set="$1";        shift
    declare -A aarr=()
    declare sep=''
    declare tag
    acid_set_to_aarr aarr "$set"
    for tag in "${!aarr[@]}"; do
        if ! "$@" "$tag"; then
            unset aarr[$tag]
        fi
    done
    acid_set_from_aarr aarr
}

# Check if all set's tags match a predicate.
# Args: set p [p_arg...]
function acid_set_are_all()
{
    declare -r set="$1";        shift
    declare -A aarr=()
    declare tag
    thud_assert 'acid_set_is_valid "$set"'
    acid_set_to_aarr aarr "$set"
    for tag in "${!aarr[@]}"; do
        if ! "$@" "$tag"; then
            return 1
        fi
    done
    return 0
}

# Check if any of the set's tags match a predicate.
# Args: set p [p_arg...]
function acid_set_is_any()
{
    declare -r set="$1";        shift
    declare -A aarr=()
    declare tag
    thud_assert 'acid_set_is_valid "$set"'
    acid_set_to_aarr aarr "$set"
    for tag in "${!aarr[@]}"; do
        if "$@" "$tag"; then
            return 0
        fi
    done
    return 1
}

# Check if an exact set has a tag matching any other tag.
# Args: exact_set any_tag
function acid_set_has_any()
{
    declare -r exact_set="$1";  shift
    declare -r any_tag="$1";    shift
    thud_assert 'acid_set_is_exact "$exact_set"'
    thud_assert 'acid_tag_is_valid "$any_tag"'
    acid_set_is_any "$exact_set" acid_tag_match_exact "$any_tag"
}

# Check if any set has a tag matching an exact tag.
# Args: any_set exact_tag
function acid_set_has_exact()
{
    declare -r any_set="$1";    shift
    declare -r exact_tag="$1";  shift
    thud_assert 'acid_set_is_valid "$any_set"'
    thud_assert 'acid_tag_is_exact "$exact_tag"'
    acid_set_is_any "$any_set" acid_tag_match_any "$exact_tag"
}

# Output a union of an exact and any other set (exact U any).
# Args: exact_set any_set
function acid_set_union()
{
    declare -r exact_set="$1";  shift
    declare -r any_set="$1";    shift
    declare -A exact_aarr=()
    declare -A any_aarr=()
    declare -A union_aarr=()
    declare exact_tag
    declare any_tag
    thud_assert 'acid_set_is_exact "$exact_set"'
    thud_assert 'acid_set_is_valid "$any_set"'
    acid_set_to_aarr exact_aarr "$exact_set"
    acid_set_to_aarr any_aarr "$any_set"
    for exact_tag in "${!exact_aarr[@]}"; do
        for any_tag in "${!any_aarr[@]}"; do
            if [[ $exact_tag == $any_tag ]]; then
                union_aarr[$exact_tag]=true
                break
            fi
        done
    done
    acid_set_from_aarr union_aarr
}

# Output a complement of an exact and any other set (exact - any).
# Args: exact_set any_set
function acid_set_comp()
{
    declare -r exact_set="$1";  shift
    declare -r any_set="$1";    shift
    declare -A exact_aarr=()
    declare -A any_aarr=()
    declare exact_tag
    declare any_tag
    thud_assert 'acid_set_is_exact "$exact_set"'
    thud_assert 'acid_set_is_valid "$any_set"'
    acid_set_to_aarr exact_aarr "$exact_set"
    acid_set_to_aarr any_aarr "$any_set"
    for exact_tag in "${!exact_aarr[@]}"; do
        for any_tag in "${!any_aarr[@]}"; do
            if [[ $exact_tag == $any_tag ]]; then
                unset exact_aarr[$exact_tag]
                break
            fi
        done
    done
    acid_set_from_aarr exact_aarr
}

# Convert an exact set to a prefix glob set.
# Args: exact_set
# Output: prefix glob set
function acid_set_to_pfx()
{
    declare -r exact_set="$1";  shift
    declare -a exact_iarr=()
    declare -a pfx_iarr=()
    declare tag
    thud_assert 'acid_set_is_exact "$exact_set"'
    acid_set_to_iarr exact_iarr "$exact_set"
    for tag in "${exact_iarr[@]}"; do
        pfx_iarr+=("$tag*")
    done
    acid_set_from_iarr pfx_iarr
}

# Convert a prefix glob set to an exact set.
# Args: pfx_set
# Output: exact set
function acid_set_from_pfx()
{
    declare -r pfx_set="$1";  shift
    thud_assert 'acid_set_is_pfx "$pfx_set"'
    printf '%s' "${pfx_set//\*}"
}

fi # _ACID_SET_SH
