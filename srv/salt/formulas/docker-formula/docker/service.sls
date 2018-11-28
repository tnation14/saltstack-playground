# vim: ft=sls
# Manage service for service docker
{%- from "docker/map.jinja" import docker with context %}

'docker-service not configured':
  test.succeed_without_changes

#docker_service:
#  service.running:
#    - name: docker
#    - enable: True
#    - watch:
#        - file: docker_config

