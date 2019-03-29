#!py

import logging

log = logging.getLogger(__name__)


def run():
    release = __salt__['pillar.get']("release")
    deployment = __salt__['pillar.get']('stacks:{}'.format(release['app_name']))  # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile # NOQA E501
    release['version'] = __salt__['helpers.get_with_defaults'](
        release, 'version',
        deployment['version'])
    log.debug("release: %s", release)

    return {
      'update_app_config': {
        'salt.state': [
          {"tgt": deployment['config']['target']},
          {"tgt_type": __salt__['helpers.get_with_defaults'](deployment['config'],
                                                             'tgt_type', 'glob')},
          {"sls": "mockup"},
          {"pillar": {'mockup': {'version': release['version']}}}
        ]
      },
      'deploy_services': {
        'salt.state': [
          {"tgt": deployment['config']['target']},
          {"tgt_type": __salt__['helpers.get_with_defaults'](deployment['config'],
                                                             'tgt_type', 'glob')},
          {"sls": "docker-ce"},
          {"pillar": __salt__['helpers.build_docker_pillar'](deployment, release)},
          {"onsuccess": [
                {"salt": "update_app_config"}
            ]
           }
        ]
      },
      'update_haproxy': {
        'salt.state': [
          {"tgt": deployment['loadbal']['target']},
          {"tgt_type": __salt__['helpers.get_with_defaults'](deployment['loadbal'],
                                                             'tgt_type', 'glob')},
          {"sls": "haproxy"},
          {"pillar": __salt__['helpers.build_haproxy_pillar'](deployment,
                                                              release,
                                                              release=True)},
          {"onsuccess": [
                {"salt": "deploy_services"}
            ]
           }
        ]
      }
    }
