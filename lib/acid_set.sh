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
    IFS="$ACID_SET_IFS" read -r -d '' -a "$_iarr_var" <<<"$_set" || true
}

# Convert a set string to an associative array, with tags having '*' and '@'
# doubled and used as keys.
# Args: _aarr_var _set
function acid_set_to_aarr()
{
    declare -r _aarr_var="$1";  shift
    declare -r _set="$1";       shift
    declare -a _iarr=()
    declare _esc_set
    declare _init_expr
    thud_assert 'thud_is_ass_arr "$_aarr_var"'
    thud_assert 'acid_set_is_valid "$_set"'
    _esc_set=${_set//\*/**}
    _esc_set=${_esc_set//@/@@}
    IFS="$ACID_SET_IFS" read -r -d '' -a _iarr <<<"$_esc_set" || true
    if [[ ${#_iarr[@]} == 0 ]]; then
        _init_expr=""
    else
        printf -v _init_expr '[%q]=true ' "${_iarr[@]}"
    fi
    eval "$_aarr_var+=($_init_expr)"
}

# Convert an indexed array to a set string.
# Args: _iarr_var
function acid_set_from_iarr()
{
    declare -r _iarr_var="$1";  shift
    thud_assert 'thud_is_idx_arr "$_iarr_var"'
    IFS="$ACID_SET_IFS" eval "
        if [[ \${#$_iarr_var[@]} != 0 ]]; then
            printf '%s' \"\${$_iarr_var[*]}\"
        fi
    "
}

# Convert an associative array to a set string, considering keys being tags
# with '*' and '@' doubled.
# Args: _aarr_var
function acid_set_from_aarr()
{
    declare -r _aarr_var="$1";  shift
    declare _esc_set
    declare _set
    thud_assert 'thud_is_ass_arr "$_aarr_var"'
    IFS="$ACID_SET_IFS" eval "_esc_set=\"\${!$_aarr_var[*]}\""
    _esc_set=${_esc_set//\*\*/*}
    _set=${_esc_set//@@/@}
    printf '%s' "$_set"
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
    declare -a iarr=()
    declare sep=''
    declare tag
    thud_assert 'acid_set_is_valid "$set"'
    if acid_set_is_empty "$set"; then
        return 0
    fi
    acid_set_to_iarr iarr "$set"
    for tag in "${iarr[@]}"; do
        if ! "$@" "$tag"; then
            unset iarr[$tag]
        fi
    done
    acid_set_from_iarr iarr
}

# Check if an exact set is a subset of any other set.
# Args: exact_set any_set
function acid_set_is_subset()
{
    declare -r exact_set="$1";  shift
    declare -r any_set="$1";    shift
    declare -a exact_iarr=()
    declare -a any_iarr=()
    declare exact_tag
    declare any_tag
    thud_assert 'acid_set_is_exact "$exact_set"'
    thud_assert 'acid_set_is_valid "$any_set"'
    if acid_set_is_empty "$exact_set"; then
        return 0
    fi
    if acid_set_is_empty "$any_set"; then
        return 1
    fi
    acid_set_to_iarr exact_iarr "$exact_set"
    acid_set_to_iarr any_iarr "$any_set"
    for exact_tag in "${!exact_iarr[@]}"; do
        for any_tag in "${!any_iarr[@]}"; do
            if [[ $exact_tag != $any_tag ]]; then
                return 1
            fi
        done
    done
    return 0
}

# Output a union of two exact sets
# Args: set_a set_b
function acid_set_union()
{
    declare -r set_a="$1";  shift
    declare -r set_b="$1";  shift
    declare -A union_aarr=()
    thud_assert 'acid_set_is_exact "$set_a"'
    thud_assert 'acid_set_is_exact "$set_b"'
    acid_set_to_aarr union_aarr "$set_a"
    acid_set_to_aarr union_aarr "$set_b"
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
    declare any_key
    declare any_tag
    thud_assert 'acid_set_is_exact "$exact_set"'
    thud_assert 'acid_set_is_valid "$any_set"'
    if acid_set_is_empty "$exact_set" ||
       acid_set_is_empty "$any_set"; then
        printf '%s' "$exact_set"
        return 0
    fi
    acid_set_to_aarr exact_aarr "$exact_set"
    acid_set_to_aarr any_aarr "$any_set"
    for exact_tag in "${!exact_aarr[@]}"; do
        for any_key in "${!any_aarr[@]}"; do
            acid_tag_from_key any_tag any_key
            if [[ $exact_tag == $any_tag ]]; then
                unset exact_aarr[$exact_tag]
                break
            fi
        done
    done
    acid_set_from_aarr exact_aarr
}

# Output an intersection of an exact and any other set (exact ∩ any).
# Args: exact_set any_set
function acid_set_intersect()
{
    declare -r exact_set="$1";  shift
    declare -r any_set="$1";    shift
    declare -A exact_aarr=()
    declare -A any_aarr=()
    declare -a result_iarr=()
    declare exact_tag
    declare any_key
    declare any_tag
    thud_assert 'acid_set_is_exact "$exact_set"'
    thud_assert 'acid_set_is_valid "$any_set"'
    if acid_set_is_empty "$exact_set" ||
       acid_set_is_empty "$any_set"; then
        return 0
    fi
    acid_set_to_aarr exact_aarr "$exact_set"
    acid_set_to_aarr any_aarr "$any_set"
    for exact_tag in "${!exact_aarr[@]}"; do
        for any_key in "${!any_aarr[@]}"; do
            acid_tag_from_key any_tag any_key
            if [[ $exact_tag == $any_tag ]]; then
                result_iarr+=("$exact_tag")
                break
            fi
        done
    done
    acid_set_from_iarr result_iarr
}

# Check if an exact set intersects any other set (exact ∩ any != ∅).
# Args: exact_set any_set
function acid_set_intersects()
{
    declare -r exact_set="$1";  shift
    declare -r any_set="$1";    shift
    declare -a exact_iarr=()
    declare -a any_iarr=()
    declare exact_tag
    declare any_tag
    thud_assert 'acid_set_is_exact "$exact_set"'
    thud_assert 'acid_set_is_valid "$any_set"'
    if acid_set_is_empty "$exact_set" ||
       acid_set_is_empty "$any_set"; then
        return 1
    fi
    acid_set_to_iarr exact_iarr "$exact_set"
    acid_set_to_iarr any_iarr "$any_set"
    for any_tag in "${any_iarr[@]}"; do
        for exact_tag in "${exact_iarr[@]}"; do
            if [[ $exact_tag == $any_tag ]]; then
                return 0
            fi
        done
    done
    return 1
}

# Output a set containing tags of any set matching at least one tag in an
# exact set.
# Args: any_set exact_set
function acid_set_hit()
{
    declare -r any_set="$1";    shift
    declare -r exact_set="$1";  shift
    declare -A any_aarr=()
    declare -A exact_aarr=()
    declare -a hit_iarr=()
    declare any_tag
    declare any_key
    declare exact_tag
    thud_assert 'acid_set_is_valid "$any_set"'
    thud_assert 'acid_set_is_exact "$exact_set"'
    if acid_set_is_empty "$any_set" ||
       acid_set_is_empty "$exact_set"; then
        return 0
    fi
    acid_set_to_aarr any_aarr "$any_set"
    acid_set_to_aarr exact_aarr "$exact_set"
    for any_key in "${!any_aarr[@]}"; do
        acid_tag_from_key any_tag any_key
        for exact_tag in "${!exact_aarr[@]}"; do
            if [[ $exact_tag == $any_tag ]]; then
                hit_iarr+=("$any_tag")
                break
            fi
        done
    done
    acid_set_from_iarr hit_iarr
}

# Output a set containing tags of any set *not* matching any of the tags in an
# exact set.
# Args: any_set exact_set
function acid_set_miss()
{
    declare -r any_set="$1";    shift
    declare -r exact_set="$1";  shift
    declare -A any_aarr=()
    declare -A exact_aarr=()
    declare any_tag
    declare any_key
    declare exact_tag
    thud_assert 'acid_set_is_valid "$any_set"'
    thud_assert 'acid_set_is_exact "$exact_set"'
    if acid_set_is_empty "$any_set" ||
       acid_set_is_empty "$exact_set"; then
        printf '%s' "$any_set"
        return 0
    fi
    acid_set_to_aarr any_aarr "$any_set"
    acid_set_to_aarr exact_aarr "$exact_set"
    for any_key in "${!any_aarr[@]}"; do
        acid_tag_from_key any_tag any_key
        for exact_tag in "${!exact_aarr[@]}"; do
            if [[ $exact_tag == $any_tag ]]; then
                unset any_aarr[$any_key]
                break
            fi
        done
    done
    acid_set_from_aarr any_aarr
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
    if acid_set_is_empty "$exact_set"; then
        return 0
    fi
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
