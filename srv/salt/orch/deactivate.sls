{%- set deactivate = salt['pillar.get']("deactivate") %}
{%- set app_name =  deactivate.app_name %}
{% if deactivate.version is defined %}
  {%- set cleanup_image_version = deactivate.version %}
{%- endif %}
{%- set deployment = salt['pillar.get']('stacks:{}'.format(app_name)) %} # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile(i.e., minion ID 'salt' becomes 'salt_master')
{%- if cleanup_image_version is defined %}
{%- set docker_prefix = "{}_{}".format(app_name, cleanup_image_version ) %}
{%- set cleanup_network = "{}_network".format(docker_prefix) %}
{% for service, task_definition in deployment.task_definitions.items() %}
{%- do salt.log.error("image_base: {}".format(task_definition.docker_config.image.split(":")[0])) %}
{%- set container_config = {'image': "{}:{}".format(task_definition.docker_config.image.split(":")[0], cleanup_image_version), 'state': "absent", 'force': True} %}
deactivate_{{ service }}:
  salt.state:
    - tgt: {{ deployment.config.target }}
    - tgt_type: {{ deployment.config.target_type | default("glob")}}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          networks:
            {{ docker_prefix }}_network:
              state: absent
          containers:
          {% for i in range(task_definition.count) %}
            "{{ docker_prefix }}_{{ service }}_{{ i }}":
              {{ container_config | yaml }}
          {% endfor %}
{%- endfor %}
{% else %}
'image_version_required':
  test.fail_without_changes:
    - name: "Image version required"
{%- endif %}
