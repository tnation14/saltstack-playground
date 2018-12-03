# vim: ft=yaml
# Custom Pillar Data for docker

docker:
  enabled: true
  daemon_options:
    DOCKER_HOST: '"-H tcp://127.0.0.1:2477 -H unix:///var/run/docker.sock"'
    DOCKER_TLS_VERIFY: "False"
