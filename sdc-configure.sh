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

# Create SDC user and group.
addgroup -S -g ${SDC_UID} ${SDC_USER}
adduser -S -u ${SDC_UID} -G ${SDC_USER} ${SDC_USER}

# Download and extract SDC.
curl -o /tmp/sdc.tgz -L "${SDC_URL}"
mkdir /opt/streamsets-datacollector-${SDC_VERSION}
tar xzf /tmp/sdc.tgz --strip-components 1 -C /opt/streamsets-datacollector-${SDC_VERSION}
rm -rf /tmp/sdc.tgz

# Add logging to stdout to make logs visible through `docker logs`.
sed -i 's|INFO, streamsets|INFO, streamsets,stdout|' "${SDC_DIST}/etc/sdc-log4j.properties"

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

# Move configuration to /etc/sdc
mv "${SDC_DIST}/etc" "${SDC_CONF}"

# Update sdc-security.policy to include the custom stage library directory.
cat >> "${SDC_CONF}/sdc-security.policy" << EOF

// custom stage library directory
grant codebase "file:///opt/streamsets-datacollector-user-libs/-" {
  permission java.security.AllPermission;
};
EOF

# Use short option -s as long option --status is not supported on alpine linux.
sed -i 's|--status|-s|' "${SDC_DIST}/libexec/_stagelibs"

# Setup filesystem permissions.
chown -R "${SDC_USER}:${SDC_USER}" "${SDC_DIST}/streamsets-libs" \
    "${SDC_CONF}" \
    "${SDC_DATA}" \
    "${SDC_LOG}" \
    "${SDC_RESOURCES}" \
    "${STREAMSETS_LIBRARIES_EXTRA_DIR}" \
    "${USER_LIBRARIES_DIR}"
