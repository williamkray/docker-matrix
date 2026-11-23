#!/bin/sh
# One synapse_auto_compressor pass over the synapse DB (env: POSTGRES_*, CHUNK_SIZE,
# CHUNKS_TO_COMPRESS, COMPRESSION_LEVELS). Same behaviour as the old tcpipuk entrypoint, minus its
# optional automatic table-dropping recovery (it was off here and needs psql).
echo "$(date -Is) compressor starting (chunk size $CHUNK_SIZE, $CHUNKS_TO_COMPRESS chunks, levels $COMPRESSION_LEVELS)"
synapse_auto_compressor \
  -p "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB" \
  -c "$CHUNK_SIZE" -n "$CHUNKS_TO_COMPRESS" -l "$COMPRESSION_LEVELS"
rc=$?
case $rc in
  0) echo "$(date -Is) compressor finished normally" ;;
  101) echo "$(date -Is) compressor error (101). If recovery is needed, drop state_compressor_progress, state_compressor_state and state_compressor_total_progress in the synapse DB." ;;
  137) echo "$(date -Is) compressor killed (137), likely memory; lower CHUNK_SIZE or CHUNKS_TO_COMPRESS." ;;
  *) echo "$(date -Is) compressor exited with $rc" ;;
esac
exit $rc
