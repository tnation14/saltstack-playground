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
    task_definition:
      count: 1
      services:
        web:
          docker_config:
            state: running
            start: true
            restart: always
            image: myapp-nginx:latest
            ports: {{ web_port }}
            binds:
              - "/etc/nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf"
            labels:
              - register_backend=true
        django:
          count: 1
          docker_config:
            state: running
            start: true
            restart: always
            image: myapp:latest
            environment:
              - MYAPP_VERSION={{ version }}
        migrations:
          count: 1
          docker_config:
            state: running
            image: myapp:latest
            command:
              - python
              - manage.py
              - migrate
            environment:
              - MYAPP_VERSION={{ version }}
