Easy Matrix Server
==================

This repo intends to make it easy to launch a Matrix server, and all the resources that go along with that.

Ensure you have created and modified a `host.conf` file to set some basic values, run the `init.sh` script, and you should end up with a reasonably stable, functional group of services:

  * Synapse server with PostgreSQL database
  * Riot web interface client pre-configured for your Synapse host
  * Traefik for reverse-proxy and TLS termination

To Use:
-------

  1. Make some DNS records:

    * an A record for yourdomain.com that points to the IP address of your server
    * a CNAME record for app.yourdomain.com that points to yourdomain.com (for Riot web client)
    * a CNAME record for synapse.yourdomain.com that points to yourdomain.com (for the synapse matrix server)
    * a CNAME record for www.yourdomain.com that points to yourdomain.com (optional, if you want to host a static site)

  2. Copy the file `templates/host.conf.sample` to the top level directory and name it `host.conf`, modify it as you see fit.

    * HOSTNAME is the most important value, the rest can be left as default if you like
    * REDIRECT_HOST determines where someone who visits `yourdomain.com` in a browser will be redirected; recommended configuration is either app.yourdomain.com to go right to the Riot interface, or www.yourdomain.com to go to the static website.

  3. execute the `init.sh` script to swap out values in files, generate configs, and start docker-compose. N.B. This script will overwrite any files it generates based on the contents of your host.conf!
  4. If you want to host a static site, dump the site files in the `storage/nginx/site` directory
  5. test by visiting yourdomain.com, synapse.yourdomain.com, and app.yourdomain.com (and optionally www.yourdomain.com)
  6. if everything looks like it's working, use the `register.sh` script to add user accounts. you can alternatively enable registration in your synapse config file, located in `storage/synapse/data/homeserver.yaml` by default, but please note that at this time you can only create synapse ADMIN accounts via the commandline.
