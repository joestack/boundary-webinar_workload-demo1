# boundary-webinar_workload-demo-01

This repo contains the Boundary use case workload that consumes the Vault and Boundary platform/service(s).

It generates a bunch of webnodes that can be accessed via Boundary based on a static secret (private key)

and..

It generates a bunch of dbnodes that can be accessed via Boundary based on a Vault dynamic secret (SSH CA signing) 


The final workload/demo is stacked upon 3 layers.

1st layer provides the required **platform** environment

2nd layer provides and configure the required **platform/services**

3rd layer provides the the final **workload** and consumes the underlying platform/services
