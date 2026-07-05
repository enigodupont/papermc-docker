#!/bin/bash

# Enter server directory
cd papermc || exit

BASE_URL="https://fill.papermc.io/v3/projects/paper"

# If no version is provided (or "latest"), use the latest Minecraft version
if [ -z "${MC_VERSION}" ] || [ "${MC_VERSION}" = "latest" ]; then
    MC_VERSION=$(wget -qO - "${BASE_URL}" | jq -r '.versions[-1]')
fi

# Get the latest build for the selected Minecraft version unless explicitly set
VERSION_URL="${BASE_URL}/versions/${MC_VERSION}"

if [ -z "${PAPER_BUILD}" ] || [ "${PAPER_BUILD}" = "latest" ]; then
    PAPER_BUILD=$(wget -qO - "${VERSION_URL}" | jq -r '.builds[-1]')
fi

JAR_NAME="paper-${MC_VERSION}-${PAPER_BUILD}.jar"
DOWNLOAD_URL="${VERSION_URL}/builds/${PAPER_BUILD}/download"

# Download/update if necessary
if [ ! -f "${JAR_NAME}" ]; then
    # Remove any old Paper jars
    rm -f -- *.jar

    echo "Downloading Paper ${MC_VERSION} build ${PAPER_BUILD}..."
    wget -O "${JAR_NAME}" "${DOWNLOAD_URL}" || exit 1

    # Accept the EULA on first run
    if [ ! -f eula.txt ]; then
        java -jar "${JAR_NAME}"
        sed -i 's/^eula=false$/eula=true/' eula.txt
    fi
fi

# Add RAM options if configured
if [ -n "${MC_RAM}" ]; then
    JAVA_OPTS="-Xms${MC_RAM} -Xmx${MC_RAM} ${JAVA_OPTS}"
fi

# Start the server
exec java -server ${JAVA_OPTS} -jar "${JAR_NAME}" nogui
