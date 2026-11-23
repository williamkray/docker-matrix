# synapse_auto_compressor from the official matrix-org image, run nightly by busybox crond.
# It rewrites Synapse's room state history (state_groups_state, usually the largest table) into a
# more compact form. The image tags are commits of github.com/matrix-org/rust-synapse-compress-state.
# To change version: edit the tag, then `docker compose up -d --build synapse-compress-state`.
FROM ghcr.io/matrix-org/rust-synapse-compress-state:REPLACE_WITH_COMPRESSOR_VERSION_TAG

# timezone data, so TZ (and so COMPRESS_SCHEDULE) works; the base image has none
RUN apk add --no-cache tzdata

COPY run-compressor.sh /usr/local/bin/run-compressor.sh

ENV POSTGRES_HOST=database \
    POSTGRES_PORT=5432 \
    POSTGRES_DB=synapse \
    CHUNK_SIZE=500 \
    CHUNKS_TO_COMPRESS=100 \
    COMPRESSION_LEVELS=100,50,25 \
    COMPRESS_SCHEDULE="30 4 * * *"

# Crontab generated at start from COMPRESS_SCHEDULE (cron format, in TZ). Run with `init: true` so the container stops
# immediately (crond ignores SIGTERM as PID 1, which otherwise means a 10s stop timeout).
CMD ["/bin/sh", "-c", "echo \"$COMPRESS_SCHEDULE sh /usr/local/bin/run-compressor.sh > /proc/1/fd/1 2>&1\" > /etc/crontabs/root && exec crond -f -l 8"]
