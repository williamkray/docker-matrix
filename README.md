Easy Matrix Server
==================

This repo intends to make it easy to launch a Matrix server, and all the resources that go along with that.

Ensure you have created and modified a `host.conf` file to set some basic values, run the `init.sh` script, and you should end up with a reasonably stable, functional group of services:

  * Synapse server with PostgreSQL database
  * Matrix Authentication Service (next-gen true OIDC auth layer)
  * Element web interface client pre-configured for your Synapse host
  * Traefik for reverse-proxy and TLS termination
  * Maubot for running your own bots!

#### DANGER! WARNING! DANGER!

If you deploy testing servers using a domain you want to use in the future, keep in mind that Matrix considers your matrix hostname to be eternal. It is strongly recommended that you not join federated rooms with a testing server that you might change the host name of, and if you do (in order to test federation presumably) that you LEAVE THOSE ROOMS before tearing down your matrix server and losing all your work. Failure to do so may result in mismatched state of those shared rooms, which means you may never be able to log into them ever again. It's weird.

#### WARNING DANGER WARNING

The `init.sh` script in this repository destructively puts the following files in place:
  
  - postgres `init-db.sh`
  - nginx config
  - `docker-compose.yml`

If you make changes to any of these files after running `init.sh`, your changes will be lost. This means if you expand
on this deployment to add things like synapse workers, matrix-media-repo, additional services, etc. and then re-run
`init.sh` your other services will magically disappear. Either make those changes in the templates used to generate
these files, or just delete the init.sh script after you run it to be safe!

To Use:
-------

  1. Make some DNS records, and wait a few minutes for them to propagate to the rest of the internet:

  * an A record for yourdomain.com that points to the IP address of your server
  * a CNAME record for app.yourdomain.com that points to yourdomain.com (for Element web client)
  * a CNAME record for synapse.yourdomain.com that points to yourdomain.com (for the synapse matrix server)
  * a CNAME record for mas.yourdomain.com that points to yourdomain.com (for the Matrix Authentication Service)
  * a CNAME record for mrtc.yourdomain.com that points to yourdomain.com (for Matrix-RTC / Element-Call voice and video calling)
  * a CNAME record for www.yourdomain.com that points to yourdomain.com (optional, if you want to host a static site)
  * a CNAME record for maubot.yourdomain.com that points to yourdomain.com (for Maubot admin interface)

  **NOTE: This is not strictly required for testing scenarios, but without DNS records pointing to your stuff you will need to understand the networking components of traefik and Docker to troubleshoot. You may also want to change which Lets Encrypt endpoint you are trying to fetch certs from so you don't spam their production service and get blocked because your server cannot be reached. You're on your own for any of this stuff.**

  2. Copy or rename the file `host.conf.sample` to `host.conf`, modify it as you see fit.

  * HOSTNAME is the most important value, the rest can be left as default if you like
  * REDIRECT_HOST determines where someone who visits `yourdomain.com` in a browser will be redirected; recommended configuration is either app.yourdomain.com to go right to the Element interface, or www.yourdomain.com to go to the static website.

  3. execute the `init.sh` script to swap out values in files, generate configs, and start docker-compose. N.B. This script will overwrite any files it generates based on the contents of your host.conf!
  4. If you want to host a static site, dump the site files in the `storage/nginx/site` directory
  5. test by visiting yourdomain.com, synapse.yourdomain.com, and app.yourdomain.com (and optionally www.yourdomain.com)
  6. if everything looks like it's working, use the `register.sh` script to add user accounts. you can alternatively enable registration in your synapse config file, located in `storage/synapse/data/homeserver.yaml` by default, but please note that at this time you can only create synapse ADMIN accounts via the commandline.
  7. At this point I strongly recommend that you go through your Synapse config file, located at
     `./storage/synapse/data/homeserver.yaml` and make your adjustments there. You can also tune your postgresql
     instance as you see fit by modifying its configs. basically everything lives under `./storage` so if you ever need
     to access files or migrate your whole system to another server, you can just run `docker-compose stop` and copy
     your files over to the new system, then run `docker-compose up -d` and it'll be like nothing ever happened
     (assuming you've updated your DNS records to point to the new server).
  8. you can uncomment the maubot section of the docker compose file to launch a maubot instance. keep in mind it will
     require running once to generate a config file, then you should go update it appropriately (this is not automated).
     you can then restart maubot and start adding clients to it.


Troubleshooting:
----------------

If you are having trouble connecting to some of your containerized services from other containers (e.g. your maubot is
not able to authenticate against your synapse instance) check your iptables rules and/or update UFW rules appropriately
to allow incoming traffic.
