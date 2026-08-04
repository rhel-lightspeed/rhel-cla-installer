# https://github.com/operator-framework/ansible-operator-plugins/blob/main/images/ansible-operator/Dockerfile
FROM quay.io/operator-framework/ansible-operator:v1.42.3

COPY ansible.cfg ${HOME}/ansible.cfg
COPY requirements/requirements.yml ${HOME}/requirements.yml
RUN ansible-galaxy collection install -r ${HOME}/requirements.yml \
 && chmod -R ug+rwx ${HOME}/.ansible

COPY watches.yaml ${HOME}/watches.yaml
COPY collections/ansible_collections/rhel_lightspeed ${HOME}/collections/ansible_collections/rhel_lightspeed
