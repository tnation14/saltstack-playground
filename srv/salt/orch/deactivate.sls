#!py


def run():
    deactivate = __salt__['pillar.get']("deactivate")
    deployment = __salt__['pillar.get']('stacks:{}'.format(deactivate['app_name']))
    try:
        deactivate['version']
    except KeyError:
        return {
            'version_required': {
                'test.fail_without_changes': [
                    {"name": "Image required."}
                ]
            }
        }

    return {
        'deactivate_services': {
            'salt.state': [
              {"tgt": deployment['config']['target']},
              {"tgt_type": __salt__['helpers.get_with_defaults'](
                deployment['config'], 'tgt_type', 'glob')},
              {"sls": "docker-ce"},
              {"pillar": __salt__['helpers.build_docker_pillar'](
                deployment, deactivate, deactivate=True)},
            ]
          }
    }
