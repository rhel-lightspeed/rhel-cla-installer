# https://github.com/operator-framework/ansible-operator-plugins/blob/main/images/ansible-operator/Dockerfile
FROM quay.io/operator-framework/ansible-operator:v1.42.3@sha256:96053ae3e045c4eb57350cbf1995dece22bf7d3bfe4cf875a20d8853963a3731

ARG VERSION=2.0.0

USER 0
RUN microdnf install -y \
    tar \
    && microdnf clean all \
    && rm -rf /var/cache/dnf

USER ${USER_UID}

ENV PWD $HOME

COPY ansible.cfg ${HOME}/ansible.cfg
COPY requirements/requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY collections/ansible_collections/rhel_lightspeed ${HOME}/collections/ansible_collections/rhel_lightspeed

LABEL konflux.additional-tags=${VERSION}
