#!/bin/bash

echo "adding group ${SDC_GROUP} with gid ${SDC_GID}"
addgroup -g ${SDC_GID} -S ${SDC_GROUP}

echo "adding user ${SDC_USER} with uid ${SDC_UID} to group ${SDC_GROUP}"
adduser -u ${SDC_UID} -G ${SDC_GROUP} -S ${SDC_USER}

echo "Owning the SDC distribution"
chown -R ${SDC_USER}:${SDC_GROUP} ${SDC_DIST}

# Setup filesystem permissions
chown ${SDC_USER}:${SDC_GROUP} ${SDC_DATA} ${SDC_LOG}

# change to our new shiny user
su - ${SDC_USER}

#exec "$@"
exec /opt/sdc/bin/streamsets dc

