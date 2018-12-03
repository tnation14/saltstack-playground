{%- from "docker/map.jinja" import docker with context %}

docker_yum_repo:
  pkgrepo.managed:
    - name: "{{ docker.pkg }}"
    - baseurl: "{{ docker.repo_url }}"
    - gpgcheck: 1
    - enabled: 1
    - gpgkey: "{{ docker.key_url }}"
    - require_in:
      - pkg: "{{ docker.pkg }}"
