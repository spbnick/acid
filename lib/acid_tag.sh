#
# ACID - tag (set element) operations
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

if [ -z "${_ACID_TAG_SH+set}" ]; then
declare -r _ACID_TAG_SH=

declare -r ACID_TAG_CS_EXACT='A-Za-z0-9_:-' # Must match >= 64 characters
declare -r ACID_TAG_CS_GLOB='][^.=*?+@!()|'
declare -r ACID_TAG_CS="$ACID_TAG_CS_GLOB$ACID_TAG_CS_EXACT"

# Check if a string is a valid tag.
# Args: str
function acid_tag_is_valid()
{
    [[ "$1" =~ ^[$ACID_TAG_CS]+$ ]]
}

# Check if a string is an exact tag.
# Args: str
function acid_tag_is_exact()
{
    [[ "$1" =~ ^[$ACID_TAG_CS_EXACT]+$ ]]
}

# Check if a string is a glob tag.
# Args: str
function acid_tag_is_glob()
{
    [[ "$1" =~ ^[$ACID_TAG_CS]+$ &&
       "$1" =~ [$ACID_TAG_CS_GLOB] ]]
}

# Check if a string is a prefix tag.
# Args: str
function acid_tag_is_pfx()
{
    [[ "$1" =~ ^[$ACID_TAG_CS_EXACT]+\*$ ]]
}

# Convert an exact tag to a prefix tag.
# Args: exact_tag
# Output: pfx_tag
function acid_tag_to_pfx()
{
    declare -r exact_tag="$1"
    thud_assert 'acid_tag_is_exact "$exact_tag"'
    printf '%s*' "$exact_tag"
}

# Convert a prefix tag to an exact tag.
# Args: pfx_tag
# Output: exact_tag
function acid_tag_from_pfx()
{
    declare -r pfx_tag="$1"
    thud_assert 'acid_tag_is_pfx "$pfx_tag"'
    printf '%s' "${pfx_tag:0:${#pfx_tag}-1}"
}

# Check if an exact and any other tag match.
# Args: exact_tag any_tag
function acid_tag_match_any()
{
    declare -r exact_tag="$1";  shift
    declare -r any_tag="$1";    shift
    thud_assert 'acid_tag_is_exact "$exact_tag"'
    thud_assert 'acid_tag_is_valid "$any_tag"'
    [[ $exact_tag == $any_tag ]]
}

# Check if any tag matches an exact tag.
# Args: any_tag exact_tag
function acid_tag_match_exact()
{
    acid_tag_match_any "$2" "$1"
}

fi # _ACID_TAG_SH
