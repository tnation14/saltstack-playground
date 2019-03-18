{% set app_name = "app" %}
{%- set pillar = salt.saltutil.runner('pillar.show_pillar', kwarg={'minion': 'minion-debian'})['deployment'] %}
# Get pillar
# Update with user

{% set stack_config = pillar['stacks'][app_name] %}
{%- set old_image = stack_config['docker_config']['image'] %}
{%- set new_image = old_image.split(":")[0] + ":{}".format("1.14") %} # API Parameter
{%- do stack_config['docker_config']['labels'].append("image=" + new_image) %}

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
              {{ pillar['loadbal']['frontend'] }}: # orch.app.name
                http_proxy:
                  default_backend: release
            backends:
              release:
                http_proxy:
                  enabled: true
                  docker_local:
                    enabled: true
                    port: {{ stack_config['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ new_image }} # Parameter

{% set container_config = {'image': old_image, 'state': "absent", 'force': True} %}
deactivate_old_stack:
  salt.state:
    - tgt: {{ pillar['config']['target'] }}
    - tgt_type: {{ pillar['config']['target_type'] }}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(stack_config['count']) %}
            "{{ app_name }}_{{ stack_config['docker_config']['image'] | replace(':', '_') }}-{{ i }}":
              {{ container_config | yaml }}
          {% endfor %}
    - onsuccess:
      - salt: update_haproxy


prune_old_backends:
  salt.state:
    - tgt: minion-debian
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              linode.example.com: # Parameterize
                http_proxy:
                  use_backends: []
                  default_backend: active
            backends:
              active:
                http_proxy:
                  docker_local:
                    enabled: true
                    port: {{ stack_config['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ new_image }}
    - onsuccess:
      - salt: deactivate_old_stack
