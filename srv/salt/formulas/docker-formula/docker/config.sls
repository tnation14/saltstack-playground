# vim: ft=sls
# How to configure docker
{%- from "docker/map.jinja" import docker with context %}

include:
  - docker.{{ docker.repo }}

docker_daemon_config:
  file.managed:
    - name: "{{ docker.conf_file_path }}"
    - source: salt://docker/files/config.conf.j2
    - user: root
    - group: root
    - mode: 0600
    - template: jinja
    - require:
      - pkg: "{{ docker.pkg }}"
