# Ansible-operator / kubebuilder targets. Prefer:
#   ./rhel-cla-installer rhel.cla.operator -e @examples/openshift-lab-vars.yml
# which builds via podman (operator/Containerfile) without invoking this Makefile.
# Run from repo root: make -C operator <target>

VERSION ?= 0.0.1
IMAGE_TAG_BASE ?= redhat.io/rhel-cla-operator
BUNDLE_IMG ?= $(IMAGE_TAG_BASE)-bundle:v$(VERSION)
IMG ?= controller:latest
CONTAINER_TOOL ?= podman
OPERATOR_SDK_VERSION ?= v1.42.3
# Repo root (parent of operator/)
ROOT := $(abspath ..)
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
LOCALBIN ?= $(ROOT)/bin

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make -C operator \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: operator-build
operator-build: ## Build operator image (context = repo root).
	$(CONTAINER_TOOL) build -f $(ROOT)/operator/Containerfile -t ${IMG} $(ROOT)

.PHONY: docker-build
docker-build: operator-build ## Alias for operator-build.

.PHONY: install
install: kustomize ## Install CRDs.
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

.PHONY: uninstall
uninstall: kustomize ## Uninstall CRDs.
	$(KUSTOMIZE) build config/crd | kubectl delete --ignore-not-found=$(ignore-not-found) -f -

.PHONY: deploy
deploy: kustomize ## Deploy controller.
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

.PHONY: undeploy
undeploy: ## Undeploy controller.
	$(KUSTOMIZE) build config/default | kubectl delete --ignore-not-found=$(ignore-not-found) -f -

ifndef ignore-not-found
  ignore-not-found = false
endif

.PHONY: kustomize
KUSTOMIZE = $(LOCALBIN)/kustomize
kustomize: ## Download kustomize if necessary.
ifeq (,$(wildcard $(KUSTOMIZE)))
ifeq (,$(shell which kustomize 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(KUSTOMIZE)) ;\
	curl -sSLo - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.6.0/kustomize_v5.6.0_$(OS)_$(ARCH).tar.gz | \
	tar xzf - -C $(LOCALBIN) ;\
	}
else
KUSTOMIZE = $(shell which kustomize)
endif
endif
