# Dockerfiles for StreamSets Data Collector

Version: 1.2.2.0

This is a (very distant) fork of [https://github.com/streamsets/datacollector-docker]
to add some customizations and drivers.

Basic Usage
-----------
`docker run -P -d streamsets/datacollector`

Detailed Usage
--------------
* You can specify a custom configs by mounting them as a volume to /etc/sdc or /etc/sdc/<specific config>
* You *should* specify a data volume for your pipelines and pipeline state. The default configured location is /data. You can override this location by passing a different value to the environment variable SDC_DATA
* You can also specify your own explicit port mappings, or arguments to the streamsets command.

For example to run with a customized sdc.properties file, a local filsystem path to store pipelines, and statically map the default UI port you could use the following:

`docker run -v $PWD/sdc.properties:/etc/sdc/sdc.properties:ro -v $PWD/sdc-data:/data:rw -p 18630:18630 -d streamsets/datacollector dc`

Creating a Data Container
-------------------------
To create a dedicated data-only container for the pipeline store issue the following command:

`docker create -v /data --name sdc-data streamsets/datacollector:latest /bin/true`

You can then use the `--volumes-from` argument to mount it when you start the data collector.

`docker run --volumes-from sdc-data -P -d streamsets/datacollector dc`
