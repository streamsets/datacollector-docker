#!/bin/bash
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

set -e

# Support for custom CA certificates, when present in the base image.
if [[ -x /__cacert_entrypoint.sh ]]; then
  # ubuntu / eclipse-temurin
  if [[ -n "${CUSTOM_TRUSTSTORE_CA_CERT:-}" ]]; then
    mkdir -p /certificates
    printf '%s' "${CUSTOM_TRUSTSTORE_CA_CERT}" >/certificates/ca-cert.crt
    USE_SYSTEM_CA_CERTS=1 /__cacert_entrypoint.sh
  else
    /__cacert_entrypoint.sh
  fi
elif command -v update-ca-trust >/dev/null; then
  # redhat ubi
  if [[ -n "${CUSTOM_TRUSTSTORE_CA_CERT:-}" ]]; then
    printf '%s' "${CUSTOM_TRUSTSTORE_CA_CERT}" >/etc/pki/ca-trust/source/anchors/ca-cert.crt
    update-ca-trust extract --output /etc/pki/ca-trust/custom \
      && mv /etc/pki/ca-trust/extracted /etc/pki/ca-trust/extracted~ \
      && mv /etc/pki/ca-trust/custom /etc/pki/ca-trust/extracted
  fi
fi

# We translate environment variables to sdc.properties and rewrite them.
set_conf() {
  if [ $# -ne 2 ]; then
    echo "set_conf requires two arguments: <key> <value>"
    exit 1
  fi

  if [ -z "$SDC_CONF" ]; then
    echo "SDC_CONF is not set."
    exit 1
  fi

  grep -q "^$1" ${SDC_CONF}/sdc.properties && sed 's|^#\?\('"$1"'=\).*|\1'"$2"'|' -i ${SDC_CONF}/sdc.properties || echo -e "\n$1=$2" >> ${SDC_CONF}/sdc.properties
}

# support arbitrary user IDs
# ref: https://docs.openshift.com/container-platform/3.3/creating_images/guidelines.html#openshift-container-platform-specific-guidelines
if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${SDC_USER:-sdc}:x:$(id -u):0:${SDC_USER:-sdc} user:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi

# In some environments such as Marathon $HOST and $PORT0 can be used to
# determine the correct external URL to reach SDC.
if [ ! -z "$HOST" ] && [ ! -z "$PORT0" ] && [ -z "$SDC_CONF_SDC_BASE_HTTP_URL" ]; then
  export SDC_CONF_SDC_BASE_HTTP_URL="http://${HOST}:${PORT0}"
fi

for e in $(env); do
  key=${e%=*}
  value=${e#*=}
  if [[ $key == SDC_CONF_* ]]; then
    lowercase=$(echo $key | tr '[:upper:]' '[:lower:]')
    key=$(echo ${lowercase#*sdc_conf_} | sed 's|_|.|g')
    set_conf $key $value
  fi
done

exec "${SDC_DIST}/bin/streamsets" "$@"
