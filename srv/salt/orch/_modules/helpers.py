#!/usr/bin/env python

import logging

log = logging.getLogger(__name__)

def get_with_defaults(dictionary, key, default):
    try:
        return dictionary[key]
    except KeyError:
        return default


def build_docker_pillar(deployment, overrides, deactivate=False):

    docker_prefix = "{}_{}_".format(overrides['app_name'],
                                    overrides['version'])
    ret = {
        "docker": {
            "networks": {
                deployment['loadbal']['default_network']: {
                    "state": "present"  # We always want the loadbal network
                }
            },
            "containers": {}
        }

    }
    for i in range(deployment['task_definition']['count']):
        network_name = docker_prefix + "network_{}".format(i)

        ret['docker']['networks'][network_name] = {
            "state": "absent" if deactivate else "present"
        }

        for service, service_definition in deployment['task_definition']['services'].items():

            labels = get_with_defaults(service_definition['docker_config'],
                                       'labels', [])
            labels.append("version={}".format(overrides['version']))
            service_definition['docker_config'].update({
                'labels': labels,
                'image': "{}:{}".format(service_definition['docker_config']['image'].split(":")[0],
                                        overrides['version']),
                'networks': [
                                deployment['loadbal']['default_network'],
                                {
                                    network_name: [
                                        {'aliases': [service]}
                                    ]
                                }
                            ],
                }
            )

            if deactivate:
                service_definition['docker_config'].update({
                    "state": "absent",
                    "force": True
                    })

            container_id = "{}{}_{}".format(docker_prefix, service, i)
            ret['docker']['containers'][container_id] = service_definition['docker_config']
    return ret


def build_haproxy_pillar(deployment, overrides, release=False):
    ret = {"haproxy": {}}
    ret['haproxy']['docker_config'] = {
        "networks": [
            deployment['loadbal']['default_network']
        ]}
    ret['haproxy']['config'] = {
            "backends": {
                "active": {
                    "http_proxy": {
                        "docker_local": {
                            "enabled": True,
                            "port": deployment['loadbal']['backend_port'],
                            "filters": {
                                "label": [
                                    "register_backend=true",
                                    "version={}".format(deployment['version'])
                                ]
                            }
                        }
                    }
                }
            }
        }

    if release:
        ret['haproxy']['config'].update({
            "frontends": {
                deployment['loadbal']['frontend']: {
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
            }
        })

        ret['haproxy']['config']['backends']['release'] = {
               "http_proxy": {
                   "docker_local": {
                       "enabled": True,
                       "port": deployment['loadbal']['backend_port'],
                       "filters": {
                           "label": [
                               "register_backend=true",
                               "version={}".format(overrides['version'])
                           ]
                       }
                   }
               }
           }

    log.error("Haproxy Pillar: %s", ret)
    return ret
