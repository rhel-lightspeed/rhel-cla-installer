# RHEL CLA on OpenShift — Ansible notes

OpenShift deploy uses the **same collection interface** as local install:
Jinja templates in each role’s `templates/k8s/`, applied by the
`rhel.cla.k8s` playbook. Do not maintain a parallel static manifest tree.

```bash
# Preferred (self-contained installer)
./rhel-cla-installer rhel.cla.k8s -e @examples/openshift-lab-vars.yml

# Equivalent
ansible-playbook -i localhost, -c local \
  collections/ansible_collections/rhel/cla/playbooks/k8s.yml \
  -e @examples/openshift-lab-vars.yml
```

Preview: add `--check --diff`. Remove: `rhel.cla.k8s_uninstall` with the same
vars file.

See [`collections/ansible_collections/rhel/cla/README.md`](../collections/ansible_collections/rhel/cla/README.md)
for variable flags (`cla_namespace`, `okp_use_pvc`, `rhel_cla_provider`,
`ls_auth_module`, `ls_use_postgres`, …). Lab example enables
`api-key-token` (Bearer) for goose-first OCP use.

## Architecture (what we reuse vs what we leave alone)

```mermaid
flowchart TB
  subgraph before["Before / reference"]
    local["rhel.cla.local<br/>Quadlet / systemd"]
    ocTpl["openshift/*.yml<br/>OpenShift Templates PR8<br/>reference only"]
  end

  subgraph entry["Installer entry same shape as local: inventory or -e @file"]
    cli["rhel-cla-installer / ansible-playbook"]
    k8sPb["rhel.cla.k8s"]
    opPb["rhel.cla.operator"]
  end

  subgraph sot["Source of truth — do not fork"]
    chain["import_role + tasks_from: k8s"]
    j2["roles/*/templates/k8s/*.j2<br/>cla_k8s · okp · rkb · pg · lightspeed_stack"]
    k8sMod["kubernetes.core.k8s"]
  end

  subgraph operatorPath["Operator thin wrap — no second SoT"]
    oi["operator_install<br/>build|release image + CR from same vars"]
    opDir["operator/<br/>Containerfile · watches · kustomize config/"]
    cr["RhelCla CR"]
    rhelcla["role rhelcla<br/>same k8s chain as rhel.cla.k8s"]
  end

  subgraph cluster["OpenShift"]
    ns["rhel-cla-system<br/>OKP · RKB · Lightspeed · Route"]
  end

  local -.->|"semantics folded into j2"| j2
  ocTpl -.->|"params / digests / auth shape"| j2

  cli --> k8sPb
  cli --> opPb
  k8sPb --> chain
  opPb --> oi --> opDir
  oi --> cr --> rhelcla --> chain
  chain --> j2 --> k8sMod --> ns
```

| Layer | Touches | Does not touch |
| --- | --- | --- |
| `templates/k8s/*.j2` + `tasks/k8s.yml` | Workload objects (Deployments, Services, Route, NetPol, …) | Local Quadlet units |
| `rhel.cla.k8s` | Applies SoT directly | Operator CRD / controller |
| `rhel.cla.operator` | Image + RBAC/CRD + `RhelCla`; reconcile re-enters SoT | Parallel manifest tree under `openshift-deployment/` |
| `openshift/` | Reference for AppSRE-shaped params | Preferred install path |
| `openshift-deployment/` | Docs, TESTPLAN, lab helper scripts | Product apply interface |

## Lab profile (optional)

[`examples/openshift-lab-vars.yml`](../examples/openshift-lab-vars.yml) pins
digests and points Lightspeed at external lab Granite
(`http://10.20.1.200:8000/v1`). Adjust for your cluster / provider.

**Prerequisites (not done by the playbook):**

1. `oc` logged into the cluster; `kubernetes.core` available to Ansible
2. Namespace pull secret + OKP access key Secret present

Optional lab-only helpers in this directory (convenience — **not** the install
interface):

| Helper | Purpose |
| --- | --- |
| [`scripts/seed-secrets-from-rhel.sh`](scripts/seed-secrets-from-rhel.sh) | Copy registry auth + OKP key from a Quadlet host into the namespace |
| [`scripts/verify.sh`](scripts/verify.sh) | Quick `oc` / curl checks after apply |
| [`scripts/expose-lab-granite.sh`](scripts/expose-lab-granite.sh) | Lab firewall / PublishPort for host Granite |
| [`examples/command-line-assistant.config.toml.example`](examples/command-line-assistant.config.toml.example) | Point `c` / clad at the Lightspeed Route |

## OKP on OpenShift (in role templates)

| Requirement | Behavior in `okp` k8s templates |
| --- | --- |
| Single pod / RWO | `strategy: Recreate` |
| Long first boot | Long `startupProbe`; `progressDeadlineSeconds: 3600` |
| Restricted SCC unpack | Tar-wrapper ConfigMap + PATH |
| Durable index | PVC when `okp_use_pvc: true` |

## Troubleshooting

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| `ErrImagePull` | Missing pull secret | Seed or create `redhat-pull-secret`; set `cla_pull_secret_name` |
| DNS / MCP timeouts in-cluster | NetworkPolicy blocking DNS | Ensure `cla_network_policies` templates include DNS egress |
| Route chat 504 ~300s | Edge proxy idle timeout | Use port-forward for long lab CPU replies, or raise edge timeout |
| Granite unreachable | Host firewall on `:8000` | Open port or run `expose-lab-granite.sh` |

## Lab test plan

See [`TESTPLAN.md`](TESTPLAN.md) for the PR #78 checkout / cleanup / k8s / operator cases.
