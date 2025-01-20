#
# Copyright contributors to the StreamSets project
# StreamSets Inc., an IBM Company 2024
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

ARG BASE_IMAGE=registry.access.redhat.com/ubi9/openjdk-17-runtime
FROM $BASE_IMAGE

USER 0
RUN microdnf -y upgrade && \
    microdnf install -y \
        httpd-tools \
        hostname \
        krb5-workstation \
        iputils \
        psmisc \
        sudo \
        wget \
        unzip \
        yum \
        && \
    microdnf clean all

ARG JDK_VERSION=17
RUN set -e; \
    if [ $JDK_VERSION = 8 ]; then \
        microdnf install -y java-1.8.0-openjdk-devel; \
        microdnf clean all; \
        alternatives --set java java-1.8.0-openjdk.$(uname -m); \
    fi

# Marker for transition between base image and application image for CVE scanning
ARG LAYER_NAME=application-image

# Accept SHA-1 in TLS trust chains for compatibility
RUN update-crypto-policies --set DEFAULT:SHA1

# OpenShift: Ensure container will have permissions to add custom CA certs at startup, if desired.
RUN if [ -d /etc/pki/ca-trust ]; then \
        chmod -R g+w /etc/pki/ca-trust; \
    fi

# Install traceroute version depending on the architecture of the host
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget https://vault.centos.org/8-stream/BaseOS/x86_64/os/Packages/traceroute-2.1.0-6.el8.x86_64.rpm; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget https://vault.centos.org/8-stream/BaseOS/aarch64/os/Packages/traceroute-2.1.0-6.el8.aarch64.rpm; \
    else \
        echo "Architecture $ARCH is not supported" && exit 1; \
    fi && \
    yum install -y traceroute-2.1.0-6.el8.*.rpm && \
    rm traceroute-2.1.0-6.el8.*.rpm

# Install protobuf-compiler
RUN curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v25.1/protoc-25.1-linux-x86_64.zip && \
    unzip protoc-25.1-linux-x86_64.zip -d $HOME/.local && \
    rm protoc-25.1-linux-x86_64.zip && \
    export PATH="$PATH:$HOME/.local/bin"


# Used for configuring DNS resolution priority
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

# We need to set up GMT as the default timezone to maintain compatibility
RUN ln -sf /usr/share/zoneinfo/GMT /etc/localtime && \
    echo "GMT" > /etc/timezone


# We set a UID/GID for the SDC user because certain test environments require these to be consistent throughout
# the cluster. We use 20159 because it's above the default value of YARN's min.user.id property.
ARG SDC_UID=20159
ARG SDC_GID=20159

# Begin Data Collector installation
ARG SDC_VERSION=6.0.0-SNAPSHOT
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

ENV SDC_JAVA_OPTS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"

# Run the SDC configuration script.
COPY sdc-configure.sh *.tgz /tmp/
RUN /tmp/sdc-configure.sh

# Install any additional stage libraries if requested
ARG SDC_LIBS
RUN if [ -n "${SDC_LIBS}" ]; then "${SDC_DIST}/bin/streamsets" stagelibs -install="${SDC_LIBS}"; fi

# Copy files in $PROJECT_ROOT/resources dir to the SDC_RESOURCES dir.
COPY resources/ ${SDC_RESOURCES}/
RUN chown -R sdc:sdc ${SDC_RESOURCES}/

# Copy local "sdc-extras" libs to STREAMSETS_LIBRARIES_EXTRA_DIR.
# Local files should be placed in appropriate stage lib subdirectories.  For example
# to add a JDBC driver like my-jdbc.jar to the JDBC stage lib, the local file my-jdbc.jar
# should be at the location $PROJECT_ROOT/sdc-extras/streamsets-datacollector-jdbc-lib/lib/my-jdbc.jar
COPY sdc-extras/ ${STREAMSETS_LIBRARIES_EXTRA_DIR}/
RUN chown -R sdc:sdc ${STREAMSETS_LIBRARIES_EXTRA_DIR}/

# Create symlink of custom certs for compatibility between jre and jdk file paths
RUN /bin/bash -c 'if [[ ${JDK_VERSION} =~ ^8 ]]; then ln -snf ${JAVA_HOME}/jre/lib/security ${JAVA_HOME}/lib/security; fi'

# Create Flight libs symlink
RUN sudo ln -s ${SDC_DIST}/flightservice/opt/ibm /opt/ibm

USER ${SDC_USER}
EXPOSE 18630
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["dc"]
