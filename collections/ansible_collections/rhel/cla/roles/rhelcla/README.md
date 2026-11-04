# rhelcla

Watched by the ansible-operator (`operator/watches.yaml`). Maps CR `spec` to
Ansible vars and runs the same `import_role` / `tasks_from: k8s` sequence as
`rhel.cla.k8s`.
