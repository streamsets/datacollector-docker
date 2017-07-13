# StreamSets Data Collector

You must accept the [Oracle Binary Code License Agreement for Java SE](http://www.oracle.com/technetwork/java/javase/terms/license/index.html) to use this image.

The Docker image for Data Collector starting from version 2.4.1.0 now uses the form type of file-based authentication by default.
As a result, you must use a Data Collector user account to log in to the Data Collector.
If you haven't set up custom user accounts, you can use the admin account shipped with the Data Collector.
The default login is: admin / admin.
Earlier versions of the Docker image required no authentication.

Basic Usage
-----------
`docker run --restart on-failure -p 18630:18630 -d --name streamsets-dc streamsets/datacollector`

Detailed Usage
--------------
*   You can specify a custom configs by mounting them as a volume to /etc/sdc or /etc/sdc/<specific config>
*   Configuration properties in `sdc.properties` can also be overridden at runtime by specifying them env vars prefixed
    with SDC_CONF
*   For example http.port would be set as SDC_CONF_HTTP_PORT=12345
*   You *should at a minimum* specify a data volume for the data directory and stage libraries. The default configured
    location is /data for $SDC_DATA. You can override this location by passing a different value to the environment
    variable SDC_DATA. Creating a volume for additional stage libraries is described in more detail below.
*   You can also specify your own explicit port mappings, or arguments to the streamsets command.

For example to run with a customized sdc.properties file, a local filsystem path to store pipelines, and statically map
the default UI port you could use the following:

`docker run --restart on-failure -v $PWD/sdc.properties:/etc/sdc/sdc.properties:ro -v $PWD/sdc-data:/data:rw -p 18630:18630 -d streamsets/datacollector dc`

Creating a Data Volumes
-----------------------
To create a dedicated data volume for the pipeline store issue the following command:

`docker volume create --name sdc-data`

You can then use the `-v` (volume) argument to mount it when you start the data collector.

`docker run -v sdc-data:/data -P -d streamsets/datacollector dc`

**Note:** There are two different methods for managing data in Docker. The above is using *data volumes* which are empty
when created. You can also use *data containers* which are derived from an image. These are useful when you want to
modify and persist a path starting with existing files from a base container, such as for configuration files. We'll use
both in the example below. See [Manage data in containers](https://docs.docker.com/engine/tutorials/dockervolumes/) for
more detailed documentation.

Pre-configuring Data Collector
-----------------------------

#### Option 1 - Volumes (Recommended)

First we create a data container for our configuration. We'll call ours `sdc-conf`

`docker create -v /etc/sdc --name sdc-conf streamsets/datacollector`
`docker run --rm -it --volumes-from sdc-conf ubuntu bash`

**Tip:** You can substitute `ubuntu` for your favorite base image. This is only
a temporary container for editing the base configuration files.

Edit the configuration of SDC to your liking by modifying the files in `/etc/sdc`

You can choose to create separate data containers using the above procedure for
`$SDC_DATA` (`/data`) and other locations, or you can add all of the volumes to the
same container. For multiple volumes in a single data container you could use the following syntax:

`docker create -v /etc/sdc -v /data -v --name sdc-volumes streamsets/datacollector`

If you find it easier to edit the configuration files locally you can, instead
of starting the temporary container above, use the `docker cp` command to
copy the configuration files back and forth from the data container.

To install stage libs using the CLI or Package Manager UI you'll need to create a volume for the stage libs directory.
It's also recommended to use a volume for the data directory at a minimum.

`docker volume create --name sdc-stagelibs`
(If you didn't create a data container for `/data` then run the command below)
`docker volume create --name sdc-data`

The volume needs to then be mounted to the correct directory when launching the container. The example below is for
Data Collector version 2.2.1.0.

`docker run --name sdc -d -v sdc-stagelibs:/opt/streamsets-datacollector-2.2.1.0/streamsets-libs -v sdc-data:/data -P streamsets/datacollector dc -verbose`

To get a list of available libs you could do:

`docker run --rm streamsets/datacollector:2.2.1.0 stagelibs -list`

For example, to install the JDBC lib into the sdc-stagelibs volume you created above, you would run:

`docker run --rm -v sdc-stagelibs:/opt/streamsets-datacollector-2.2.1.0/streamsets-libs streamsets/datacollector:2.2.1.0 stagelibs -install=streamsets-datacollector-jdbc-lib`

#### Option 2 - Deriving a new image

One disadvantage of the first method is that we can't commit data in a volume
and distribute it via a docker registry. Instead we must create the volume,
backup the data, restore the data if we need to recreate or move the container
to another host.

This second option will allow us to make modifications to the original base
image, creating a new one which can be pushed to a docker registry and easily
distributed.

The simplest and recommended way is simply to create your own Dockerfile with
the official streamsets/datacollector image as the base! This provides a
repeatable process for building derived images.

For example this derived Dockerfile:

```
FROM streamsets/datacollector:2.2.1.0
# My custom configured sdc.properties
COPY sdc.properties /etc/sdc/sdc.properties
```

`docker build -t mycompany/datacollector:2.2.1.0-abc .`
`docker push mycompany/datacollector:2.2.1.0-abc`

I've now created a new image with a customized sdc.properties file and
am able to distribute it from a docker registry with ease!

You can also launch a default container, modify it while it is running and
use the `docker commit` command, but this isn't recommended.
