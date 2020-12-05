#!/bin/bash

set -u

function parseInputs(){
	# Required inputs
	if [ "${INPUT_CDK_SUBCOMMAND}" == "" ]; then
		echo "Input cdk_subcommand cannot be empty"
		exit 1
	fi
}

checkRequirements() {
	if [ ! -d "${INPUT_WORKING_DIR}" ]; then
		if [ ! -e "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIR}/cdk.json" ]; then
			echo "${GITHUB_WORKSPACE}/${INPUT_WORKING_DIR}/cdk.json does not exit!";
			exit 1;
		fi
	fi
}

function installYarn(){
	npm install -g yarn
}

function installDeps(){
	yarn install --checkfiles --frozen-lockfile
}

function installAwsCdk(){
	echo "Install aws-cdk ${INPUT_CDK_VERSION}"
	if [ "${INPUT_CDK_VERSION}" == "latest" ]; then
		if [ "${INPUT_DEBUG_LOG}" == "true" ]; then
			yarn global add aws-cdk
		else
			yarn global add aws-cdk >/dev/null 2>&1
		fi

		if [ "${?}" -ne 0 ]; then
			echo "Failed to install aws-cdk ${INPUT_CDK_VERSION}"
		else
			echo "Successful install aws-cdk ${INPUT_CDK_VERSION}"
		fi
	else
		if [ "${INPUT_DEBUG_LOG}" == "true" ]; then
			yarn global add -g aws-cdk@"${INPUT_CDK_VERSION}"
		else
			yarn global add aws-cdk@"${INPUT_CDK_VERSION}" >/dev/null 2>&1
		fi

		if [ "${?}" -ne 0 ]; then
			echo "Failed to install aws-cdk ${INPUT_CDK_VERSION}"
		else
			echo "Successful install aws-cdk ${INPUT_CDK_VERSION}"
		fi
	fi
}

function installPipRequirements(){
	if [ -e "requirements.txt" ]; then
		echo "Install requirements.txt"
		if [ "${INPUT_DEBUG_LOG}" == "true" ]; then
			pip install -r requirements.txt
		else
			pip install -r requirements.txt >/dev/null 2>&1
		fi

		if [ "${?}" -ne 0 ]; then
			echo "Failed to install requirements.txt"
		else
			echo "Successful install requirements.txt"
		fi
	fi
}

function runCdk(){
	echo "Run cdk ${INPUT_CDK_SUBCOMMAND} ${*} \"${INPUT_CDK_STACK}\""
	subCommand=${INPUT_CDK_SUBCOMMAND}
	if [ "${INPUT_CDK_SUBCOMMAND}" == "bootstrap"]: then
		output=$(cdk "${subCommand}" "${*}" 2>&1)
	else
		output=$(cdk "${subCommand}" "${*}" "${INPUT_CDK_STACK}" 2>&1)
	fi
	exitCode=${?}
	echo ::set-output name=status_code::${exitCode}
	echo "${output}"

	commentStatus="Failed"
	if [ "${exitCode}" == "0" ] || [ "${exitCode}" == "1" ]; then
		commentStatus="Success"
	fi

	if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "${INPUT_ACTIONS_COMMENT}" == "true" ]; then
		commentWrapper="#### \`cdk ${INPUT_CDK_SUBCOMMAND}\` ${commentStatus}
<details><summary>Show Output</summary>

\`\`\`
${output}
\`\`\`

</details>

*Workflow: \`${GITHUB_WORKFLOW}\`, Action: \`${GITHUB_ACTION}\`, Working Directory: \`${INPUT_WORKING_DIR}\`*"

		payload=$(echo "${commentWrapper}" | jq -R --slurp "{body: .}")
		commentsURL=$(cat "${GITHUB_EVENT_PATH}" | jq -r .pull_request.comments_url)

		echo "${payload}" | curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data @- "${commentsURL}" > /dev/null
	fi
}

function main(){
	parseInputs
	checkRequirements
	installYarn
	installAwsCdk

	echo "Cdk Project Path: ${GITHUB_WORKSPACE}"/"${INPUT_WORKING_DIR}"
	cd "${GITHUB_WORKSPACE}"/"${INPUT_WORKING_DIR}"
	ls -lah
	installDeps
	installPipRequirements
	runCdk "${INPUT_CDK_ARGS}"
}

main
