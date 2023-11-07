#!/bin/bash
# See this doc about default GitHub Actions variables
#   https://docs.github.com/en/actions/learn-github-actions/variables#default-environment-variables
# - GITHUB_REF_NAME is the branch name
# - GITHUB_SHA is the full sha, so it's a bit too long

#!/bin/bash

# Should we make a git tag or not?
create_git_tag=${1:-"false"}

# elog - echo for logging
elog() {
    echo "$*" >&2
}

getJenkinsVersion() {
    # Fetch the current version of jenkins form Dockerfile
    cat master/Dockerfile | grep jenkins/jenkins | cut -f2 -d":"
}

determineRepoVersion() {
    NO_TAG_MARKER=noTagOnThisBranch

    elog Fetching existing tags
    git fetch --tags

    # Figure out version coordinates
    tagResult=$(git describe --match '${GITHUB_REF_NAME}*' 2>/dev/null || echo ${NO_TAG_MARKER})
    # elog "DEBUG: Version coordinates: ${tagResult}"

    # Remove any spaces
    tagResult="${tagResult//[[:space:]]/}"
    # elog "DEBUG: Remove any spaces: ${tagResult}"

    # If this branch has a tag, then we are done
    if [[ "${tagResult}" != "${NO_TAG_MARKER}" ]]; then
        # elog "DEBUG DONE 1! Found some tagResult: ${tagResult}"
        echo ${tagResult}
        return 0
    fi

    elog No tag found in this branch. Looking at parent branches
    tagResult=$(git describe --always)
    # elog "DEBUG: git describe --always: ${tagResult}"

    # Remove any spaces
    tagResult="${tagResult//[[:space:]]/}"
    # elog "DEBUG: Remove any spaces: ${tagResult}"
    # Replace / and # with -
    tagResult=${tagResult//\//\-} # Replace all '/' with '-'
    tagResult=${tagResult//#/\-} # Replace all '#' with '-'
    # elog "DEBUG: DONE 2! Replaced / and #: ${tagResult}"
    echo ${tagResult}
    return 0
}

is_on_topic_branch() {
    lower_case_branch=$(echo "${GITHUB_REF_NAME}" | tr '[:upper:]' '[:lower:]')
    if [[ "${lower_case_branch}" == *"/"* ]]; then
        result=true
    else
        result=false
    fi
    echo ${result}
}

is_new_jenkins_version() {
    jcore_version=$1
    current_repo_version=$2
    if [[ "${current_repo_version}" == *"${jcore_version}"* ]]; then
        echo false
    else
        echo true
    fi
}

generate_tag_name_for_branch() {
    jenkinsVersion=$1
    echo "${GITHUB_REF_NAME}-${jenkinsVersion}"
}


isOnTopicBranch=$(is_on_topic_branch)
jcoreVersion=$(getJenkinsVersion)
repoVersion=$(determineRepoVersion)
isNewJenkinsVersion=$(is_new_jenkins_version $jcoreVersion $repoVersion)
version=$repoVersion
if [[ isOnTopicBranch == "false" && isNewJenkinsVersion == "true" ]]; then
    version=$(generate_tag_name_for_branch $jcoreVersion)
fi

# elog "isOnTopicBranch: $isOnTopicBranch"
# elog "jcoreVersion: $jcoreVersion"
# elog "repoVersion: $repoVersion"
# elog "isNewJenkinsVersion: $isNewJenkinsVersion"
# elog "The version was determined to be '${version}'"

if [[ $isOnTopicBranch == "true" ]]; then
    elog "\
    Git branch         : ${GITHUB_REF_NAME} (topic branch)
    Jenkins version    : ${jcoreVersion}
    jcasc-core version : ${version}
    Skipping git tagging as we are on a topic branch"
elif [[ $isNewJenkinsVersion == "true" ]]; then
    elog "\
    Git branch         : ${GITHUB_REF_NAME} (not a topic branch)
    Jenkins version    : ${jcoreVersion}
    jcasc-core version : ${version}
    Potential Tag name : ${version}"
    if [[ $create_git_tag == "true" ]]; then
        elog "    Creating a new git tag as Jenkins was upgraded"
        git tag -a -f -m "Jenkins version: ${jcoreVersion}" ${version}
        git push origin ${version}
    else
        elog "No new git tag as create_git_tag == ${create_git_tag}"
    fi
else
    elog "\
    Git branch         : ${GITHUB_REF_NAME} (not a topic branch)
    Jenkins version    : ${jcoreVersion}
    jcasc-core version : ${version}
    Skip git tagging as Jenkins was not upgraded
    "
fi
echo $version