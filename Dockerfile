# JRE base
FROM amazoncorretto:19.0.1

# Place script at root
WORKDIR /

# Container setup
EXPOSE 25565/tcp
EXPOSE 25565/udp
VOLUME /papermc

# Environment variables
ENV MC_VERSION="latest" \
    PAPER_BUILD="latest" \
    MC_RAM="" \
    JAVA_OPTS=""

COPY papermc.sh .
RUN yum install -y wget jq && yum clean all

# Start script
CMD ["sh", "./papermc.sh"]