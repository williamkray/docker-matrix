# postgres image has pg_dumpall installed
FROM postgres:17

# Install cron and awscli for pushing to s3
RUN apt update && \
  apt install -y cron awscli && \
  rm -rf /var/lib/apt/lists/*

# Copy the sync script into the container
COPY pgdump.sh /usr/local/sbin/pgdump.sh

# Make the script executable
RUN chmod +x /usr/local/sbin/pgdump.sh

# Define the entrypoint
CMD ["/usr/sbin/cron", "-f"]
