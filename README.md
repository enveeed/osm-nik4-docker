# osm-nik4-docker

This container allows you to easily set up an OpenStreetMap PNG renderer using `nik4` given a `.osm` file. It is based on the [Overv's openstreetmap-tile-server](https://github.com/Overv/openstreetmap-tile-server/) and uses the default `openstreetmap-carto` style. This is not a server, it's intended to be run once to render an image.

## Setting up the renderer

First create a Docker volume to hold the PostgreSQL database that will contain the OpenStreetMap data:

    docker volume create openstreetmap-data

Next, create or download an .osm file that you want to render. You can then start importing it into PostgreSQL by running a container and mounting the file as `/data.osm`. For example:

```
docker run \
    -v /absolute/path/to/file.osm:/data.osm \
    -v openstreetmap-data:/var/lib/postgresql/12/main \
    osm-nik4-docker \
    import
```

If the container exits without errors, then your data has been successfully imported and you are now ready to run the renderer.

## Rendering

Run the renderer like this, mounting an output directory as `/output/`:

```
docker run \
    -v /absolute/path/to/output/:/output/ \
    -v openstreetmap-data:/var/lib/postgresql/12/main \
    -d osm-nik4-docker \
    render
```

Your rendered image will now be availaible in `/output/`

## License

```
Copyright 2019 Alexander Overvoorde (Original Author) and
Arthur Schüler (Modifications)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
