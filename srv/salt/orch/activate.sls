{%- set pillar = salt.saltutil.runner('pillar.show_pillar', kwarg={'minion': 'minion-debian'})['orch']['app'] %}
{%- set old_image = pillar['docker_config']['image'] %}
{%- set new_image = "nginx:1.15" %} # Parameter
{%- set binds = ['/etc/nginx/conf.d/blue.conf:/etc/nginx/conf.d/default.conf'] %} # Parameter
{%- set labels = "image=" + new_image %}
{% set dummy_pillar =  {'labels': labels.split(","), 'image': new_image, 'binds': binds} %}

update_app_config:
  salt.state:
    - tgt: minion-debian
    - sls:
      - 'mockup'

{% do pillar['docker_config'].update(dummy_pillar) %}

deploy_new_stack:
  salt.state:
    - tgt: minion-debian
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(pillar['count']) %}
            "{{ pillar['name_prefix'] }}_{{ pillar['docker_config']['image'] | replace(':', '_') }}-{{ i }}":
              {{ pillar['docker_config'] | yaml }}
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
              linode.example.com: # Parameterize
                acls:
                  - name: release_traffic
                    condition: src 10.0.2.0/16
                    enabled: True
                http_proxy:
                  use_backends:
                    - name: release
                      condition: "if release_traffic"
                  default_backend: active
            backends:
              release:
                http_proxy:
                  enabled: true
                  docker_local:
                    port: {{ pillar['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ new_image }} # Parameter
              active:
                http_proxy:
                  docker_local:
                    port: {{ pillar['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ old_image }} # Pull from pillar

## TODO update pillar after health-check
