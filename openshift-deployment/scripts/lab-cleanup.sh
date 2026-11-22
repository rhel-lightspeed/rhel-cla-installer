#!/usr/bin/env bash
# Soft cleanup of lab CLA stack + operator (keeps namespace + secrets by default).
# Usage:
#   openshift-deployment/scripts/lab-cleanup.sh
#   HARD=1 openshift-deployment/scripts/lab-cleanup.sh   # also delete namespaces
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VARS="${VARS:-${ROOT}/examples/openshift-lab-vars.yml}"
NS="${NS:-rhel-cla-system}"
OPS_NS="${OPS_NS:-rhel-cla-operator-system}"
HARD="${HARD:-0}"

echo "==> Context: $(oc config current-context)"
echo "==> Vars: ${VARS}"

run_pb() {
  local pb="$1"
  if [[ -f "${ROOT}/collections/ansible_collections/rhel/cla/playbooks/${pb}" ]]; then
    echo "==> ansible-playbook ${pb}"
    ansible-playbook -i localhost, -c local \
      "${ROOT}/collections/ansible_collections/rhel/cla/playbooks/${pb}" \
      -e "@${VARS}" || true
  fi
}

run_pb operator_uninstall.yml
run_pb k8s_uninstall.yml

if [[ "${HARD}" == "1" ]]; then
  echo "==> HARD=1 deleting namespaces ${NS} ${OPS_NS}"
  oc delete ns "${NS}" "${OPS_NS}" --wait=true --ignore-not-found=true
else
  echo "==> Soft cleanup done (namespace/secrets retained). HARD=1 to delete namespaces."
fi

echo "==> Remaining in ${NS} (if any):"
oc -n "${NS}" get deploy,route 2>/dev/null || echo "(namespace absent or empty)"
