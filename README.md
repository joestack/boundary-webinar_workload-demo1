# boundary-webinar_workload-demo1

This repo contains the Boundary use case workload that consumes the Vault and Boundary platform.

It generates a bunch of webnodes that can be accessed via Boundary based on a static secret (private key)

and..

It generates a bunch of dbnodes that can be accessed via Boundary based on a Vault dynamic secret (SSH CA signing) 

and..

It generates a bunch of mysql DBs that can be accessed via Boundary based on static credentials.


The final workload/demo is stacked upon 2 layers.

1st layer provides the required **platform** environment (github.com/joestackboundary-webinar_platform-hcp)

2nd layer provides and configure the required **platform/services** and the final **workload** (this repo)
