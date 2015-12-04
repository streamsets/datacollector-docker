#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#

FROM jeanblanchard/java:serverjre-8

MAINTAINER Morton Swimmer
EXPOSE 18630

# Default user, overridable via -e option when executing docker run.
ENV SDC_USER=sdc \
    SDC_GROUP=sdc \
    SDC_UID=100 \
    SDC_GID=1000 \
    SDC_VERSION=1.1.3 \
    SDC_DIST=/opt/sdc \
    SDC_DATA=/data \
    SDC_LOG=/logs \
    SDC_CONF=/etc/sdc

RUN apk update && apk add bash curl
RUN addgroup -g ${SDC_GID} -S ${SDC_GROUP} && adduser -u ${SDC_UID} -G ${SDC_GROUP} -S ${SDC_USER}

WORKDIR /tmp
RUN curl -O -L https://archives.streamsets.com/datacollector/$SDC_VERSION/tarball/streamsets-datacollector-$SDC_VERSION.tgz

# Download JDBC drivers for PostgresQL
RUN curl -O -L https://jdbc.postgresql.org/download/postgresql-9.4-1206-jdbc42.jar

# Download JDBC drivers for MySQL
RUN curl -O -L http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.37.tar.gz

# Extract tarball and cleanup
RUN tar xzf /tmp/streamsets-datacollector-$SDC_VERSION.tgz -C /opt/
RUN mv /opt/streamsets-datacollector-$SDC_VERSION ${SDC_DIST}
RUN rm -rf /tmp/streamsets-datacollector-*.tgz

# Create the drivers directory
RUN mkdir -p ${SDC_DIST}-extras ${SDC_DIST}-extras/streamsets-datacollector-jdbc-postgresql/lib ${SDC_DIST}-extras/streamsets-datacollector-jdbc-mysql/lib

# Move the postgresql jdbc driver in place
RUN mv /tmp/postgresql-9.4-1206-jdbc42.jar ${SDC_DIST}-extras/streamsets-datacollector-jdbc-postgresql/lib/

# unpack the mysql driver
RUN tar xzf /tmp/mysql-connector-java-5.1.37.tar.gz  -C /tmp/
RUN mv /tmp/mysql-connector-java-5.1.37/mysql-connector-java-5.1.37-bin.jar ${SDC_DIST}-extras/streamsets-datacollector-jdbc-mysql/lib/
RUN rm -rf /tmp/mysql-connector-java-5.1.37
RUN rm /tmp/mysql-connector-java-5.1.37.tar.gz

# Disable authentication by default, overriable with custom sdc.properties.
RUN sed -i 's|\(http.authentication=\).*|\1none|' ${SDC_DIST}/etc/sdc.properties
RUN chown -R sdc:sdc ${SDC_DIST}

# add our directory to the environment
RUN echo "export STREAMSETS_LIBRARIES_EXTRA_DIR=${SDC_DIST}-extras" >> ${SDC_DIST}/libexec/sdc-env.sh

# Log to stdout for docker instead of sdc.log for compatibility with docker.
RUN sed -i 's|DEBUG|INFO|' ${SDC_DIST}/etc/sdc-log4j.properties
RUN sed -i 's|INFO, streamsets|INFO, stdout|' ${SDC_DIST}/etc/sdc-log4j.properties

RUN echo 'grant codebase "file://${SDC_DIST}-extras/-" {' >> ${SDC_DIST}/etc/sdc-security.policy
RUN echo '  permission java.security.AllPermission;'      >> ${SDC_DIST}/etc/sdc-security.policy
RUN echo '};'                                             >> ${SDC_DIST}/etc/sdc-security.policy

# Create data directory and optional mount point
RUN mkdir -p ${SDC_DATA} /mnt ${SDC_LOG}

# Move configuration to /etc/sdc
RUN mv ${SDC_DIST}/etc ${SDC_CONF}

# Setup filesystem permissions
RUN chown ${SDC_USER}:${SDC_USER} ${SDC_DATA} ${SDC_LOG}

# /mnt is a generic mount point for mounting volumes from other containers or the host
#   such as an input directory for directory spooling.
# SDC_DATA is a volume for storing collector state. Do not share this between collectors.
# SDC_CONF is a olume containing configuration of the data collector. This can be shared.
VOLUME /mnt ${SDC_DATA} ${SDC_CONF}

USER ${SDC_USER}

ENTRYPOINT ["/opt/streamsets-datacollector-1.1.2/bin/streamsets"]
CMD ["dc"]
