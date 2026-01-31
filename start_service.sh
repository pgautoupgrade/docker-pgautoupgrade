#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
VOLUME_NAME="pgdata16"
SERVICE_NAME="pgautoupgrade-test"

if [[ -z "${MODE}" ]]; then
    echo "Usage: $0 <test|fix>"
    exit 1
fi

case "${MODE}" in
    test)
        IMAGE_NAME="pgautoupgrade:17-test"
        ;;
    fix)
        IMAGE_NAME="pgautoupgrade:17-fix"
        ;;
    *)
        echo "Invalid mode: ${MODE}"
        echo "Usage: $0 <test|fix>"
        exit 1
        ;;
esac

echo "Starting pgautoupgrade in '${MODE}' mode using image: ${IMAGE_NAME}"

docker service create \
    --name "${SERVICE_NAME}" \
    --mount "type=volume,source=${VOLUME_NAME},target=/var/lib/postgresql/data" \
    --env TEST_BREAKPOINT=1 \
    --detach \
    "${IMAGE_NAME}"

# tooling 
# watch docker service ps pgautoupgrade-test
# docker inspect $(docker ps --filter label=com.docker.swarm.service.name=pgautoupgrade-test --filter status=running --format="{{.ID}}") | jq -r ".[] | .State.Health.Log"