[comment]: <> (  )
[comment]: <> ( Copyright contributors to the StreamSets project )
[comment]: <> ( StreamSets Inc., an IBM Company 2024 )
[comment]: <> (  )
[comment]: <> ( Licensed under the Apache License, Version 2.0 (the "License"); )
[comment]: <> ( you may not use this file except in compliance with the License. )
[comment]: <> ( You may obtain a copy of the License at )
[comment]: <> (  )
[comment]: <> (     http://www.apache.org/licenses/LICENSE-2.0 )
[comment]: <> (  )
[comment]: <> ( Unless required by applicable law or agreed to in writing, software )
[comment]: <> ( distributed under the License is distributed on an "AS IS" BASIS, )
[comment]: <> ( WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. )
[comment]: <> ( See the License for the specific language governing permissions and )
[comment]: <> ( limitations under the License. )
[comment]: <> (  )

![Data Collector Splash Image](https://raw.githubusercontent.com/streamsets/datacollector/master/datacollector_splash.png)

StreamSets Data Collector allows building dataflows quickly and easily, spanning on-premises, multi-cloud and edge infrastructure.

It has an advanced and easy to use User Interface that allows data scientists, developers and data infrastructure teams easily create data pipelines in a fraction of the time typically required to create complex ingest scenarios.

To learn more, check out [http://streamsets.com](http://streamsets.com)

You must accept the [Oracle Binary Code License Agreement for Java SE](http://www.oracle.com/technetwork/java/javase/terms/license/index.html) to use this image.

### Getting Help

Connect with the [StreamSets Community](https://streamsets.com/community) to discover ways to reach the team.

If you need help with production systems, you can check out the variety of support options offered on our
[support page](http://streamsets.com/support).

### Basic Usage

`docker run --restart on-failure -p 18630:18630 -d --name streamsets-dc streamsets/datacollector`

The default login is: `admin` / `admin`.

### Detailed Usage

* You can specify a custom configs by mounting them as a volume to /etc/sdc or `/etc/sdc/<configuration file>`
* Configuration properties in `sdc.properties` and `dpm.properties` can also be overridden at runtime by specifying them env vars prefixed with `SDC_CONF` or `DPM_CONF`
  * For example `http.port` would be set as SDC_CONF_HTTP_PORT=12345
* You *should at a minimum* specify a data volume for the data directory unless running as a stateless service integrated with [StreamSets Control Hub](https://streamsets.com/products/sch). The default configured location for `SDC_DATA` is `/data`. You can override this location by passing a different value to the environment variable `SDC_DATA`.
* You can also specify your own explicit port mappings, or arguments to the `streamsets` command.
* When building the image yourself, files or directories placed in the "resources" directory at the project root will be copied to the image's  `SDC_RESOURCES` directory.
* When building the image yourself, files or directories placed in the "sdc-extras" directory at the project root will be copied to the image's `STREAMSETS_LIBRARIES_EXTRA_DIR`. See the Dockerfile for details

For example to run with a customized sdc.properties file, a local filsystem path to store pipelines, and statically map the default UI port you could use the following:

`docker run --restart on-failure -v $PWD/sdc.properties:/etc/sdc/sdc.properties:ro -v $PWD/sdc-data:/data:rw -p 18630:18630 -d streamsets/datacollector`

### Creating Data Volumes

To create a dedicated data volume for the pipeline store issue the following command:

`docker volume create --name sdc-data`

You can then use the `-v` (volume) argument to mount it when you start the data collector.

`docker run -v sdc-data:/data -P -d streamsets/datacollector`

**Note:** There are two different methods for managing data in Docker. The above is using *data volumes* which are empty when created. You can also use *data containers* which are derived from an image. These are useful when you want to modify and persist a path starting with existing files from a base container, such as for configuration files. We'll use both in the example below. See [Manage data in containers](https://docs.docker.com/engine/tutorials/dockervolumes/) for more detailed documentation.

### Pre-configuring Data Collector

#### Option 1 - Deriving a new image (Recommended)

The simplest and recommended way is to derive your own custom image.

For example, create a new file named `Dockerfile` with the following contents:

```dockerfile
ARG SDC_VERSION=3.9.1
FROM streamsets/datacollector:${SDC_VERSION}

ARG SDC_LIBS
RUN "${SDC_DIST}/bin/streamsets" stagelibs -install="${SDC_LIBS}"
```

To create a derived image that includes the Jython stage library for SDC version 3.9.1, you can run the following command:

```bash
docker build -t mycompany/datacollector:3.9.1 --build-arg SDC_VERSION=3.9.1 --build-arg SDC_LIBS=streamsets-datacollector-jython_2_7-lib .
```

#### Option 2 - Volumes

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
Data Collector version 
.1.

`docker run --name sdc -d -v sdc-stagelibs:/opt/streamsets-datacollector-3.9.1/streamsets-libs -v sdc-data:/data -P streamsets/datacollector dc -verbose`

To get a list of available libs you could do:

`docker run --rm streamsets/datacollector:3.9.1 stagelibs -list`

For example, to install the JDBC lib into the sdc-stagelibs volume you created above, you would run:

`docker run --rm -v sdc-stagelibs:/opt/streamsets-datacollector-3.9.1/streamsets-libs streamsets/datacollector:3.9.1 stagelibs -install=streamsets-datacollector-jdbc-lib`

