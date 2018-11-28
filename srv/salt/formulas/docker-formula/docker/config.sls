# vim: ft=sls
# How to configure docker
{%- from "docker/map.jinja" import docker with context %}

docker_config:
  file.managed:
    - name: '/tmp/config.conf'
    - source: salt://docker/files/config.conf
    - user: root
    - group: root
    - mode: 0600
    - template: jinja
    - local_string: 'test string please ignore'


docker_apt_repo:
  pkgrepo.managed:
    - name: deb [arch={{ salt['grains.get']('osarch') }}] https://download.docker.com/linux/debian {{ salt['grains.get']('oscodename') }} stable
    - key_url: https://download.docker.com/linux/debian/gpg
    - require_in:
      - pkg: "{{ docker.pkg }}"
