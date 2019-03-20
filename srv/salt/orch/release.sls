# TODO: Error handling
{%- set release = salt['pillar.get']("release") %}
{%- set app_name =  release.app_name %}
{%- set new_image = release.image %}
{%- set deployment = salt['pillar.get']('stacks:{}'.format(app_name)) %} # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile(i.e., minion ID 'salt' becomes 'salt_master')

update_app_config:
  salt.state:
    - tgt: {{ deployment.config.target }}
    {% if deployment.config.target_type is defined %}
    - tgt_type: {{ deployment.config.target_type }}
    {% endif %}
    - sls:
      - {{ deployment.config.formula}}

{% for service, task_definition in deployment.task_definitions.items() %}
{%- set old_image = task_definition.docker_config.image %}
{%- do task_definition.docker_config.labels.append("image=" + new_image) %}
{%- do task_definition.docker_config.update({'image': new_image }) %}

deploy_new_stack:
  salt.state:
    - tgt: {{ deployment.config.target }}
    {% if deployment.config.target_type is defined %}
    - tgt_type: {{ deployment.config.target_type }}
    {% endif %}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(task_definition.count) %}
            "{{ app_name }}_{{ service }}_{{ task_definition.docker_config.image | replace(':', '_') }}-{{ i }}":
              {{ task_definition.docker_config | yaml }}
          {% endfor %}
{%- if "register_backend=true" in task_definition.docker_config.labels %}
update_haproxy:
  salt.state:
    - tgt: {{ deployment.loadbal.target }}
    {% if deployment.loadbal.target_type is defined %}
    - tgt_type: {{ deployment.loadbal.target_type }}
    {% endif %}
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              {{ deployment.loadbal.frontend }}: # Parameterize
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
                    port: {{ deployment.loadbal.backend_port }}
                    filters:
                      label:
                        - register_backend=true
                        - image={{ new_image }} # Parameter
              active:
                http_proxy:
                  docker_local:
                    enabled: True
                    port: {{ deployment.loadbal.backend_port }}
                    filters:
                      label:
                        - register_backend=true
                        - image={{ old_image }} # Pull from pillar
{% endif %}
{% endfor %}
## TODO update pillar after health-check
