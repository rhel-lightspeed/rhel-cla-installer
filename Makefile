##@ Installer

# Run Hermeto locally with the same input the Konflux pipeline uses, to
# validate the prefetch (pip sdists + build deps, the RPM lockfile and the
# galaxy collections). Requires podman; output lands in .hermeto-out/.
HERMETO_IMAGE ?= quay.io/konflux-ci/hermeto:0.62.0
HERMETO_PREFETCH_INPUT = '[{"type":"pip","path":".konflux/pip","requirements_files":["requirements-3.12.txt"],"requirements_build_files":["requirements-tools-3.12.txt","requirements-build-3.12.txt","requirements-build-legacy-3.12.txt"]},{"type":"rpm","path":".konflux/rpms"},{"type":"generic","path":".konflux/artifacts"}]'

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: hermeto-prefetch
hermeto-prefetch: ## Generate a hermeto artifact for testing locally with our artifacts
	rm -rf .hermeto-out
	podman run --rm -v "$(shell pwd):$(shell pwd):z" -w "$(shell pwd)" $(HERMETO_IMAGE) fetch-deps \
		--source . --output ./.hermeto-out $(HERMETO_PREFETCH_INPUT)
	podman run --rm -v "$(shell pwd):$(shell pwd):z" -w "$(shell pwd)" $(HERMETO_IMAGE) generate-env \
		./.hermeto-out -o ./.hermeto-out/cachi2.env --for-output-dir /cachi2/output
	podman run --rm -v "$(shell pwd):$(shell pwd):z" -w "$(shell pwd)" $(HERMETO_IMAGE) inject-files \
		./.hermeto-out --for-output-dir /cachi2/output

RLP_VERSION = 0.30.1
RLP_IMAGE ?= rpm-lockfile-prototype:$(RLP_VERSION)
.PHONY: rpm-lockfile-prototype-image
rpm-lockfile-prototype-image: ## Build the containerized rpm-lockfile-prototype (requires podman).
	curl -s https://raw.githubusercontent.com/konflux-ci/rpm-lockfile-prototype/refs/tags/v$(RLP_VERSION)/Containerfile | \
		podman build -t localhost/$(RLP_IMAGE) -

.PHONY: rpm-lock
rpm-lock: rpm-lockfile-prototype-image ## Regenerate .konflux/rpms/rpms.lock.yaml (requires podman and network access).
	podman run --rm -v "$(shell pwd):/work:z" -w /work $(RLP_IMAGE) .konflux/rpms/rpms.in.yaml --outfile .konflux/rpms/rpms.lock.yaml

.PHONY: artifacts-lock
artifacts-lock: ## Regenerate .konflux/artifacts/artifacts.lock.yaml (requires network access to galaxy.ansible.com).
	python3 scripts/artifacts-lock.py

.PHONY: pip-deps
pip-deps: ## Regenerate the hash-pinned pip requirements in .konflux/pip/ (requires python3.12 and network access).
	python3 scripts/pip-deps.py
