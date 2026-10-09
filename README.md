# RHEL Commandline Assistant Installer #

Installer for the Red Hat Enterprise Linux CLA in a self-managed environment.

### OpenShift Templates ###

OpenShift templates are provided in `openshift/`. The most complex configuration is for Lightspeed Stack, which is the API server.

Create a parameters file then deploy the templates.

```
oc process -f openshift/redhat-okp.yml | oc apply -f -
oc process -f openshift/rhel-knowledge-bridge.yml | oc apply -f -
oc process -f openshift/lightspeed-stack.yml --param-file params | oc apply -f -
```
