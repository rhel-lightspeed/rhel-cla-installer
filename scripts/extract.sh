#!/bin/bash

set -eu

CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-$(command -v podman || command -v docker)}
if [[ -z "$CONTAINER_RUNTIME" ]]; then
    echo "Error: neither podman nor docker is available; set CONTAINER_RUNTIME explicitly." >&2
    exit 1
fi

echo "Starting build container..."
IMAGE=${IMAGE:-quay.io/redhat-user-workloads/rhel-lightspeed-tenant/rhel-cla-installer:latest}
CONTAINER=$("$CONTAINER_RUNTIME" run --rm -d -u root --entrypoint tail "$IMAGE" -f /dev/null)
trap '"$CONTAINER_RUNTIME" stop "$CONTAINER" > /dev/null 2>&1 || true' EXIT

"$CONTAINER_RUNTIME" exec -u root "$CONTAINER" microdnf -y install tar > /dev/null 2>&1

# Install shiv
echo "Installing build tools..."
"$CONTAINER_RUNTIME" exec "$CONTAINER" python3 -m venv --upgrade-deps .venvs/tools > /dev/null 2>&1
"$CONTAINER_RUNTIME" exec "$CONTAINER" .venvs/tools/bin/pip install shiv > /dev/null 2>&1

# Add collections to site-packages and build zipapp.
echo "Building zipapp..."
"$CONTAINER_RUNTIME" exec "$CONTAINER" cp -Ra collections/ansible_collections /usr/local/lib/python3.12/site-packages/
"$CONTAINER_RUNTIME" exec "$CONTAINER" .venvs/tools/bin/shiv \
    --site-packages /usr/local/lib/python3.12/site-packages \
    --console-script ansible-playbook \
    --output-file rhel-cla-installer

# Copy the zipapp and config to container host
if [[ ! -d local ]]; then
    mkdir local
fi

if [[ -f local/rhel-cla-install ]]; then
    rm -f local/rhel-cla-install
fi

"$CONTAINER_RUNTIME" exec "$CONTAINER" tar -cf - rhel-cla-installer | tar -C local -xf -

if [[ ! -f local/ansible.cfg ]]; then
    "$CONTAINER_RUNTIME" exec "$CONTAINER" tar -cf - ansible.cfg | tar -C local -xf -
fi

echo "Installer extracted to rhel-cla-installer."
