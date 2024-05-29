# AvantGraph Demo for SciLake
This repository contains a demonstration of the AvantGraph Graph Data Management System, tailored to the context of the [SciLake](https://scilake.eu/) project.

## Getting Started

### A note on compatibility
**We strongly recommend running AvantGraph on an x86-64 Linux host with a kernel version 5.15 or newer**.

AvantGraph is designed to use the Linux-only `io_uring` API.
A compatibility layer is included for systems running on older Linux kernels (<5.15) or macOS.
Use of the compatibility layer will negatively impact performance and stability.

### Pull the docker container
Make sure you have [installed docker](https://docs.docker.com/engine/install/) and that the daemon is [running](https://docs.docker.com/config/daemon/start/).

AvantGraph is published on our GitHub container registry.
For your convenience, we provide an image that contains the OpenAIRE demo graph preloaded.
You can fetch it using the following command:

```bash
docker pull ghcr.io/avantlab/ag-openaire
```

### Start the docker container
Start an instance of the image you have just pulled:

```bash
docker run -it --rm \
    -p 127.0.0.1:7687:7687/tcp \
    --privileged \
    ghcr.io/avantlab/ag-openaire
```

This will open a shell inside the container.
The OpenAIRE graph will be extracted on container startup, so it may take some time before a shell is available.
The `--privileged` flag is necessary for `io_uring` support.

### Run a query using the AvantGraph CLI
The `avantgraph` binary provides the command-line interface to the system.
To run a query, pass the path to the graph, the query type and the path to the query as arguments.
The OpenAIRE demo graph comes preloaded under the `openaire/` directory stored in the user home directory.

A simple query in the Cypher language is available in the container as `lookup.cypher`.
It does a lookup of an entry in the `results` table:

```cypher
MATCH (result:result{id:"50|a21a1b1477ad::93648cc837d3a95091032260ae3aa29e"})
RETURN result
```

We can run it as follows:

```bash
avantgraph openaire/ --query-type=cypher lookup.cypher
```

### Run a query using the BOLT protocol
TODO: describe the BOLT feature.

#### Start AvantGraph in server mode

`ag-server` is the tool to start the local server. The graph repository is required to be specified. The listening host and port are also required.

```bash
ag-server --listen 0.0.0.0:7687 openaire/
```

#### Run a query using Python
You can use the regular `neo4j` Python API to interact with AvantGraph.
If you want to run this locally, ensure the package is installed on your machine:

```bash
# Run this on your local machine
pip3 --user install neo4j
```

An example script `bolt_lookup.py` is provided in this repository.
It connects to AvantGraph using the BOLT protocol, issues a query, and prints the results.

If you prefer not to install the `neo4j` package locally, you can run the same script directly from the docker container.
Open another shell into already-running container:

```bash
# Retrieve the ID of the running container, and open another shell to it.
CONTAINER=$(docker ps -f publish=7687 -q)
docker exec -it $CONTAINER bash -s

# Inside the new shell, run:
python3 bolt_lookup.py
```

It is also possible to use the server with any of the [other Neo4J libraries for various programming languages](https://neo4j.com/docs/create-applications/).

### Running Algorithms
In addition to Cypher queries, AvantGraph also supports the execution of user-defined graph algorithms.
We include an implementation of the [PageRank](https://en.wikipedia.org/wiki/PageRank) algorithm in `pr_openaire.mlir`.
It represents the following GraphAlg program:

```
func withDamping(degree:int, damping:real) -> real {
    return cast<real>(degree) / damping;
}

func PageRank(graph: Matrix<s1, s1, bool>, damping:real, iterations:int) -> Vector<s1, real> {
    n = graph.nrows;
    teleport = (real(1.0) - damping) / cast<real>(n);
    rdiff = real(1.0);

    // out degree
    d_out = reduceRows(cast<int>(graph));

    // L(pj) (out degree with damping)
    d = apply(withDamping, d_out, damping);

    connected = reduceRows(graph);
    sinks = Vector<bool>(n);
    sinks<!connected>[:] = bool(true);

    pr = Vector<real>(n);
    pr[:] = real(1.0) / cast<real>(n);

    for i in int(0):iterations {
        // redistributed from sinks
        sink_pr = Vector<real>(n);
        sink_pr<sinks> = pr;
        redist = (damping / cast<real>(n)) * reduce(sink_pr);

        // importance
        w = pr (./) d;

        pr[:] = teleport + redist;

        // PR(pi;t+1) += \sum_{pj \in M(pi)} PR(pj;t) / L(pj)
        // Where M(pi, pj) = true iff there is an edge.
        pr += cast<real>(graph).T * w;
    }

    return pr;
}
```

GraphAlg is designed to be embedded inside of Cypher queries, but the GraphAlg compiler has not yet been updated to use the new storage layer shipped with the latest AvantGraph release, so we provide a manually constructed execution plan instead.
This plan runs 14 iterations of PageRank over the OpenAIRE citation graph and reports the final score of each vertex.
To execute it, we use the `ag-exec` binary included in the docker image:

```bash
# Run inside the container:
ag-exec openaire/ pr_openaire.mlir
```

### Load the OpenAIRE graph manually
The provided docker image contains a preloaded instance of the OpenAIRE demo graph.
If you wish to replicate it from the original dataset, follow the instructions below.

Get the OpenAIRE graph. AvantGraph has been tested with [v1.0.0](https://doi.org/10.5281/zenodo.7490192).
Create a new local directory and download all parts of the dataset.
With a terminal open in that directory, you should see 9 tar files:

```bash
$ ls
communities_infrastructures.tar  organization.tar          publication.tar
dataset.tar                      otherresearchproduct.tar  relation.tar
datasource.tar                   project.tar               software.tar
```

Extract all tar files:

```bash
for i in *.tar; do tar xvf $i; done
```

Run the provided conversion script, still from the directory containing the tar files:

```bash
<path to scilake-demo>/convert.sh
```

This converts the original JSON structure into a Neo4J dump format that AvantGraph understands.
The script requires the `gzip` and `jq` utilities to be installed.

Start the container and mount the directory that contains the converted graph:

```bash
docker run -it --rm \
    --privileged \
    -v <path to download dir>:/openaire \
    ghcr.io/avantlab/ag-openaire
```

In the container shell, first create the OpenAIRE graph schema:

```bash
./create_openaire_graph.sh my-openaire/
```

Where `my-openaire` is a directory name of your choice.
Finally, run the JSON loader binary to populate the graph:

```bash
ag-load-graph --graph-format=json <(zcat /openaire/ag/mapped/*.json.gz) my_openaire/
```

*note: The loading process can take 30 minutes up to an hour.*
