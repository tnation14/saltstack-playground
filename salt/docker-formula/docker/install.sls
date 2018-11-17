# vim: ft=sls
# How to install docker
{%- from "docker/map.jinja" import docker with context %}

docker_pkg:
  pkg.installed:
    - name: {{ docker.pkg }}

