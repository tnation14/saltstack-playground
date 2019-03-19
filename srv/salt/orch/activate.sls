{% set app_name = "app" %} # Parameter
{%- set deployment = salt.saltutil.runner('pillar.show_pillar', kwarg={'minion': 'minion-debian'})['stacks'][app_name] %} # TODO should this be master pillar?? Come from request?

# Get pillar
# Update with user
{%- set cleanup_image_version = "1.15" %}

{% if cleanup_image_version %}
{%- set active_image = deployment['task_definition']['docker_config']['image'] %}
{%- set cleanup_image = active_image.split(":")[0] + ":{}".format(cleanup_image_version) %}

prune_old_backends:
  salt.state:
    - tgt: minion-debian
    - sls:
      - haproxy
    - pillar:
        haproxy:
          config:
            frontends:
              {{ deployment['loadbal']['frontend'] }}: # Parameterize
                http_proxy:
                  use_backends: []
                  default_backend: active
            backends:
              active:
                http_proxy:
                  docker_local:
                    enabled: true
                    port: {{ deployment['task_definition']['docker_config']['ports'] }}
                    filters:
                      label:
                        - image={{ active_image }}


{% set container_config = {'image': cleanup_image, 'state': "absent", 'force': True} %}
deactivate_old_stack:
  salt.state:
    - tgt: {{ deployment['config']['target'] }}
    - tgt_type: {{ deployment['config']['target_type'] }}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(deployment['task_definition']['count']) %}
            "{{ app_name }}_{{ cleanup_image | replace(':', '_') }}-{{ i }}":
              {{ container_config | yaml }}
          {% endfor %}
    - onsuccess:
      - salt: prune_old_backends
{% else %}
'image_version_required':
  test.fail_without_changes:
    - name: "Image version required"
{%- endif %}
