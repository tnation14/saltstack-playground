{%- set pillar = salt.saltutil.runner('pillar.show_pillar', kwarg={'minion': 'salt'})['orch']['app']['docker_config'] %}
{% set new_version = 1.14 %}
{% set binds = ['/etc/nginx/conf.d/green.conf:/etc/nginx/conf.d/default.conf'] %}


update_app_config:
  salt.state:
    - tgt: minion-debian
    - sls:
      - 'mockup'

deploy_new_stack:
  salt.state:
    - tgt: minion-debian
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(pillar['count']) %}
            {{ pillar['name_prefix'] }}_{{ pillar['image'] }}-release-{{ i }}:
              state: running
              force: true
              start: true
              restart: always
              ports: {{ pillar['port'] }}
              image: {{ pillar['image'] }}:{{ new_version }}
              labels:
                - stack=release
              networks:
                - office
              binds:
                {%- for bind in binds %}
                - {{ bind }}
                {%- endfor %}
          {% endfor %}

update_haproxy:
  salt.state:
    - tgt: minion-debian
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              linode.example.com:
                acls:
                  - name: release_traffic
                    condition: src 10.0.2.0/16
                    enabled: True
                http_proxy:
                  use_backends:
                    - name: release
                      condition: "if release_traffic"
