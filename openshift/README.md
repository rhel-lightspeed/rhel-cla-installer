# OpenShift Templates (reference)

Static `Template` objects from PR #8. **Not** the preferred install path.

New installs use role Jinja under `collections/.../roles/*/templates/k8s/` via:

```bash
./rhel-cla-installer rhel.cla.k8s -e @examples/openshift-lab-vars.yml
# or
./rhel-cla-installer rhel.cla.operator -e @examples/openshift-lab-vars.yml
```

Keep these files for production-shaped parameter examples (Vertex, Postgres
Secret keys, digests). Do not add a second live manifest tree beside the k8s
SoT. See [`../openshift-deployment/OC-Deployment.md`](../openshift-deployment/OC-Deployment.md).
