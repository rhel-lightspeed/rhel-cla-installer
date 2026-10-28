# Upgrading #

Upgrading is a two step process that involves downloading the new installer then running it in order to perform the upgrade. The installer upgrades each component as well as the configuration, restarting services as necessary.

1. Download a newer version of the installer container image.

    ```
    export IMAGE=quay.io/redhat-user-workloads/rhel-lightspeed-tenant/rhel-cla-installer:[new tag]
    podman pull "$IMAGE"
    ```

1. Extract the installer from the container image in the directory that contains the `ansible.cfg` and inventory created during initial setup.

    ```
    cd rhel-cla-installer
    podman run --rm -i --entrypoint sh "$IMAGE" -c 'tar -cf - rhel-cla-installer' | tar -xf -
    ```

    Newer versions of the installer may require changes to the provided variables. If desired, extract the example inventory from the new image to see if any variables have changed.

    ```
    podman run --rm -i --entrypoint sh "$IMAGE" -c 'tar -cf - inventory' | tar -xOf - inventory/hosts.yml > inventory/hosts.example.yml
    ```
