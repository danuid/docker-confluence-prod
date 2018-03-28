FROM anapsix/alpine-java:8_jdk
MAINTAINER Atlassian Confluence

ENV RUN_USER            daemon
ENV RUN_GROUP           daemon

# https://confluence.atlassian.com/doc/confluence-home-and-other-important-directories-590259707.html
ENV CONFLUENCE_HOME          /var/atlassian/application-data/confluence
ENV CONFLUENCE_INSTALL_DIR   /opt/atlassian/confluence

VOLUME ["${CONFLUENCE_HOME}"]

# Expose HTTP and Synchrony ports
EXPOSE 8090
EXPOSE 8091

WORKDIR $CONFLUENCE_HOME

CMD ["/entrypoint.sh", "-fg"]
ENTRYPOINT ["/sbin/tini", "--"]

RUN apk update -qq \
    && apk add ca-certificates wget curl openssh bash procps openssl perl ttf-dejavu tini \
    && update-ca-certificates \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ /tmp/* /var/tmp/*

COPY entrypoint.sh              /entrypoint.sh

ARG CONFLUENCE_VERSION=6.8.0
ARG DOWNLOAD_URL=http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONFLUENCE_VERSION}.tar.gz

COPY . /tmp

RUN mkdir -p                             ${CONFLUENCE_INSTALL_DIR} \
    && curl -L --silent                  ${DOWNLOAD_URL} | tar -xz --strip-components=1 -C "$CONFLUENCE_INSTALL_DIR" \
    && chown -R ${RUN_USER}:${RUN_GROUP} ${CONFLUENCE_INSTALL_DIR}/ \
    && sed -i -e 's/-Xms\([0-9]\+[kmg]\) -Xmx\([0-9]\+[kmg]\)/-Xms\${JVM_MINIMUM_MEMORY:=\1} -Xmx\${JVM_MAXIMUM_MEMORY:=\2} \${JVM_SUPPORT_RECOMMENDED_ARGS} -Dconfluence.home=\${CONFLUENCE_HOME}/g' ${CONFLUENCE_INSTALL_DIR}/bin/setenv.sh \
    && sed -i -e 's/port="8090"/port="8090" secure="${catalinaConnectorSecure}" scheme="${catalinaConnectorScheme}" proxyName="${catalinaConnectorProxyName}" proxyPort="${catalinaConnectorProxyPort}"/' ${CONFLUENCE_INSTALL_DIR}/conf/server.xml

# also package database JDBC drivers
ARG MYSQL_DRIVER_URL=https://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz
ARG JAR_FILE=mysql-connector-java-5.1.46-bin.jar

RUN mkdir -p /tmp/mysql_driver_extracted/ \
    && curl -L --silent ${MYSQL_DRIVER_URL} | tar -xz --strip-components=1 -C "/tmp/mysql_driver_extracted/" \
    && chown -R ${RUN_USER}:${RUN_GROUP} /tmp/mysql_driver_extracted/ \
	&& cp /tmp/mysql_driver_extracted/${JAR_FILE} ${CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/lib/
