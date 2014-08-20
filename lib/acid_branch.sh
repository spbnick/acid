#
# ACID - branch configuration
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

if [ -z "${_ACID_BRANCH_SH+set}" ]; then
declare -r _ACID_BRANCH_SH=

. thud_arr.sh
. acid_git.sh

declare -r ACID_BRANCH_SHIFT='
    declare -r branch_str="$1";    shift
    declare -A branch=()
    thud_arr_parse branch <<<"$branch_str"
'

# Load a branch.
# Args: git_dir name
# Output: branch string
function acid_branch_load()
{
    declare -r git_dir="$1";    shift
    declare -r name="$1";   shift
    declare git_str
    git_str=`acid_git_load "$git_dir" "branch.${name}.acid-"`
    thud_assert 'acid_git_branch_exists "$git_str" "$name"'

    declare -A branch=()
    thud_arr_parse branch <<<"$git_str"

    branch[name]="$name"
    branch[enabled]=`acid_git_conf_get_bool "$git_str" enabled || echo false`
    branch[pre_selected]=`acid_git_conf_get_all "$git_str" pre-selected ||
                            true`
    branch[pre_selected]=`acid_set_uniq "${branch[pre_selected]}"`
    branch[pre_defaults]=`
        acid_git_conf_get_all "$git_str" pre-defaults || true
    `
    branch[pre_defaults]=`acid_set_uniq "${branch[pre_defaults]}"`
    branch[post_selected]=`acid_git_conf_get_all "$git_str" post-selected ||
                            true`
    branch[post_selected]=`acid_set_uniq "${branch[post_selected]}"`

    thud_arr_print branch
}

fi # _ACID_BRANCH_SH
