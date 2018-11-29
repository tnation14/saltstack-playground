{%- from "docker/map.jinja" import docker with context %}

docker_apt_repo:
  pkgrepo.managed:
    - name: deb {{ docker.repo_url }} {{ salt['grains.get']('oscodename') }} {{ docker.component }}
    - key_url: "{{ docker.key_url }}"
    - architecture: "{{ salt['grains.get']('osarch') }}"
    - require_in:
      - pkg: "{{ docker.pkg }}"
