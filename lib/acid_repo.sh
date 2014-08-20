#
# ACID - git repository
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

if [ -z "${_ACID_REPO_SH+set}" ]; then
declare -r _ACID_REPO_SH=

. thud_arr.sh
. acid_git.sh
. acid_var.sh
. acid_branch.sh

declare -r ACID_REPO_SHIFT='
    declare -r repo_str="$1";    shift
    declare -A repo=()
    thud_arr_parse repo <<<"$repo_str"
'

# Load a repo.
# Args: git_dir
# Output: repo string
function acid_repo_load()
{
    declare -r git_dir="$1";    shift
    declare git_str
    git_str=`acid_git_load "$git_dir" ""`
    declare -A repo=()
    thud_arr_parse repo <<<"$git_str"
    declare -A var_map=()
    declare var_name
    declare var_str
    declare -A var
    declare set
    declare -A branch_map=()
    declare branch_str
    declare -A branch
    declare var_selected
    declare var_defaults
    repo+=(
        [set]=""
    )

    #
    # Read global settings
    #
    repo[script_pfx]=`acid_git_conf_get "$git_str" acid.script-pfx || true`
    repo[script_sfx]=`acid_git_conf_get "$git_str" acid.script-sfx || true`
    repo[pre_script]=`acid_git_conf_get "$git_str" acid-pre.script || true`
    repo[post_script]=`acid_git_conf_get "$git_str" acid-post.script || true`

    #
    # Read variables
    #
    while read -r var_name; do
        if ! var_str=`acid_var_load "$git_dir" "$var_name"`; then
            echo "Failed to get variable from configuration: $var_name" >&2
            return 1
        fi
        var=()
        thud_arr_parse var <<<"$var_str"

        # Check for tag ambiguity
        set=`acid_set_intersect "${repo[set]}" "${var[set]}"`
        if ! acid_set_is_empty "$set"; then
            echo "Variable \"$var_name\" has non-unique tags: $set" >&2
            return 1
        fi

        repo[set]=`acid_set_union "${repo[set]}" "${var[set]}"`
        var_map[$var_name]="$var_str"
        if acid_var_is_scope "$var_str"; then
            repo[scope_var]="$var_name"
        fi
    done < <(
        acid_git_conf_list_regexp "$git_str" 'acid-var\.' |
            cut -d. -f2 | sort -u
    )
    # Check that scope variable is defined
    if [[ -z ${repo[scope_var]-} ]]; then
        echo "No scope variable defined" >&2
        return 1
    fi
    # Store variable map
    repo[var_map]=`thud_arr_print var_map`

    #
    # Read all applicable branches
    #
    while read -r branch_name; do
        if ! branch_str=`acid_branch_load "$git_dir" "$branch_name"`; then
            echo "Failed to get branch from configuration: $branch_name" >&2
            return 1
        fi
        branch=()
        thud_arr_parse branch <<<"$branch_str"
        "${branch[enabled]}" || continue

        # Check that each mask tag matches at least one supported tag
        set=`acid_set_miss "${branch[pre_selected]}" "${repo[set]}"`
        if ! acid_set_is_empty "$set"; then
            echo "Branch \"$branch_name\" selects unknown" \
                 "pre-commit tags: $set" >&2
            return 1
        fi
        set=`acid_set_miss "${branch[post_selected]}" "${repo[set]}"`
        if ! acid_set_is_empty "$set"; then
            echo "Branch \"$branch_name\" selects unknown" \
                 "post-commit tags: $set" >&2
            return 1
        fi

        # Check that all default tags match at least one supported tag
        set=`acid_set_miss "${branch[pre_defaults]}" "${repo[set]}"`
        if ! acid_set_is_empty "$set"; then
            echo "Branch \"$branch_name\" defaults to unknown" \
                 "pre-commit tags: $set" >&2
            return 1
        fi

        # For each variable
        for var_name in "${!var_map[@]}"; do
            var_str=${var_map[$var_name]}
            thud_arr_parse var <<<"$var_str"

            #
            # Check pre-commit tags
            #

            # Produce selected set
            var_selected=`acid_set_intersect "${var[set]}" \
                                             "${branch[pre_selected]}"`
            if acid_set_is_empty "$var_selected"; then
                echo "Branch \"$branch_name\" doesn't select" \
                     "any pre-commit \"$var_name\" tags" >&2
                return 1
            fi

            # Check that defaults select from selected tags
            set=`acid_set_hit "${branch[pre_defaults]}" "${var[set]}"`
            set=`acid_set_miss "$set" "$var_selected"`
            if ! acid_set_is_empty "$set"; then
                echo "Some \"$branch_name\" branch pre-commit defaults" \
                     "match masked-out \"$var_name\" tags: $set" >&2
                return 1
            fi

            # Produce default set
            var_defaults=`acid_set_intersect "$var_selected" \
                                             "${branch[pre_defaults]}"`
            if acid_set_is_empty "$var_defaults"; then
                echo "Branch \"$branch_name\" pre-commit defaults" \
                     "don't match any selected \"$var_name\" tags" >&2
                return 1
            fi

            # Check that defaults are not ambiguous
            if acid_var_is_exclusive "$var_str" &&
               ! acid_set_is_singleton "$var_defaults"; then
                echo "Branch \"$branch_name\" defaults to ambiguous" \
                     "\"$var_name\" pre-commit tag set: $var_defaults" >&2
                return 1
            fi

            #
            # Check post-commit tags
            #

            # Produce selected set
            var_selected=`acid_set_intersect "${var[set]}" \
                                             "${branch[post_selected]}"`
            if acid_set_is_empty "$var_selected"; then
                echo "Branch \"$branch_name\" doesn't select" \
                     "any post-commit \"$var_name\" tags" >&2
                return 1
            fi

            # Check that selected tags are not ambiguous
            if acid_var_is_exclusive "$var_str" &&
               ! acid_set_is_singleton "$var_selected"; then
                echo "Branch \"$branch_name\" selects ambiguous" \
                     "\"$var_name\" post-commit tag set: $var_selected" >&2
                return 1
            fi

        done

        # Store branch
        branch_map[$branch_name]="$branch_str"
    done < <(acid_git_branch_list "$git_str")

    # Store branch map
    repo[branch_map]=`thud_arr_print branch_map`

    thud_arr_print repo
}

