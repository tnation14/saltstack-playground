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
        acls:
          - name: use_office_stack
            condition: src 10.0.2.0/16
            enabled: False
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
            host: example.com
          default_backend: active
    backends:
      active:
        http_proxy:
          balance_algorithm: roundrobin
          docker_local:
            enabled: True
            filters:
              label: "image=latest"
      release:
        http_proxy:
          enabled: False
          balance_algorithm: roundrobin
          docker_local:
            enabled: True
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
