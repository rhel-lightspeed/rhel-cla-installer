# RHEL CLA operator

Layout (kept out of the installer repo root):

- `operator/` — Containerfile, PROJECT, watches, kustomize `config/`, optional Makefile
- `collections/.../roles/rhelcla` — reconcile role (`tasks_from` same k8s chain as `rhel.cla.k8s`)
- `collections/.../roles/operator_install` — installer one-shot (`templates/operator/`)

Workload objects still come only from role `templates/k8s/*.j2` (see the
reuse diagram in [`../openshift-deployment/OC-Deployment.md`](../openshift-deployment/OC-Deployment.md)).
The operator does not carry a second copy of those manifests.

| `operator_image_mode` | Behavior |
| --- | --- |
| `build` (default) | `podman build -f operator/Containerfile` → push to cluster registry → deploy |
| `release` | Deploy `operator_image` pullspec (Quay / catalog later) |

```bash
./rhel-cla-installer rhel.cla.operator -e @examples/openshift-lab-vars.yml

./rhel-cla-installer rhel.cla.operator -e @examples/openshift-lab-vars.yml \
  -e operator_image_mode=release \
  -e operator_image=quay.io/example/rhel-cla-operator:1.2.3

./rhel-cla-installer rhel.cla.k8s -e @examples/openshift-lab-vars.yml
```
