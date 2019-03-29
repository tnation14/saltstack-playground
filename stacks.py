#!/usr/bin/env python
import requests
import argparse
import logging
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.addHandler(logging.StreamHandler())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app-name', action='store',
                        required=True, dest='app_name', help='App to deploy.')
    parser.add_argument('--version', action='store',
                        dest='version', help='Version of app to deploy.')
    parser.add_argument('--action', action='store', dest='action',
                        choices=['release', 'activate', 'deactivate'])
    parser.add_argument('--username', action='store', dest='username',
                        default='saltapi')
    parser.add_argument('--password', action='store', dest='password',
                        default='saltapi1') # TODO switch to getpass
    parser.add_argument('--debug', action='store_true', dest='debug',
                        default=False)

    args = parser.parse_args()
    vars(args)
    if args.debug:
        logger.setLevel(logging.DEBUG)

    session = requests.Session()
    resp = session.post('https://localhost:8000/login',
                        json={
                            'username': args.username,
                            'password': args.password,
                            'eauth': 'pam',
                        }, verify=False)

    logger.debug('Response: {}'.format(resp.text))
    logger.debug('Response: {}'.format(resp.headers))

    pillar = {
                args.action: {
                    'app_name': args.app_name
                }
             }

    logger.debug("Version: {}".format(args.version))
    if args.version is not None:
        pillar[args.action]['version'] = args.version

    resp = session.post('https://localhost:8000', json=[{
                            "client": "runner",
                            "fun": "state.orchestrate",
                            "mods": args.action,
                            "pillar": pillar
                        }], verify=False)
    if resp.status_code == 200:
        salt_results = resp.json()
        if salt_results['return'][0]['retcode'] != 0:
            logger.info("Action %s failed!", args.action)
            logger.info(json.dumps(salt_results, indent=2,
                                   separators=(',', ': ')))
        else:
            logger.info("Action %s succeeded!", args.action)
            logger.debug(json.dumps(salt_results, indent=2,
                                    separators=(',', ': ')))
    else:
        logger.info("Action %s failed with error code %d!",
                    args.action, resp.status_code)
        resp.raise_for_status()


if __name__ == '__main__':
    main()
