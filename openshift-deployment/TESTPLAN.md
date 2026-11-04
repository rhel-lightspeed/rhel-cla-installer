# OpenShift installer test plan (PR #78)

Traceable steps for the PR checkboxes. Run from a **fresh clone** of the PR
branch for each case. Prefer `ansible-playbook` on the checkout (same playbooks
as `./rhel-cla-installer`).

**Branch:** `feature/rhel-cla-operator-k8s`  
**Vars:** `examples/openshift-lab-vars.yml` (PR #8-aligned: `api-key-token`, digests, lab Granite)

```bash
export PR_REMOTE=https://github.com/lmcdasm/rhel-cla-installer.git
export PR_BRANCH=feature/rhel-cla-operator-k8s
export VARS=examples/openshift-lab-vars.yml
export NS=rhel-cla-system
```

---

## 0. Prerequisites

- [ ] `oc login` to the lab cluster; `oc whoami` works
- [ ] `podman`, `ansible-playbook`, `kustomize` on the workstation
- [ ] `kubernetes.core` available to Ansible
- [ ] Lab Granite reachable (default `http://10.20.1.200:8000/v1/models`)
- [ ] Pull + OKP secrets can be seeded (or already present after soft cleanup)

---

## 1. Cluster not provisioned (cleanup)

Soft cleanup (keeps namespace + secrets):

```bash
# From any checkout of the PR branch:
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/operator_uninstall.yml \
  -e @${VARS} || true

ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/k8s_uninstall.yml \
  -e @${VARS}

# Optional helper:
#   openshift-deployment/scripts/lab-cleanup.sh
```

Hard cleanup (empty slate; re-seed secrets after):

```bash
oc delete ns ${NS} rhel-cla-operator-system --wait=true || true
# Re-seed pull + OKP:
#   openshift-deployment/scripts/seed-secrets-from-rhel.sh
```

Verify clean:

```bash
oc get ns ${NS} rhel-cla-operator-system 2>&1 | grep -E 'NotFound|Active' || true
oc -n ${NS} get deploy,route 2>&1 | grep -i 'No resources\|NotFound' || oc -n ${NS} get deploy
```

- [x] Soft or hard cleanup done; no CLA stack deployments (or ns gone)

---

## 2. Case A — native `rhel.cla.k8s` (fresh clone)

```bash
WORKDIR=/tmp/rhel-cla-pr78-k8s
rm -rf "${WORKDIR}"
git clone -b "${PR_BRANCH}" --single-branch "${PR_REMOTE}" "${WORKDIR}"
cd "${WORKDIR}"

# If hard-cleaned, seed secrets first (creates ${NS} as needed).
# openshift-deployment/scripts/seed-secrets-from-rhel.sh

ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/k8s.yml \
  -e @${VARS}

openshift-deployment/scripts/verify.sh
```

Pass when:

- OKP / RKB / Lightspeed pods Ready (OKP may take long for index extract)
- ConfigMap shows `authentication.module: api-key-token`
- Route liveness OK (or noted warm-up)

```bash
oc -n ${NS} get cm lightspeed-stack-config \
  -o jsonpath='{.data.lightspeed-stack\.yml}' | grep -A2 'authentication:'
```

- [x] Case A apply + verify passed

Cleanup before Case B:

```bash
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/k8s_uninstall.yml \
  -e @${VARS}
# or: openshift-deployment/scripts/lab-cleanup.sh
```

- [x] Case A teardown done

---

## 3. Case B — `rhel.cla.operator` build mode (fresh clone)

```bash
WORKDIR=/tmp/rhel-cla-pr78-operator
rm -rf "${WORKDIR}"
git clone -b "${PR_BRANCH}" --single-branch "${PR_REMOTE}" "${WORKDIR}"
cd "${WORKDIR}"

# Secrets must exist in ${NS} (re-seed if hard-cleaned).

ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/operator.yml \
  -e @${VARS}
# default: operator_image_mode=build (podman build operator/Containerfile + push)

openshift-deployment/scripts/verify.sh
oc -n rhel-cla-operator-system get deploy
```

Pass when:

- Operator Deployment Ready
- `RhelCla` CR present; stack converges via same k8s roles
- Auth still `api-key-token`

```bash
oc -n ${NS} get rhelcla
oc -n ${NS} get cm lightspeed-stack-config \
  -o jsonpath='{.data.lightspeed-stack\.yml}' | grep -A2 'authentication:'
```

- [x] Case B apply + verify passed
  - Note: lab used `operator_image_mode=release` + local `podman build` →
    `ghcr.io/dasmlab/rhel-cla-operator:dev` because integrated registry was
    Removed / push flaky; default `build` path still targets cluster registry.

Optional release-mode dry (skip if no published image):

```bash
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/operator.yml \
  -e @${VARS} \
  -e operator_image_mode=release \
  -e operator_image=<pullspec>
```

- [x] Release mode checked or skipped

Teardown:

```bash
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/operator_uninstall.yml \
  -e @${VARS}
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/k8s_uninstall.yml \
  -e @${VARS}
```

- [x] Case B teardown done

---

## 4. Client smoke (optional, either case while stack is up)

```bash
# API key from Secret
oc -n ${NS} get secret lightspeed-stack-api-key \
  -o jsonpath='{.data.API_KEY}' | base64 -d; echo
# Goose / curl Bearer against Route — see README OpenShift auth notes
```

- [ ] Goose or Bearer curl against Route (optional)

---

## Evidence for PR checkboxes

Comment on the PR with:

1. Link to this file on the branch (permalink).
2. Short notes: Case A pass/fail, Case B pass/fail, cleanup done.
3. Optional: paste `oc get deploy,pods -n rhel-cla-system` and auth grep output.
