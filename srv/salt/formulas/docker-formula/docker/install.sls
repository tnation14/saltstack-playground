# vim: ft=sls
# How to install docker
{%- from "docker/map.jinja" import docker with context %}

docker_deps:
  pkg.installed:
    - pkgs: "{{ docker.pkg_deps | yaml }}"
    - require_in:
      - pkg: "{{ docker.pkg }}"

docker_pkg:
  pkg.installed:
    - name: "{{ docker.pkg }}"
    - require:
      - sls: "docker.{{ docker.repo }}"
