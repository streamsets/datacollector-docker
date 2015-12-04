#!/bin/bash
# TODO: most, if not all, of this could be done directly in Dockerfile

set -e

# Download the SDC tarball
cd /tmp
curl -O -L https://archives.streamsets.com/datacollector/$SDC_VERSION/tarball/streamsets-datacollector-$SDC_VERSION.tgz
# Download JDBC drivers for PostgresQL
curl -O -L https://jdbc.postgresql.org/download/postgresql-9.4-1206-jdbc42.jar
# Download JDBC drivers for MySQL
curl -O -L http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.37.tar.gz

# Extract tarball and cleanup
tar xzf /tmp/streamsets-datacollector-$SDC_VERSION.tgz -C /opt/
rm -rf /tmp/streamsets-datacollector-*.tgz

# Create the drivers directory
mkdir -p ${SDC_DIST}-extras ${SDC_DIST}-extras/streamsets-datacollector-jdbc-postgresql/lib ${SDC_DIST}-extras/streamsets-datacollector-jdbc-mysql/lib

# Move the postgresql jdbc driver in place
mv /tmp/postgresql-9.4-1206-jdbc42.jar ${SDC_DIST}-extras/streamsets-datacollector-jdbc-postgresql/lib/

# unpack the mysql driver
tar xzf /tmp/mysql-connector-java-5.1.37.tar.gz  -C /tmp/mysql/
mv /tmp/mysql/mysql-connector-java-5.1.37-bin.jar ${SDC_DIST}-extras/streamsets-datacollector-jdbc-mysql/lib/
rm -rf /tmp/mysql
rm /tmp/mysql-connector-java-5.1.37.tar.gz

# Disable authentication by default, overriable with custom sdc.properties.
sed -i 's|\(http.authentication=\).*|\1none|' ${SDC_DIST}/etc/sdc.properties
chown -R sdc:sdc ${SDC_DIST}

# add our directory to the environment
echo "export STREAMSETS_LIBRARIES_EXTRA_DIR=${SDC_DIST}-extras" >> ${SDC_DIST}/libexec/sdc-env.sh

# Log to stdout for docker instead of sdc.log for compatibility with docker.
sed -i 's|DEBUG|INFO|' ${SDC_DIST}/etc/sdc-log4j.properties
sed -i 's|INFO, streamsets|INFO, stdout|' ${SDC_DIST}/etc/sdc-log4j.properties

echo 'grant codebase "file://${SDC_DIST}-extras/-" {' >> ${SDC_DIST}/etc/sdc-security.policy
echo '  permission java.security.AllPermission;'      >> ${SDC_DIST}/etc/sdc-security.policy
echo '};'                                             >> ${SDC_DIST}/etc/sdc-security.policy

# Create data directory and optional mount point
mkdir -p ${SDC_DATA} /mnt ${SDC_LOG}

# Move configuration to /etc/sdc
mv ${SDC_DIST}/etc ${SDC_CONF}

# Setup filesystem permissions
chown ${SDC_USER}:${SDC_USER} ${SDC_DATA} ${SDC_LOG}
