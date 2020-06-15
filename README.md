Easy Matrix Server
==================

This repo intends to make it easy to launch a Matrix server, and all the resources that go along with that.

Ensure you have created and modified a `host.conf` file to set some basic values, run the `init.sh` script, and you should end up with a reasonably stable, functional group of services:

  * Synapse server with PostgreSQL database
  * Riot web interface client pre-configured for your Synapse host
  * Traefik for reverse-proxy and TLS termination
