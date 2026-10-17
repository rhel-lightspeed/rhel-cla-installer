# Red Hat Enterprise Linux Command Line Assistant Installer #

This is the installer for the self-managed RHEL CLA. It supports local, remote installations. OpenShift support is stil in development.

## Prerequisites ##

- Python 3.11 or later
- [`podman`]
- A [Red Hat Offline Knowledge Portal key][rhokp_key]
- 30GB of free disk space for the Red Hat Offline Knowledge Portal.
- Valid container registry login credentials in `/etc/containers/auth.json`.
- If using a provider that requires a credentials stored in a file, create the secret in `podman`.

Create the container registry required login credentials. This needs to be done on both local and remote systems, or the auth file can be generated once and copied to remote systems.

```
sudo podman login --authfile /etc/containers/auth.json registry.redhat.io
```

If necessary for your inference provider, create a `podman` secret.

```
sudo podman secrete create [secret name] [path to file]
```

Set the secret name in the inventory variables for our provider.
```yaml
ls_providers:
  vertex:
    project_id: my_project
    location: global
    credentials_secret_name: vertex
```


## Local Installation ##

1. Extract the installer from the container image in order to run it against `localhost`.

    ```
    ./scripts/extract.sh
    ```

    This will extract the installer from the container into a single executable to a `local` directory.

    If any errors are encountered when extracting the installer, run `bash -s scripts/extract.sh` to see more verbose output.

    It is possible to override `IMAGE` and `CONTAINER_RUNTIME` if needed.

    ```
    CONTAINER_RUNTIME=docker ./scripts/extract.sh
    ```

1. Configure inventory.

    Make a copy of the example inventory file and fill in the required variables.

    ```
    mkdir local/inventory
    cp inventory/hosts.example.yml local/inventory/hosts.yml
    ```

    For local installation, no host definitions are necessary.

1. Run the installer.

    ```
    cd local
    ./rhel-cla-installer rhel.cla.local
    ```

    Adjust verbosity by adding `-v`. More v's give more verbosity.

### Verify Installation ###

Check the pod and container status.

```
sudo systemctl status rhel-cla-pod.service
sudo systemctl status rhel-knowledge-bridge.service
sudo systemctl status rh-offline-knowledge-portal.service
sudo systemctl status lightspeed-stack.service
```

### Uninstall ###

Run `./rhel-cla-installer rhel.cla.uninstall_local`.


[`podman`]: https://podman.io/
[rhokp_key]: https://access.redhat.com/offline/access/