# (Attempt to) handle a reference update.
# Args: repo_str act rev_old rev_new ref
# Output: error messages, if any
function acid_repo_ref_update()
{
    eval "$ACID_REPO_SHIFT"
    declare -r act="$1";        shift
    declare -r rev_old="$1";    shift
    declare -r rev_new="$1";    shift
    declare -r ref="$1";        shift
    declare ref_dest_raw
    declare ref_dest
    declare ref_branch
    declare -A branch_map=()
    declare branch_str
    declare -A branch=()
    declare ref_pfx_list
    declare ref_set
    declare branch_selected
    declare ref_selected
    declare set
    declare -A var_map=()
    declare var_name
    declare var_str
    declare -A var
    declare var_selected
    declare -A val_map=()

    thud_assert 'thud_is_bool "$act"'

    if [[ "$rev_new" =~ ^0{40}$ ]]; then
        echo "Reference removal is not supported: $ref"
        return 1
    fi

    #
    # Retrieve and validate destination
    #
    ref_dest_raw=${ref%%,*}
    ref_dest=`GIT_DIR="${repo[git_dir]}" \
                    git check-ref-format --normalize "$ref_dest_raw"` || {
        echo "Invalid destination: $ref_dest_raw"
        return 1
    }
    if [[ $ref_dest =~ ^refs/for/([^/]+)$ ]]; then
        ref_branch=${BASH_REMATCH[1]}
    else
        echo "Destination doesn't begin with \"refs/for/\": $ref_dest"
        return 1
    fi

    if ! acid_git_branch_exists "$repo_str" "$ref_branch"; then
        echo "Destination branch doesn't exist: $ref_branch"
        return 1
    fi

    thud_arr_parse branch_map <<<"${repo[branch_map]}"
    branch_str="${branch_map[$ref_branch]-}"
    if [[ -z "$branch_str" ]]; then
        echo "Destination branch is not configured for CI: $ref_branch"
        return 1
    fi

    thud_arr_parse branch <<<"$branch_str"
    branch_selected=`acid_set_intersect "${repo[set]}" \
                                        "${branch[pre_selected]}"`

    #
    # Retrieve and validate tags
    #
    if [[ $ref != *,* ]]; then
        ref_set=""
    else
        ref_pfx_list=${ref#*,}
        ref_set=${ref_pfx_list//,/ }
        if ! acid_set_is_exact "$ref_set"; then
            echo "Invalid tag prefix list: $ref_pfx_list"
            return 1
        fi
        ref_set=`acid_set_to_pfx "$ref_set"`
    fi

    # Check if any of the supplied tags don't match any of the tags selected
    # for the branch
    set=`acid_set_miss "$ref_set" "$branch_selected"`
    if ! acid_set_is_empty "$set"; then
        set=`acid_set_from_pfx "$set"`
        echo "Some tag prefixes don't match any allowed tags: $set" >&2
        # TODO Output allowed tags with instructions
        return 1
    fi

    # Produce selected tag set
    ref_selected=`acid_set_intersect "$branch_selected" "$ref_set"`

    # For each variable
    thud_arr_parse var_map <<<"${repo[var_map]}"
    for var_name in "${!var_map[@]}"; do
        var_str="${var_map[$var_name]}"
        var=()
        thud_arr_parse var <<<"$var_str"

        # If no variable tags were specified
        var_selected=`acid_set_intersect "$ref_selected" "${var[set]}"`
        if acid_set_is_empty "$var_selected"; then
            var_selected=`acid_set_intersect "${var[set]}" \
                                             "${branch[pre_defaults]}"`
        else
            if acid_var_is_exclusive "$var_str" &&
               ! acid_set_is_singleton "$var_selected"; then
                echo "Specified tag prefixes match ambigous" \
                     "\"$var_name\" tag set: $var_selected" >&2
                return 1
            fi
        fi
        val_map[$var_name]="$var_selected"
    done

    # If not asked to act
    if ! "$act"; then
        return 0
    fi

    # TODO Output selected values
}

fi # _ACID_REPO_SH
