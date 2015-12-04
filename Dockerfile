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

ADD install.sh /tmp/
RUN /tmp/install.sh

# /mnt is a generic mount point for mounting volumes from other containers or the host
#   such as an input directory for directory spooling.
# SDC_DATA is a volume for storing collector state. Do not share this between collectors.
# SDC_CONF is a olume containing configuration of the data collector. This can be shared.
VOLUME /mnt ${SDC_DATA} ${SDC_CONF}

USER ${SDC_USER}

ENTRYPOINT ["/opt/streamsets-datacollector-1.1.2/bin/streamsets"]
CMD ["dc"]
