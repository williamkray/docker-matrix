Easy Matrix Server
==================

This repo intends to make it easy to launch a Matrix server, and all the resources that go along with that.

Ensure you have created and modified a `host.conf` file to set some basic values, run the `init.sh` script, and you should end up with a reasonably stable, functional group of services:

  * Synapse server with PostgreSQL database
  * Riot web interface client pre-configured for your Synapse host
  * Traefik for reverse-proxy and TLS termination

To Use:
-------

  1. Make two DNS records:

    * an A record for yourdomain.com that points to the IP address of your server
    * a CNAME record for app.yourdomain.com that points to yourdomain.com

  2. Copy the file `templates/host.conf.sample` to the top level directory and name it `host.conf`, modify it as you see fit.
  3. execute the `init.sh` script to swap out values in files, generate configs, and start docker-compose
  4. test by visiting yourdomain.com and app.yourdomain.com
  5. if everything looks like it's working, use the `register.sh` script to add user accounts. you can alternatively enable registration in your synapse config file, located in `storage/synapse/data/homeserver.yaml` by default.
