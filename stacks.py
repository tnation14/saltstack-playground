#!/usr/bin/env python
import requests
import argparse
import logging

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
logger.addHandler(logging.StreamHandler())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app-name', action='store',
                        required=True, dest='app_name', help='App to deploy.')
    parser.add_argument('--image', action='store',
                        dest='image', help='Version of image to deploy.')
    parser.add_argument('--action', action='store', dest='action',
                        choices=['release', 'activate', 'deactivate'])
    parser.add_argument('--username', action='store', dest='username',
                        default='saltapi')
    parser.add_argument('--password', action='store', dest='password',
                        default='saltapi1')

    args = parser.parse_args()
    vars(args)
    session = requests.Session()
    resp = session.post('https://localhost:8000/login',
                        json={
                            'username': args.username,
                            'password': args.password,
                            'eauth': 'pam',
                        }, verify=False)

    logger.info('Response: {}'.format(resp.text))
    logger.info('Response: {}'.format(resp.headers))

    pillar = {
                args.action: {
                    'app_name': args.app_name
                }
             }
    logger.info("Image: {}".format(args.image))
    if args.image is not None:
        pillar[args.action]['image'] = args.image

    resp = session.post('https://localhost:8000/hook/jenkins/webserver/{}'.format(args.action),
                        json={
                            'action': args.action,
                            'pillar': pillar
                        }, verify=False)
    logger.info('Response: {}'.format(resp.text))


if __name__ == '__main__':
    main()
