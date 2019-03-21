{% set version = 1.13 %}
{% set web_port = 8080 %}
stacks:
  app:
    version: {{ version }}
    loadbal:
      target: minion-debian
      target_type: glob
      frontend: linode.example.com
      backend_port: {{ web_port }}
      default_network: loadbal
    config:
      target: minion-debian
      target_type: glob
      formula: mockup
    task_definitions:
      web:
        count: 1
        docker_config:
          state: running
          start: true
          restart: always
          image: nginx:{{ version }}
          ports: {{ web_port }}
          binds:
            - "/etc/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf"
          labels:
            - register_backend=true
