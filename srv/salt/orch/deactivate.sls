{%- set deactivate = salt['pillar.get']("deactivate") %}
{%- set app_name =  deactivate.app_name %}
{%- set cleanup_image_version = deactivate.image | default(None) %}
{%- set deployment = salt['pillar.get']('stacks:{}'.format(app_name)) %} # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile(i.e., minion ID 'salt' becomes 'salt_master')
{%- if cleanup_image_version is defined %}
{% for service, task_definition in deployment.task_definitions.items() %}
{%- set container_config = {'image': task_definition.docker_config.image.split(":")[0] + cleanup_image_version, 'state': "absent", 'force': True} %}
deactivate_old_stack:
  salt.state:
    - tgt: {{ deployment.config.target }}
    - tgt_type: {{ deployment.config.target_type }}
    - sls:
      - 'docker-ce'
    - pillar:
        docker:
          containers:
          {% for i in range(task_definition.count) %}
            "{{ app_name }}_{{ service }}_{{ cleanup_image_version | replace(':', '_') }}-{{ i }}":
              {{ container_config | yaml }}
          {% endfor %}
{%- endfor %}
{% else %}
'image_version_required':
  test.fail_without_changes:
    - name: "Image version required"
{%- endif %}
