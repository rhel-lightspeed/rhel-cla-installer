# ELI5: Ansible operators (for RHEL CLA)

**Audience:** engineers comfortable with Ansible + OpenShift YAML, new to
operators.  
**Goal:** enough vocabulary to join the **design** discussion (and later review
small PRs) without building an operator from scratch first.  
**Now:** skim this, then comment on
[design-openshift-operator.md](design-openshift-operator.md) / epic #78.  
Implementation PRs are paused until that design has buy-in.

---

## The one-sentence version

An **operator** is a program that lives in the cluster, watches a custom object
you define (a **CR**), and repeatedly runs automation (**reconcile**) until the
cluster matches what that object asks for.

For CLA we use an **Ansible operator**: reconcile is literally an Ansible role,
not a big Go controller.

---

## Pieces you already know (mapped)

| You already know | Operator word | In this repo |
| --- | --- | --- |
| Inventory / `-e @vars.yml` describing the desired stack | **Custom Resource (CR)** spec | `RhelCla` object in a namespace |
| Kind/apiVersion for that object | **CRD** | `operator/config/crd/...rhelclas.yaml` |
| `ansible-playbook … import_role … tasks/k8s.yml` | **Reconcile** | Role `rhelcla` → same `tasks_from: k8s` chain |
| “Something changed the vars; run playbooks again” | **Watch / event** | `operator/watches.yaml` |
| Container that runs the playbooks | **Operator Deployment** | Built from `operator/Containerfile` |

```text
You:  oc apply -f my-rhelcla.yaml          (desired state)
        │
        ▼
Operator pod:  "CR changed → run role rhelcla"
        │
        ▼
Same k8s Jinja + kubernetes.core.k8s as rhel.cla.k8s
        │
        ▼
Cluster:  OKP / RKB / Lightspeed Deployments, etc.
```

If you can reason about `rhel.cla.k8s -e @file`, you already understand **what**
reconcile does. The operator only changes **who triggers it** (the controller
loop instead of a human/CI invoking the installer).

---

## Reconcile loop (ELI5)

1. Someone creates or edits a `RhelCla` in a namespace.  
2. The operator notices (watch).  
3. It runs the Ansible role once with the CR fields as vars.  
4. Ansible applies/updates/deletes cluster objects.  
5. If anything drifts or the CR changes again → go to 2.

There is no magic second copy of the stack manifests. **SoT stays**
`roles/*/templates/k8s/*.j2`. The operator is a thin trigger + packaging.

---

## Two install shapes (same SoT)

```text
A) Direct (no operator in the path)
   human → rhel.cla.k8s → templates/k8s → cluster

B) Operator
   human → rhel.cla.operator
            ├─ build/push operator image (or use release pullspec)
            ├─ install operator Deployment + CRD
            └─ apply RhelCla CR
                 └─ operator reconcile → same templates/k8s → cluster
```

**Why B exists:** day-2 (edit CR → stack updates), catalog/OLM later, cluster
native API.  
**Why A exists:** reviewable without learning operators; lab smoke; same Jinja.

---

## What is *not* required to review early PRs

You do **not** need kubebuilder fluency to review:

- Changes under `roles/*/templates/k8s/` (same as reviewing OpenShift YAML)
- `rhel.cla.k8s` playbook wiring
- Auth/probe/NetPol fixes in role defaults

You **do** want a short glossary when reviewing:

- `operator/` layout, `watches.yaml`, CRD schema, `operator_install` one-shot

---

## Tiny glossary

| Term | Meaning |
| --- | --- |
| **CRD** | Schema: “this cluster may store `RhelCla` objects” |
| **CR** | One instance: “in ns X, deploy CLA with these vars” |
| **Watch** | Mapping: which CR kind → which Ansible role |
| **Reconcile** | One Ansible run to converge |
| **ansible-operator** | Upstream runtime that runs those roles in-cluster |
| **build vs release** | Build image in lab vs pull a published image later |

---

## Suggested learning path (after Nov 10)

1. Read this page + the [design doc](design-openshift-operator.md).  
2. Trace **one** successful `rhel.cla.k8s` apply (no operator).  
3. 30‑min show-and-tell: create a toy CRD → watch → role that creates a ConfigMap.  
4. Map that toy onto `RhelCla` → `rhelcla` → `lightspeed_stack` k8s tasks.  
5. Only then: image build / `operator_install` one-shot.

Tutorials and a CLA-specific walkthrough can be scheduled in eng tech sync;
this doc is the shared baseline until then.

---

## Open questions for the team (comment below / on the PR)

1. Do we want **A-first** forever (operator optional), or operator as the
   default OpenShift path within N months?  
2. Who owns day-2 upgrades (bump digests via CR vs re-run installer)?  
3. How much RBAC are we willing to grant the operator SA in shared clusters?
