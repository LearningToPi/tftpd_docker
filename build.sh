#!/bin/bash -v


VERSION=$1
SOURCE_DISTRO='ubuntu'
SOURCE_TAG='latest'
REGISTRY="docker.io"
PACKAGE="learningtopi/tftpd"

docker pull docker.io/${SOURCE_DISTRO}:${SOURCE_TAG}
RETCODE=$?
if [ "${RETCODE}" -ne 0 ] ; then
    echo "Failed to pull ${SOURCE_DISTRO}:{$SOURCE_TAG}.  Return code ${RECODE}"
    quit $RETCODE
fi

IMAGE_SOURCE_DISTRO=`docker image inspect ${SOURCE_DISTRO}:${SOURCE_TAG} -f '{{index .Config.Labels "org.opencontainers.image.ref.name"}}'`
IMAGE_VERSION=`docker image inspect ${SOURCE_DISTRO}:${SOURCE_TAG} -f '{{index .Config.Labels "org.opencontainers.image.version"}}'`

docker build -f Containerfile . -t $REGISTRY/$PACKAGE:${VERSION} -t $REGISTRY/$PACKAGE:latest --build-arg VERSION="${IMAGE_SOURCE_DISTRO}-${IMAGE_VERSION}"
RETCODE=$?

if [ "${RETCODE}" -ne 0 ] ; then
    echo "\n\nBuild failed with return code $RETCODE"
    exit $RETCODE
fi

echo ""
echo "Build completeled for $REGISTRY/$PACKAGE:$VERSION using $SOURCE_DISTRO:$SOURCE_TAG"
