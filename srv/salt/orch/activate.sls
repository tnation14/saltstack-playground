#!py


def run():
    activate = __salt__['pillar.get']("activate")
    deployment = __salt__['pillar.get']('stacks:{}'.format(activate['app_name']))
    deployment['version'] = __salt__['pigeon.get_with_defaults'](activate, 'version',
                                                                 deployment['version'])
    return {
        'update_haproxy': {
            'salt.state': [
              {"tgt": deployment['loadbal']['target']},
              {"tgt_type": __salt__['pigeon.get_with_defaults'](deployment['loadbal'],
                                                                'tgt_type', 'glob')},
              {"sls": "haproxy"},
              {"pillar": __salt__['pigeon.build_haproxy_pillar'](deployment,
                                                                 activate)},
            ]
          }
    }
