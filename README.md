#StreamSets Data Collector

You must accept the [Oracle Binary Code License Agreement for Java SE](http://www.oracle.com/technetwork/java/javase/terms/license/index.html) to use this image.

Basic Usage
-----------
`docker run -p 18630:18630 -d streamsets/datacollector`

Detailed Usage
--------------
* You can specify a custom configs by mounting them as a volume to /etc/sdc or /etc/sdc/<specific config>
* Configuration properties in `sdc.properties` can also be overridden at runtime by specifying them env vars prefixed with SDC_CONF
  * For example http.port would be set as SDC_CONF_HTTP_PORT=12345
* You *should* specify a data volume for your pipelines and pipeline state. The default configured location is /data. You can override this location by passing a different value to the environment variable SDC_DATA
* You can also specify your own explicit port mappings, or arguments to the streamsets command.

For example to run with a customized sdc.properties file, a local filsystem path to store pipelines, and statically map the default UI port you could use the following:

`docker run -v $PWD/sdc.properties:/etc/sdc/sdc.properties:ro -v $PWD/sdc-data:/data:rw -p 18630:18630 -d streamsets/datacollector dc`

Creating a Data Volumes
-----------------------
To create a dedicated data-only container for the pipeline store issue the following command:

`docker create -v /data --name sdc-data streamsets/datacollector:latest`

You can then use the `--volumes-from` argument to mount it when you start the data collector.

`docker run --volumes-from sdc-data -P -d streamsets/datacollector dc`

Preconfiguring Data Collector
-----------------------------

#### Option 1 - Volumes

Create a volume using the process above. We'll call our `sdc-conf`

`docker create -v /etc/sdc --name sdc-conf streamsets/datacollector:latest`
`docker run --rm -it --volumes-from sdc-conf ubuntu bash`

**_Tip:_** You can substitute `ubuntu` for your favorite base image. This is only
a temporary container for editing the base configuration files.

Edit the configuration of SDC to your liking by modifying the files in `/etc/sdc`

You can choose to create separate data containers using the above procedure for
`$SDC_DATA` (`/data`) and other locations, or you can add all of the volumes to the
same container.

If you find it easier to edit the configuration files locally you can, instead
of starting the temporary container above, use the `docker cp` command to
copy the configuration files back and forth from the data container.

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
FROM streamsets/datacollector:1.2.1.0
# My custom configured sdc.properties
COPY sdc.properties /etc/sdc/sdc.properties
```

`docker build -t mycompany/datacollector:1.2.1.0-abc .`
`docker push mycompany/datacollector:1.2.1.0-abc`

I've now created a new image with a customized sdc.properties file and
am able to distribute it from a docker registry with ease!

You can also launch a default container, modify it while it is running and
use the `docker commit` command, but this isn't recommended.
