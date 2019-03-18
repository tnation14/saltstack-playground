deployment:
  loadbal:
    target: minion-debian
    target_type: glob
    frontend: linode.example.com
  config:
    target: minion-debian
    target_type: glob
    formula: mockup
  stacks:
    app:
      count: 1
      docker_config:
        state: running
        start: true
        restart: always
        image: nginx:1.15
        ports: 8080
        binds:
          - "/etc/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf"
        labels:
          - stack=active
        networks:
          - office
