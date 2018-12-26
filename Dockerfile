#
# Copyright 2017 StreamSets Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

FROM adoptopenjdk/openjdk8:jdk8u192-b12-alpine
LABEL maintainer="Adam Kunicki <adam@streamsets.com>"

# Note: libidn is required as a workaround for addressing AWS Kinesis Producer issue (https://github.com/awslabs/amazon-kinesis-producer/issues/86)
# nsswitch.conf is based on jeanblanchard's alpine base image and used for configuring DNS resolution priority
RUN apk add --update --no-cache bash \
    curl \
    krb5-libs \
    krb5 \
    libidn \
    libstdc++ \
    libuuid \
    sed \
    sudo && \
    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

# We set a UID/GID for the SDC user because certain test environments require these to be consistent throughout
# the cluster. We use 20159 because it's above the default value of YARN's min.user.id property.
ARG SDC_UID=20159

# Begin Data Collector installation
ARG SDC_VERSION=3.2.0.0-SNAPSHOT
ARG SDC_URL=http://nightly.streamsets.com.s3-us-west-2.amazonaws.com/datacollector/latest/tarball/streamsets-datacollector-core-${SDC_VERSION}.tgz
ARG SDC_USER=sdc
# SDC_HOME is where executables and related files are installed. Used in setup_mapr script.
ARG SDC_HOME="/opt/streamsets-datacollector-${SDC_VERSION}"

# The paths below should generally be attached to a VOLUME for persistence.
# SDC_CONF is where configuration files are stored. This can be shared.
# SDC_DATA is a volume for storing collector state. Do not share this between containers.
# SDC_LOG is an optional volume for file based logs.
# SDC_RESOURCES is where resource files such as runtime:conf resources and Hadoop configuration can be placed.
# STREAMSETS_LIBRARIES_EXTRA_DIR is where extra libraries such as JDBC drivers should go.
# USER_LIBRARIES_DIR is where custom stage libraries are installed.
ENV SDC_CONF=/etc/sdc \
    SDC_DATA=/data \
    SDC_DIST=${SDC_HOME} \
    SDC_HOME=${SDC_HOME} \
    SDC_LOG=/logs \
    SDC_RESOURCES=/resources \
    USER_LIBRARIES_DIR=/opt/streamsets-datacollector-user-libs
ENV STREAMSETS_LIBRARIES_EXTRA_DIR="${SDC_DIST}/streamsets-libs-extras"

# Run the SDC configuration script.
COPY sdc-configure.sh *.tgz /tmp/
RUN /tmp/sdc-configure.sh

# Install any additional stage libraries if requested
ARG SDC_LIBS
RUN if [ -n "${SDC_LIBS}" ]; then "${SDC_DIST}/bin/streamsets" stagelibs -install="${SDC_LIBS}"; fi

# Copy files in $PROJECT_ROOT/resources dir to the SDC_RESOURCES dir.
COPY --chown=sdc:sdc resources/ ${SDC_RESOURCES}/

# Copy local "sdc-extras" libs to STREAMSETS_LIBRARIES_EXTRA_DIR.
# Local files should be placed in appropriate stage lib subdirectories.  For example
# to add a JDBC driver like my-jdbc.jar to the JDBC stage lib, the local file my-jdbc.jar
# should be at the location $PROJECT_ROOT/sdc-extras/streamsets-datacollector-jdbc-lib/lib/my-jdbc.jar
COPY --chown=sdc:sdc sdc-extras/ ${STREAMSETS_LIBRARIES_EXTRA_DIR}/

USER ${SDC_USER}
EXPOSE 18630
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["dc", "-exec"]
