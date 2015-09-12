#!/bin/bash

# Download the SDC tarball
cd /tmp
curl -O -L https://s3-us-west-1.amazonaws.com/download.streamsets.com/datacollector/1.1.0/tarball/streamsets-datacollector-1.1.0.tgz

# Extract tarball and cleanup
tar xzf /tmp/streamsets-datacollector-1.1.0.tgz -C /opt/
rm -rf /tmp/streamsets-datacollector-*.tgz

# Disable authentication by default, overriable with custom sdc.properties.
sed -i 's|\(http.authentication=\).*|\1none|' ${SDC_DIST}/etc/sdc.properties
chown -R sdc:sdc ${SDC_DIST}

# Log to stdout for docker instead of sdc.log for compatibility with docker.
sed -i 's|DEBUG|INFO|' ${SDC_DIST}/etc/sdc-log4j.properties
sed -i 's|INFO, streamsets|INFO, stdout|' ${SDC_DIST}/etc/sdc-log4j.properties

# Create data directory and optional mount point
mkdir -p ${SDC_DATA} /mnt ${SDC_LOG}

# Move configuration to /etc/sdc
mv ${SDC_DIST}/etc ${SDC_CONF}

# Setup filesystem permissions
chown ${SDC_USER}:${SDC_USER} ${SDC_DATA} ${SDC_LOG}
