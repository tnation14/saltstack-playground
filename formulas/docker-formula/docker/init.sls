# vim: ft=sls
# Init docker
{%- from "docker/map.jinja" import docker with context %}
{# Below is an example of having a toggle for the state #}

{% if docker.enabled %}
include:
  - docker.install
  - docker.config
  - docker.service
{% else %}
'docker-formula disabled':
  test.succeed_without_changes
{% endif %}

