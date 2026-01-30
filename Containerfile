ARG SOURCE_DISTRO
ARG SOURCE_TAG
ARG BUILD_VERSION

FROM docker.io/${SOURCE_DISTRO}:${SOURCE_TAG}

ARG SOURCE_DISTRO
ARG SOURCE_TAG
ARG BUILD_VERSION

LABEL org.opencontainers.image.title="TFTP container"
LABEL org.opencontainers.image.description="TFTP running in a container."
LABEL org.opencontainers.image.ref.name="learningtopi/tftpd"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"
LABEL org.opencontainers.image.source="https://github.com/LearningToPi/tftpd_docker"
LABEL org.opencontainers.image.vendor="LearningToPi.com"
LABEL org.opencontainers.image.base.name="docker.io/${SOURCE_DISTRO}:${SOURCE_TAG}"
LABEL org.opencontainers.image.documentation="/README.md"

# install tftpd
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y &&  \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y tftpd-hpa  && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y rsyslog && \
    DEBIAN_FRONTEND=noninteractive apt-get clean -y

# Update config file
ADD tftpd_startup.sh /tftpd_startup.sh
RUN chmod +x /tftpd_startup.sh
RUN mkdir /tftp && chown tftp:tftp /tftp && chmod 775 /tftp

# Add rsyslog config
ADD rsyslog.conf /etc/rsyslog.conf

ENV WRITE_ENABLED=Yes
ENV IPV4_ONLY=No
ENV IPV6_ONLY=No
ENV WORLD_READABLE=No
ENV DEBUG=No
ENV BLOCKSIZE=1400
ENV DATA_PATH="/tftp"

EXPOSE 69/udp

VOLUME ["/tftp"]
ENTRYPOINT ["/tftpd_startup.sh"]
