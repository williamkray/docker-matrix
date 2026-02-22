Easy Matrix Server
==================

This repo intends to make it easy to launch a Matrix server, and all the resources that go along with that.

Ensure you have created and modified a `host.conf` file to set some basic values, run the `init.sh` script, and you should end up with a reasonably stable, functional group of services:

  * Synapse server with PostgreSQL database
  * Domain delegation (`@user:example.com` usernames, with synapse running at `synapse.example.com`)
  * Working federation with the broader Matrix network
  * Matrix Authentication Service (next-gen true OIDC auth layer)
  * Matrix-RTC (Element-Call) for voice and video calling
  * Element web interface client pre-configured for your Synapse host
  * Traefik for reverse-proxy and TLS termination
  * Maubot for running your own bots!

## Why should I use this?

There are other projects out there, like the Matrix Docker Ansible Deployment, Element Server Suite, etc that can
also deploy a fully functional Synapse + services stack. So why should you use this?

1. No kubernetes required: this uses docker compose for simplified setup and ease of management. Assuming you
   know your way around Docker/containers, this is a flexible starting point to get going.
2. Bare-bones: only the services that are necessary to get a fully-functioning environment for your community. Maubot
   is optional, just to provide a platform to add bots for your community use. Don't use it if you don't want it.
3. Straightforward setup: all config files and persistent storage are in a single directory on-disk so you can find
   what you're looking for if you want to change something.

I strongly encourage you to understand everything this project does so that when you want to expand on the deployment,
you know what all the moving pieces are.

Alternatively, if you want to use this script to just generate some configs for you and drop them into place on another
architecture, or even just read through the init script and replicate the work by hand, go for it! This is really
intended as a "bootstrap" mechanism, so you can feel confident owning the result and administrating your server
as time proceeds.

## Architecture

Important notes about the opinionated deployment strategy:

- Nginx is used to serve your .well-known files for your matrix server, not Synapse. This allows for simplified
  flexibility when adding more things to these files, just update the nginx config file used and restart the nginx
  container.
- Traefik is used as the reverse proxy with LetsEncrypt SSL termination. This allows for all proxy-related routing rules
  to be configured in docker labels on the containers, which makes adding new services that need additional routing
  rules easy to manage. Full documentation on how to use Traefik can be found elsewhere and are outside of the scope
  of this project.
- Default containers used are generally `latest` labels, but for stability it is recommended that you change these in
  your docker-compose.yml to reflect static versions, and upgrade them intentionally. I'm not responsible for your
  auto-update processes breaking everything.
- Database backups are not included, it's up to you to add this. I'm not your mother. I do, however, have plans to
  include a backup and restore process.

> [!NOTE]
> If you deploy testing servers using a domain you want to use in the future, keep in mind that Matrix considers your matrix hostname to be eternal. It is strongly recommended that you not join federated rooms with a testing server that you might change the host name of, and if you do (in order to test federation presumably) that you LEAVE THOSE ROOMS before tearing down your matrix server and losing all your work. Failure to do so may result in mismatched state of those shared rooms, which means you may never be able to log into them ever again. It's weird.

> [!WARNING]
> The `init.sh` script in this repository destructively puts the following files in place:
>   
>   - postgres `init-db.sh`
>   - nginx config
>   - `docker-compose.yml`
>   - more configs in the storage directory!
> 
> If you make changes to any of these files after running `init.sh`, your changes will be lost. This means if you expand
> on this deployment to add things like synapse workers, matrix-media-repo, additional services, etc. and then re-run
> `init.sh` your other services will magically disappear. Either make those changes in the templates used to generate
> these files, or just delete the init.sh script after you run it to be safe!

To Use:
-------

  1. Make some DNS records, and wait a few minutes for them to propagate to the rest of the internet (this isn't
     _strictly_ necessary if you're testing but if you don't use real DNS, you're on your own). Some
     recommendations are (you can change these if you know what you're doing):

  * an A record for `yourdomain.com` that points to the IP address of your server
  * a CNAME record for `app.yourdomain.com` that points to `yourdomain.com` (for Element web client)
  * a CNAME record for `synapse.yourdomain.com` that points to `yourdomain.com` (for the synapse matrix server)
  * a CNAME record for `mas.yourdomain.com` that points to `yourdomain.com` (for the Matrix Authentication Service)
  * a CNAME record for `mrtc.yourdomain.com` that points to `yourdomain.com` (for Matrix-RTC / Element-Call voice and video calling)
  * a CNAME record for `www.yourdomain.com` that points to `yourdomain.com` (optional, if you want to host a static site)
  * a CNAME record for `maubot.yourdomain.com` that points to `yourdomain.com` (for Maubot admin interface)


  2. Copy or rename the file `host.conf.sample` to `host.conf`, modify it as you see fit.

  * `HOSTNAME` and postgres passwords are the most important, the rest can be left as default if you like. If you change any other host
    endpoints, make sure they match whatever DNS records you made above!
  * `REDIRECT_HOST` determines where someone who visits `yourdomain.com` in a browser will be redirected; recommended configuration is either `app.yourdomain.com` to go right to the Element interface, or `www.yourdomain.com` to go to the static website.

  3. execute the `init.sh` script to swap out values in files, generate configs, and prompt you to review the outputted files and run docker compose. N.B. This script will overwrite any files it generates based on the contents of your host.conf!
  4. If you want to host a static site, dump the site files in the `storage/nginx/site` directory
  5. test by visiting yourdomain.com, synapse.yourdomain.com, and app.yourdomain.com (and optionally www.yourdomain.com). if you get SSL certificate errors because Traefik is still serving a self-signed certificate, wait a few more minutes for LetsEncrypt to finish doing its thing.
  6. if everything looks like it's working, use the `register.sh` script to add user accounts. you can alternatively
     enable registration in your MAS config file, located in `storage/mas/data/homeserver.yaml` by default, but
     please note that this exposes you to spam and bad things, and at this time you can only create ADMIN accounts
     for your server via the command line utilities.
  7. At this point I strongly recommend that you go through your Synapse config file, located at
     `./storage/synapse/data/homeserver.yaml` by default, and make your adjustments there. You can also tune your postgresql
     instance as you see fit by modifying its configs. basically everything lives under `./storage` so if you ever need
     to access files or migrate your whole system to another server, you can just run `docker-compose stop` and copy
     your files over to the new system, then run `docker-compose up -d` and it'll be like nothing ever happened
     (assuming you've updated your DNS records to point to the new server).
  8. you can uncomment the maubot section of the docker compose file to launch a maubot instance. keep in mind it will
     require running once to generate a config file, then you should go update it appropriately (this is not automated).
     you can then restart maubot and start adding clients to it. The rest of that configuration is out
     of scope for this project, go read the docs.


Troubleshooting:
----------------

If you are having trouble connecting to some of your containerized services from other containers (e.g. your maubot is
not able to authenticate against your synapse instance) check your iptables rules and/or update UFW rules appropriately
to allow incoming traffic.
