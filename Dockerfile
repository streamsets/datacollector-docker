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

FROM alpine:3.6
MAINTAINER Adam Kunicki <adam@streamsets.com>

# glibc installation courtesy https://github.com/jeanblanchard/docker-alpine-glibc
ENV GLIBC_VERSION 2.25-r0

# Download and install glibc
RUN apk add --update curl && \
  curl -Lo /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub && \
  curl -Lo glibc.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk" && \
  curl -Lo glibc-bin.apk "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk" && \
  apk add glibc-bin.apk glibc.apk && \
  /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib && \
  echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
  apk del curl && \
  rm -rf glibc.apk glibc-bin.apk /var/cache/apk/*

# JRE installation courtesy https://github.com/jeanblanchard/docker-java
# Java Version
ENV JAVA_VERSION_MAJOR 8
ENV JAVA_VERSION_MINOR 131
ENV JAVA_VERSION_BUILD 11
ENV JAVA_PACKAGE       server-jre
ENV JAVA_SHA256_SUM    a80634d17896fe26e432f6c2b589ef6485685b2e717c82cd36f8f747d40ec84b
ENV JAVA_URL_ELEMENT   d54c1d3a095b4ff2b6607d096fa80163

# Download and unarchive Java
RUN apk add --update curl && \
  mkdir -p /opt && \
  curl -jkLH "Cookie: oraclelicense=accept-securebackup-cookie" -o java.tar.gz\
    http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/${JAVA_URL_ELEMENT}/${JAVA_PACKAGE}-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz && \
  echo "$JAVA_SHA256_SUM  java.tar.gz" | sha256sum -c - && \
  gunzip -c java.tar.gz | tar -xf - -C /opt && rm -f java.tar.gz && \
  ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/jdk && \
  curl -jkLH "Cookie: oraclelicense=accept-securebackup-cookie" -o jce_policy-8.zip http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip && \
  unzip jce_policy-8.zip -d /tmp && \
  cp /tmp/UnlimitedJCEPolicyJDK8/*.jar /opt/jdk/jre/lib/security/ && \
  rm -rf jce_policy-8.zip /tmp/UnlimitedJCEPolicyJDK8 && \
  apk del curl && \
  rm -rf /var/cache/apk/*

# Set environment
ENV JAVA_HOME /opt/jdk
ENV PATH ${PATH}:${JAVA_HOME}/bin

# Begin Data Collector installation
ARG SDC_URL=http://nightly.streamsets.com.s3-us-west-2.amazonaws.com/datacollector/latest/tarball/streamsets-datacollector-core-2.5.0.0-SNAPSHOT.tgz
ARG SDC_USER=sdc
ARG SDC_VERSION=2.5.0.0-SNAPSHOT

# We set a UID/GID for the SDC user because certain test environments require these to be consistent throughout
# the cluster. We use 20159 because it's above the default value of YARN's min.user.id property.
ARG SDC_UID=20159

RUN apk --no-cache add bash \
    curl \
    krb5-libs \
    krb5 \
    libstdc++ \
    libuuid \
    sed

# The paths below should generally be attached to a VOLUME for persistence.
# SDC_CONF is where configuration files are stored. This can be shared.
# SDC_DATA is a volume for storing collector state. Do not share this between containers.
# SDC_LOG is an optional volume for file based logs.
# SDC_RESOURCES is where resource files such as runtime:conf resources and Hadoop configuration can be placed.
# STREAMSETS_LIBRARIES_EXTRA_DIR is where extra libraries such as JDBC drivers should go.
ENV SDC_CONF=/etc/sdc \
    SDC_DATA=/data \
    SDC_DIST="/opt/streamsets-datacollector-${SDC_VERSION}" \
    SDC_LOG=/logs \
    SDC_RESOURCES=/resources
ENV STREAMSETS_LIBRARIES_EXTRA_DIR="${SDC_DIST}/streamsets-libs-extras"

RUN addgroup -S -g ${SDC_UID} ${SDC_USER} && \
    adduser -S -u ${SDC_UID} -G ${SDC_USER} ${SDC_USER}

RUN cd /tmp && \
    curl -o /tmp/sdc.tgz -L "${SDC_URL}" && \
    mkdir /opt/streamsets-datacollector-${SDC_VERSION} && \
    tar xzf /tmp/sdc.tgz --strip-components 1 -C /opt/streamsets-datacollector-${SDC_VERSION} && \
    rm -rf /tmp/sdc.tgz

# Add logging to stdout to make logs visible through `docker logs`.
RUN sed -i 's|INFO, streamsets|INFO, streamsets,stdout|' "${SDC_DIST}/etc/sdc-log4j.properties"

# Create necessary directories.
RUN mkdir -p /mnt \
    "${SDC_DATA}" \
    "${SDC_LOG}" \
    "${SDC_RESOURCES}"

# Move configuration to /etc/sdc
RUN mv "${SDC_DIST}/etc" "${SDC_CONF}"

# Use short option -s as long option --status is not supported on alpine linux.
RUN sed -i 's|--status|-s|' "${SDC_DIST}/libexec/_stagelibs"

# Setup filesystem permissions.
RUN chown -R "${SDC_USER}:${SDC_USER}" "${SDC_DIST}/streamsets-libs" \
    "${SDC_CONF}" \
    "${SDC_DATA}" \
    "${SDC_LOG}" \
    "${SDC_RESOURCES}" \
    "${STREAMSETS_LIBRARIES_EXTRA_DIR}"

USER ${SDC_USER}
EXPOSE 18630
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["dc", "-exec"]
