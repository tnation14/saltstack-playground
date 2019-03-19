{% set app_name = "app" %} # Parameter
{%- set deployment = salt['pillar.get']('stacks')[app_name] %} # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile(i.e., minion ID 'salt' becomes 'salt_master')
{%- set color = "blue" %}

update_app_config:
  salt.state:
    - tgt: {{ deployment['config']['target'] }}
    {% if deployment['config']['target_type'] is defined %}
    - tgt_type: {{ deployment['config']['target_type'] }}
    {% endif %}
    - sls:
      - {{ deployment['config']['formula']}}
    - pillar:
        mockup:
          color: {{ color }}

{# {% do deployment['docker_config'].update(dummy_pillar) %}#}
{%- set image_version = "1.14" %}
{%- set old_image = deployment['task_definition']['docker_config']['image'] %}
{%- set new_image = old_image.split(":")[0] + ":{}".format(image_version) %} # API Parameter
{%- do deployment['task_definition']['docker_config']['labels'].append("image=" + new_image) %}
{%- do deployment['task_definition']['docker_config'].update({'image': new_image }) %}

deploy_new_stack:
  salt.state:
    - tgt: {{ deployment['config']['target'] }}
    {% if deployment['config']['target_type'] is defined %}
    - tgt_type: {{ deployment['config']['target_type'] }}
    {% endif %}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(deployment['task_definition']['count']) %}
            "{{ app_name }}_{{ deployment['task_definition']['docker_config']['image'] | replace(':', '_') }}-{{ i }}":
              {{ deployment['task_definition']['docker_config'] | yaml }}
          {% endfor %}

update_haproxy:
  salt.state:
    - tgt: {{ deployment['loadbal']['target'] }}
    {% if deployment['loadbal']['target_type'] is defined %}
    - tgt_type: {{ deployment['loadbal']['target_type'] }}
    {% endif %}
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              {{ deployment['loadbal']['frontend'] }}: # Parameterize
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
                  docker_local:
                    enabled: True
                    port: {{ deployment['task_definition']['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ new_image }} # Parameter
              active:
                http_proxy:
                  docker_local:
                    enabled: True
                    port: {{ deployment['task_definition']['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ old_image }} # Pull from pillar
## TODO update pillar after health-check
