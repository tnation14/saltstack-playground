#!py

import collections
import logging

log = logging.getLogger(__name__)


def _get_with_defaults(dictionary, key, default):
    try:
        return dictionary[key]
    except KeyError:
        return default

def build_docker_pillar(deployment, release):
    docker_prefix = "{}_{}_".format(release['app_name'], release['version'])
    ret = {
        "docker": {
            "networks": {},
            "containers": {}
        }

    }
    for i in range(deployment['task_definition']['count']):
        network_name = docker_prefix + "network_{}".format(i)
        ret['docker']['networks'][network_name] = {"state": "present"}

        for service, task_definition in deployment['task_definition']['services'].items():
            release_image = "{}:{}".format(task_definition['docker_config']['image'].split(":")[0], release['version'])

            labels = _get_with_defaults(task_definition['docker_config'],
                                        'labels', [])
            log.info("version: %s", release['version'])
            labels.append("version={}".format(release['version']))
            task_definition['docker_config']['labels'] = labels
            task_definition['docker_config']['image'] = release_image
            task_definition['docker_config']['networks'] = [
                deployment['loadbal']['default_network'],
                {
                    network_name: [
                        {'aliases': [service]}
                    ]
                }
            ]
            container_id = "{}{}_{}".format(docker_prefix, service, i)
            ret['docker']['containers'][container_id] = task_definition['docker_config']
            log.info("Docker pillar: %s", ret)
    return ret


def build_haproxy_pillar(deployment_config, release_version):
    ret = {"haproxy": {}}
    ret['haproxy']['docker_config'] = {
        "networks": [
            deployment_config['loadbal']['default_network']
        ]}
    ret['haproxy']['config'] = {
            "frontends": {
                deployment_config['loadbal']['frontend']: {
                    "acls": [
                        {
                            "name": "release_traffic",
                            "condition":  "src 10.0.2.0/16",  # Eventually, this will be the office IPs, pulled from pillar
                            "enabled": True
                        }
                    ],
                    "http_proxy": {
                        "use_backends": [
                            {
                                "name": "release",
                                "condition": "if release_traffic"
                            }
                        ],
                        "default_backend": "active"
                    }

                }
            },
            "backends": {
                "release": {
                    "http_proxy": {
                        "docker_local": {
                            "enabled": True,
                            "port": deployment_config['loadbal']['backend_port'],
                            "filters": {
                                "label": [
                                    "register_backend=true",
                                    "version={}".format(release_version)
                                ]
                            }
                        }
                    }
                },
                "active": {
                    "http_proxy": {
                        "docker_local": {
                            "enabled": True,
                            "port": deployment_config['loadbal']['backend_port'],
                            "filters": {
                                "label": [
                                    "register_backend=true",
                                    "version={}".format(deployment_config['version'])
                                ]
                            }
                        }
                    }
                }
            }
        }
    log.info("haproxy_pillar: %s", ret)
    return ret


def run():
    release = __salt__['pillar.get']("release")
    deployment = __salt__['pillar.get']('stacks:{}'.format(release['app_name']))  # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile # NOQA E501
    release_version = _get_with_defaults(release, 'version',
                                         deployment['version'])
    release['version'] = release_version

    return {
      'update_app_config': {
        'salt.state': [
          {"tgt": deployment['config']['target']},
          {"tgt_type": _get_with_defaults(deployment['config'],
                                          'tgt_type', 'glob')},
          {"highstate": True},
          {"pillar": {'mockup': {'version': release['version']}}}
        ]
      },
      'deploy_services': {
        'salt.state': [
          {"tgt": deployment['config']['target']},
          {"tgt_type": _get_with_defaults(deployment['config'],
                                          'tgt_type', 'glob')},
          {"sls": "docker-ce"},
          {"pillar": build_docker_pillar(deployment, release)},
          {"onsuccess": [
                {"salt": "update_app_config"}
            ]
           }
        ]
      },
      'update_haproxy': {
        'salt.state': [
          {"tgt": deployment['loadbal']['target']},
          {"tgt_type": _get_with_defaults(deployment['loadbal'],
                                          'tgt_type', 'glob')},
          {"sls": "haproxy"},
          {"pillar": build_haproxy_pillar(deployment, release['version'])},
          {"onsuccess": [
                {"salt": "deploy_services"}
            ]
           }
        ]
      }
    }
