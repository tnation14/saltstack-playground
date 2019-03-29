#!pyobjects

import collections
import logging

log = logging.getLogger(__name__)


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
            labels = task_definition['docker_config']['labels'] or []
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
            ret['containers'][container_id] = task_definition['docker_config']
            log.info("Docker pillar: %s", ret)
    return ret


def build_haproxy_pillar(deployment_config, release_version):
    ret = collections.defaultdict(dict)
    ret['docker_config'] = {
        "networks": [
            deployment_config['loadbal']['default_network']
        ],
        "config": {
            "frontends": {
                deployment_config['loadbal']['frontend']: {
                    "acls": [
                        {
                            "name": "release_traffic",
                            "condition":  "src 10.0.2.0/16"  # Eventually, this will be the office IPs, pulled from pillar
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
                                    "version=" + release_version
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
                                    "version=" + deployment_config['version']
                                ]
                            }
                        }
                    }
                }
            }
        }
    }


def run():
    release = collections.defaultdict(dict)  # Simplifies some of the assignment logic done throughout the rest of this file.  # NOQA E501
    release.update(__salt__['pillar.get']("release"))
    deployment = collections.defaultdict(dict)
    deployment.update(__salt__['pillar.get']('stacks:{}'.format(release['app_name'])))  # You can add pillar to the salt master by appending _master to the master's minion ID in the Topfile # NOQA E501
    release_version = release['version'] or deployment['version']

    minion_tgt_type = deployment['config']['target_type'] or 'glob'

    try:
        loadbal_tgt_type = deployment['loadbal']['target_type']
    except KeyError:
        loadbal_tgt_type = 'glob'

    Saltmod.state(name="update_app_config",
                  tgt=deployment['config']['target'],
                  tgt_type=minion_tgt_type,
                  highstate=True,
                  pillar={'mockup': {'version': release_version}})

    Saltmod.state(name="deploy_services",
                  tgt=deployment['config']['target'],
                  tgt_type=minion_tgt_type,
                  sls='docker-ce',
                  pillar=build_docker_pillar(deployment, release),
                  onsuccess=Saltmod("update_app_config"))

    Saltmod.state(name="update_haproxy",
                  tgt=deployment['loadbal']['target'],
                  tgt_type=loadbal_tgt_type,
                  sls='haproxy',
                  pillar=build_haproxy_pillar(deployment, release_version),
                  onsuccess=Saltmod("deploy_services"))

## TODO update pillar after health-check
