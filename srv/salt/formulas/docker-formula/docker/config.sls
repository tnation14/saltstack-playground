# vim: ft=sls
# How to configure docker
{%- from "docker/map.jinja" import docker with context %}

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


docker_apt_repo:
  pkgrepo.managed:
    - name: deb [arch={{ salt['grains.get']('osarch') }}] https://download.docker.com/linux/debian {{ salt['grains.get']('oscodename') }} stable
    - key_url: https://download.docker.com/linux/debian/gpg
    - require_in:
      - pkg: "{{ docker.pkg }}"
