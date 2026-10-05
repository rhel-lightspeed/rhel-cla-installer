# Run RHEL CLA on Kubernetes

The direct Kubernetes entry point is `collections/ansible_collections/rhel_lightspeed/cla/playbooks/k8s.yml`. It deploys the Offline Knowledge Portal, Knowledge Bridge, and Lightspeed Stack into the namespace supplied through `ansible_operator_meta.namespace` (default: `rhel-cla`). The `config/` directory is an unfinished Ansible Operator scaffold: `watches.yaml` has no watches, and there is no custom resource to install.

## Local cluster

Install [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) and `kubectl`. With Podman, start a local cluster:

```sh
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name rhel-cla --wait 5m
kubectl cluster-info --context kind-rhel-cla
```

Rootless Podman may need the host setup described in the [kind rootless guide](https://kind.sigs.k8s.io/docs/user/rootless/). An existing Kubernetes cluster works too; select its `kubectl` context before continuing.

## Deploy

From the repository root, install Ansible and the Kubernetes Python client in a virtual environment, then install the pinned Ansible collections:

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements/requirements.in kubernetes
.venv/bin/ansible-galaxy collection install -r requirements/requirements.yml -p collections
kubectl create namespace rhel-cla
.venv/bin/ansible-playbook collections/ansible_collections/rhel_lightspeed/cla/playbooks/k8s.yml \
  -e rkb_solr_url=http://YOUR-SOLR-SERVICE:8983
kubectl -n rhel-cla rollout status deployment/rhel-knowledge-bridge
kubectl -n rhel-cla port-forward service/rhel-knowledge-bridge 8000:8000
```

The Solr URL must resolve from inside the cluster. The repository does not deploy Solr; its default URL is `http://redhat-okp:8983`. The bridge image is `registry.redhat.io/rhel-cla/rhel-knowledge-bridge-rhel10:v1.0.2-1785450151`. Ensure your cluster can pull it. If authentication is required, create an image pull secret in `rhel-cla` and attach it to the `rhel-knowledge-bridge` ServiceAccount. Check `kubectl -n rhel-cla describe pod` for pull or startup errors.

To target another namespace, create it first and override `ansible_operator_meta`, for example `-e '{"ansible_operator_meta":{"namespace":"my-project"}}'`.

## OpenShift

The same playbook targets OpenShift after `oc login` and `oc new-project rhel-cla`; `oc` provides the Kubernetes API connection used by Ansible. Set `-e ls_create_route=true` to create the OpenShift Route; it is disabled by default because Routes are not supported by vanilla Kubernetes. For a local OpenShift cluster, use [OpenShift Local](https://developers.redhat.com/products/openshift-local) (`crc setup`, then `crc start`). An OpenShift project may also need a pull secret for the Red Hat registry image. Verify that the image starts under the project's default security context constraints; the image's arbitrary UID compatibility has not been verified here.

## Deploy to an ephemeral Bonfire namespace

From the repository root, log in to the OpenShift cluster with `oc` and make sure Bonfire is configured. The `.env` file should contain the Lightspeed Stack settings, including non-empty `DEFAULT_MODEL` and `DEFAULT_PROVIDER` values. You can re-use the `.env.example` file from the [lscore-deploy](https://gitlab.cee.redhat.com/rhel-lightspeed/enhanced-shell/lscore-deploy/-/blob/c6d81e558b7a001d9a7465978232a20782720695/local/.env.example) repository. It must be shell-compatible. Source it with automatic export so Ansible can pass its values into the pod:

```sh
oc login --web --server=https://api.crc-eph.r9lp.p1.openshiftapps.com:6443
export NAMESPACE="$(bonfire namespace reserve)"

set -a
source .env
set +a
```

The namespace must also contain the `vertexai` Secret with a `credentials_json` key and the `rls-lscore-db` Secret with `db.host`, `db.port`, `db.name`, `db.user`, and `db.password` keys.For that you need to run the postgresql template from [score-deploy](https://gitlab.cee.redhat.com/rhel-lightspeed/enhanced-shell/lscore-deploy/-/blob/main/openshift/postgresql.yml?ref_type=heads). Sentry is optional; Splunk is disabled in this deployment.

Run the Kubernetes playbook in that namespace:

```sh
# Run this from lscore-deploy directory
oc process -f openshift/postgresql.yml | oc apply -f -

# Run this from rhel-cla-installer directory
ansible-playbook -i localhost, \
  collections/ansible_collections/rhel_lightspeed/cla/playbooks/k8s.yml \
  -e "{\"ansible_operator_meta\":{\"namespace\":\"${NAMESPACE:?}\"}}" \
  -e ls_create_route=true
```

If you installed Ansible into the repository's virtual environment, use `.venv/bin/ansible-playbook` in place of `ansible-playbook`.

Check that the workloads are ready:

```sh
oc -n "$NAMESPACE" get deployments,pods
oc -n "$NAMESPACE" rollout status deployment/lightspeed-stack
```

Get the Lightspeed Stack route hostname:

```sh
export ROUTE="$(oc -n "$NAMESPACE" get routes lightspeed-stack \
  -o go-template='{{ .spec.host }}')"
```

Send a simple Responses API request. `X_RH_IDENTITY` must contain a valid RH Identity token. The endpoint is `/v1/responses`:

```sh
curl --request POST \
  --header "X-RH-IDENTITY: ${X_RH_IDENTITY}" \
  --header "Content-Type: application/json" \
  --data '{"input":"hi"}' \
  "https://${ROUTE}/api/lightspeed/v1/responses"
```
