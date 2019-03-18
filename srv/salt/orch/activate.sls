{% set app_name = "app" %}
{%- set pillar = salt.saltutil.runner('pillar.show_pillar', kwarg={'minion': 'minion-debian'})['deployment'] %}
{%- set color = "blue" %}

update_app_config:
  salt.state:
    - tgt: {{ pillar['config']['target'] }}
    {% if pillar['config']['target_type'] is defined %}
    - tgt_type: {{ pillar['config']['target_type'] }}
    {% endif %}
    - sls:
      - {{ pillar['config']['formula']}}
    - pillar:
        mockup:
          color: {{ color }}

{# {% do pillar['docker_config'].update(dummy_pillar) %}#}
{% set stack_config = pillar['stacks'][app_name] %}

{%- set old_image = stack_config['docker_config']['image'] %}
{%- set new_image = old_image.split(":")[0] + ":{}".format("1.14") %} # API Parameter
{%- do stack_config['docker_config']['labels'].append("image=" + new_image) %}
{%- do stack_config['docker_config'].update({'image': new_image }) %}

deploy_new_stack:
  salt.state:
    - tgt: {{ pillar['config']['target'] }}
    {% if pillar['config']['target_type'] is defined %}
    - tgt_type: {{ pillar['config']['target_type'] }}
    {% endif %}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(stack_config['count']) %}
            "{{ app_name }}_{{ stack_config['docker_config']['image'] | replace(':', '_') }}-{{ i }}":
              {{ stack_config['docker_config'] | yaml }}
          {% endfor %}

update_haproxy:
  salt.state:
    - tgt: {{ pillar['loadbal']['target'] }}
    - tgt_type: {{ pillar['loadbal']['target_type'] }}
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              {{ pillar['loadbal']['frontend'] }}: # Parameterize
                acls:
                  - name: release_traffic
                    condition: src 10.0.2.0/16 # Eventually, this will be the office IPs
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
                    enabled: True
                    port: {{ stack_config['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ new_image }} # Parameter
              active:
                http_proxy:
                  docker_local:
                    enabled: True
                    port: {{ stack_config['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ old_image }} # Pull from pillar
## TODO update pillar after health-check
