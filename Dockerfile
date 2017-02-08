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
MAINTAINER Adam Kunicki <adam@streamsets.com>

RUN apk --no-cache add bash curl sed libstdc++ krb5-libs

ENV SDC_USER=sdc

# ARG is new in Docker 1.9 and not yet supported by Docker Hub Automated Builds
# ARG SDC_VERSION
ENV SDC_VERSION ${SDC_VERSION:-2.4.0.0-SNAPSHOT}

# The paths below should generatelly be attached to a VOLUME for persistence
# SDC_DATA is a volume for storing collector state. Do not share this between containers.
# SDC_LOG is an optional volume for file based logs. You must provide a custom sdc-log4j.properties file to use this.
# SDC_CONF is where configuration files are stored. This can be shared.
# SDC_RESOURCES is where resource files such as runtime:conf resources and Hadoop configuration can be placed.
ENV SDC_DIST="/opt/streamsets-datacollector" \
    SDC_DATA=/data \
    SDC_LOG=/logs \
    SDC_CONF=/etc/sdc \
    SDC_RESOURCES=/resources
# STREAMSETS_LIBRARIES_EXTRA_DIR is where extra libraries such as JDBC drivers should go.
ENV STREAMSETS_LIBRARIES_EXTRA_DIR="${SDC_DIST}/libs-common-lib"

RUN addgroup -S ${SDC_USER} && \
  adduser -S ${SDC_USER} ${SDC_USER}

# Download the SDC tarball, Extract tarball and cleanup
RUN cd /tmp && \
  curl -O -L "http://nightly.streamsets.com.s3-us-west-2.amazonaws.com/datacollector/latest/tarball/streamsets-datacollector-core-${SDC_VERSION}.tgz" && \
  tar xzf "/tmp/streamsets-datacollector-core-${SDC_VERSION}.tgz" -C /opt/ && \
  rm -rf "/tmp/streamsets-datacollector-core-${SDC_VERSION}.tgz" && \
  mv /opt/streamsets-datacollector-${SDC_VERSION} ${SDC_DIST}

# Log to stdout for docker instead of sdc.log for compatibility with docker.
RUN sed -i 's|DEBUG|INFO|' "${SDC_DIST}/etc/sdc-log4j.properties" && \
  sed -i 's|INFO, streamsets|INFO, stdout|' "${SDC_DIST}/etc/sdc-log4j.properties"

# Create data directory and optional mount point
RUN mkdir -p "${SDC_DATA}" /mnt "${SDC_LOG}" "${SDC_RESOURCES}"

# Move configuration to /etc/sdc
RUN mv "${SDC_DIST}/etc" "${SDC_CONF}"

# Don't blacklist Java 8 only stages as this image already includes Java 8
RUN sed -i -E '/^\s+streamsets-datacollector-(apache-solr|elasticsearch)\w+-lib,?\\?/d' "${SDC_CONF}/sdc.properties" && \
  sed -i -r 's/(^\s+streamsets-datacollector-mapr_5_2-lib),\\/\1/' "${SDC_CONF}/sdc.properties"

# Disable authentication by default, overriable with custom sdc.properties.
RUN sed -i 's|\(http.authentication=\).*|\1none|' "${SDC_CONF}/sdc.properties"
# Use short option -s as long option --status is not supported on alpine linux.
RUN sed -i 's|--status|-s|' "${SDC_DIST}/libexec/_stagelibs"

# Setup filesystem permissions
RUN chown -R "${SDC_USER}:${SDC_USER}" "${SDC_DIST}/streamsets-libs" "${SDC_CONF}" "${SDC_DATA}" "${SDC_LOG}" "${SDC_RESOURCES}"

# Disable GC logging by default since there is no log volume
ENV SDC_GC_LOGGING=false

USER ${SDC_USER}
EXPOSE 18630
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["dc", "-exec"]
