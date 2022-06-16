#!/usr/bin/env bash
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
set -e
set -x

# Check if SDC dist already exists, if not create its artifact of things.
if [ ! -d "${SDC_DIST}" ]; then

    # Download and extract SDC.
    for f in /tmp/*.tgz; do
        [ -e "$f" ] && mv "$f" /tmp/sdc.tgz || curl -o /tmp/sdc.tgz -L "${SDC_URL}"
        break
    done

    mkdir "${SDC_DIST}"
    tar xzf /tmp/sdc.tgz --strip-components 1 -C "${SDC_DIST}"
    rm -rf /tmp/sdc.tgz

    # Move configuration to /etc/sdc
    mv "${SDC_DIST}/etc" "${SDC_CONF}"
fi;

# SDC-11575 -- support for arbitrary userIds as per OpenShift
# We use Apache Hadoop code in file system related stagelibs to lookup the
# current user name, which fails when run in OpenShift.
# It fails because containers in OpenShift run as an ephemeral uid for
# security purposes, and that uid does not show up in /etc/passwd.
addgroup --system --gid ${SDC_GID} ${SDC_USER} && \
    adduser --system --disabled-password --uid ${SDC_UID} --gid ${SDC_GID} ${SDC_USER}

addgroup ${SDC_USER} root && \
    chgrp -R 0 "${SDC_DIST}" "${SDC_CONF}"  && \
    chmod -R g=u "${SDC_DIST}" "${SDC_CONF}" && \
    # setgid bit on conf dir to preserve group on sed -i
    chmod g+s "${SDC_CONF}" && \
    chmod g=u /etc/passwd

# Update /etc/sudoers to include SDC user.
echo "${SDC_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Add logging to stdout to make logs visible through `docker logs`.
if [ -f "${SDC_CONF}/sdc-log4j.properties" ]; then
  sed -i 's|INFO, streamsets|INFO, streamsets,stdout|' "${SDC_CONF}/sdc-log4j.properties"
elif [ -f "${SDC_CONF}/sdc-log4j2.properties" ]; then
  sed -i 's|rootLogger.appenderRef.streamsets.ref = streamsets|rootLogger.appenderRef.streamsets.ref = streamsets\nrootLogger.appenderRef.stdout.ref = stdout|' "${SDC_CONF}/sdc-log4j2.properties"
fi

# Workaround to address SDC-8005.
if [ -d "${SDC_DIST}/user-libs" ]; then
  cp -R "${SDC_DIST}/user-libs" "${USER_LIBRARIES_DIR}"
fi

# Create necessary directories.
mkdir -p /mnt \
    "${SDC_DATA}" \
    "${SDC_LOG}" \
    "${SDC_RESOURCES}" \
    "${USER_LIBRARIES_DIR}"

chgrp -R 0 "${SDC_RESOURCES}" "${USER_LIBRARIES_DIR}" "${SDC_LOG}" "${SDC_DATA}" && \
    chmod -R g=u "${SDC_RESOURCES}" "${USER_LIBRARIES_DIR}" "${SDC_LOG}" "${SDC_DATA}"

# Update sdc-security.policy to include the custom stage library directory.
cat >> "${SDC_CONF}/sdc-security.policy" << EOF

// custom stage library directory
grant codebase "file:///opt/streamsets-datacollector-user-libs/-" {
  permission java.security.AllPermission;
};
EOF

# Use short option -s as long option --status is not supported on alpine linux.
sed -i 's|--status|-s|' "${SDC_DIST}/libexec/_stagelibs"

# Set distribution channel variable
sed -i '/^export SDC_DISTRIBUTION_CHANNEL=*/d' "${SDC_DIST}/libexec/sdcd-env.sh"
sed -i '/^export SDC_DISTRIBUTION_CHANNEL=*/d' "${SDC_DIST}/libexec/sdc-env.sh"
echo -e "\nexport SDC_DISTRIBUTION_CHANNEL=docker" >> ${SDC_DIST}/libexec/sdc-env.sh
echo -e "\nexport SDC_DISTRIBUTION_CHANNEL=docker" >> ${SDC_DIST}/libexec/sdcd-env.sh


# Needed for OpenShift deployment
sed -i 's/http.realm.file.permission.check=true/http.realm.file.permission.check=false/' ${SDC_CONF}/sdc.properties

# Create VERSION file
echo "${SDC_VERSION}" > "${SDC_DIST}/VERSION"
