orch:
  app:
    name_prefix: app
    count: 1
    docker_config:
      state: running
      start: true
      restart: always
      image: nginx:1.14
      ports: 8080
      binds:
        - "/etc/nginx/conf.d/blue.conf:/etc/nginx/conf.d/default.conf"
      labels:
        - stack=active
      networks:
        - office
