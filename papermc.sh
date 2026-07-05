#!/bin/bash
set -euo pipefail

# Enter server directory
cd papermc || exit 1

BASE_URL="https://fill.papermc.io/v3/projects/paper"

# Paper requests that API clients send a descriptive User-Agent.
# Replace the email below with your own if desired.
USER_AGENT="paper-updater/1.0 (admin@example.com)"

# -----------------------------------------------------------------------------
# Determine Minecraft version
# -----------------------------------------------------------------------------
if [ -z "${MC_VERSION:-}" ] || [ "${MC_VERSION}" = "latest" ]; then
    MC_VERSION=$(
        curl -fsSL \
            -H "User-Agent: ${USER_AGENT}" \
            "${BASE_URL}" \
        | jq -r '.versions[-1]'
    )
fi

echo "Minecraft version: ${MC_VERSION}"

# -----------------------------------------------------------------------------
# Fetch builds for the selected version
# -----------------------------------------------------------------------------
BUILDS_JSON=$(
    curl -fsSL \
        -H "User-Agent: ${USER_AGENT}" \
        "${BASE_URL}/versions/${MC_VERSION}/builds"
)

# -----------------------------------------------------------------------------
# Determine build
# -----------------------------------------------------------------------------
if [ -z "${PAPER_BUILD:-}" ] || [ "${PAPER_BUILD}" = "latest" ]; then
    PAPER_BUILD=$(
        echo "${BUILDS_JSON}" \
        | jq -r 'map(select(.channel == "STABLE")) | .[0].id'
    )

    # Fall back to first build if no STABLE channel exists
    if [ "${PAPER_BUILD}" = "null" ] || [ -z "${PAPER_BUILD}" ]; then
        PAPER_BUILD=$(
            echo "${BUILDS_JSON}" \
            | jq -r '.[0].id'
        )
    fi
fi

echo "Paper build: ${PAPER_BUILD}"

# -----------------------------------------------------------------------------
# Get download URL from API
# -----------------------------------------------------------------------------
DOWNLOAD_URL=$(
    echo "${BUILDS_JSON}" \
    | jq -r --argjson build "${PAPER_BUILD}" '
        .[]
        | select(.id == $build)
        | .downloads["server:default"].url
    '
)

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
    echo "Unable to locate download URL for Paper ${MC_VERSION} build ${PAPER_BUILD}"
    exit 1
fi

JAR_NAME="paper-${MC_VERSION}-${PAPER_BUILD}.jar"

# -----------------------------------------------------------------------------
# Download if necessary
# -----------------------------------------------------------------------------
if [ ! -f "${JAR_NAME}" ]; then
    rm -f -- *.jar

    echo "Downloading ${JAR_NAME}..."

    curl -fL \
        -H "User-Agent: ${USER_AGENT}" \
        -o "${JAR_NAME}" \
        "${DOWNLOAD_URL}"

    if [ ! -f eula.txt ]; then
        echo "Generating EULA..."
        java -jar "${JAR_NAME}" || true
        sed -i 's/^eula=false$/eula=true/' eula.txt
    fi
fi

# -----------------------------------------------------------------------------
# Memory options
# -----------------------------------------------------------------------------
if [ -n "${MC_RAM:-}" ]; then
    JAVA_OPTS="-Xms${MC_RAM} -Xmx${MC_RAM} ${JAVA_OPTS:-}"
fi

# -----------------------------------------------------------------------------
# Start server
# -----------------------------------------------------------------------------
exec java -server ${JAVA_OPTS:-} -jar "${JAR_NAME}" nogui
