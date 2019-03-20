mockup:
  color: blue

haproxy:
  enabled: True
  version: 1.9
  install_method: docker
  docker_config:
    image: haproxy
    name: haproxy
    networks:
      - office
      - prod
      - loadbal
  config:
    logging:
      'Send logs to stdout':
        location: stdout
        facility: local0
      'Send notice-level logs to stdout':
        location: stdout
        facility: local1
        severity: notice
    frontends:
      linode.example.com:
        http_proxy:
          http:
            port: 80
            redirect: true
          https:
            port: 443
            cert: /etc/ssl/certs/example.com.pem
          healthcheck:
            method: GET
            uri: /healthcheck
            host: linode.example.com
          default_backend: active
    backends:
      active:
        http_proxy:
          balance_algorithm: roundrobin
          servers: {}
          docker_local:
            enabled: False
            filters:
              label: "image=latest"
      release:
        http_proxy:
          enabled: False
          balance_algorithm: roundrobin
          servers: {}
          docker_local:
            enabled: False
            filters:
              label: "image=latest"

docker:
  networks:
    loadbal:
      state: present
      subnet: 10.3.0.0/24
    prod:
      state: present
      subnet: 10.1.0.0/24
    office:
      state: present
      subnet: 10.2.0.0/24
