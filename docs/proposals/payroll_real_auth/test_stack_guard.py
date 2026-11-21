"""Offline synthetic guard tests only; no Docker, HTTP or DB access."""
import copy
import unittest
import stack_guard as guard


def fixture():
    return {'Id': 'a' * 64, 'Image': 'sha256:' + 'b' * 64, 'State': {'Running': True},
            'Config': {'Image': guard.POSTGRES, 'Labels': {'payroll.auth.run': '123-1'},
                       'Env': ['POSTGRES_DB=payroll_auth_fixture','POSTGRES_PASSWORD=synthetic-only']},
            'HostConfig': {'Privileged': False, 'Binds': None, 'PortBindings': None,
                           'NetworkMode': 'github_network_fixture',
                           'Tmpfs': {'/var/lib/postgresql/data': 'rw'}},
            'Mounts': []}


class GuardTests(unittest.TestCase):
    def test_environment_requires_job_and_exact_container_id(self):
        env = {'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted',
               'GITHUB_REPOSITORY':'kanta13jp1/my_web_app','GITHUB_JOB':'synthetic-auth-envoy',
               'GITHUB_EVENT_NAME':'pull_request','GITHUB_RUN_ID':'123','GITHUB_RUN_ATTEMPT':'1',
               'FIXTURE_DB_CONTAINER_ID':'a'*64}
        self.assertEqual(guard.job_identity(env), ('a'*64, '123-1'))
        for key in env:
            bad = dict(env); bad[key] = '../bad'
            with self.subTest(key=key), self.assertRaises(RuntimeError): guard.job_identity(bad)

    def test_database_rejects_foreign_and_exposed_containers(self):
        good = fixture()
        self.assertTrue(guard.container_ok(good, 'a'*64, 'sha256:'+'b'*64, guard.POSTGRES, '123-1', db=True))
        for change in ('id','image','label','bind','port','network','tmpfs','volume','env'):
            value=copy.deepcopy(good)
            if change=='id': value['Id']='x'*64
            if change=='image': value['Config']['Image']='postgres:latest'
            if change=='label': value['Config']['Labels']['payroll.auth.run']='other'
            if change=='bind': value['HostConfig']['Binds']=['/private:/data']
            if change=='port': value['HostConfig']['PortBindings']={'5432/tcp':[]}
            if change=='network': value['HostConfig']['NetworkMode']='host'
            if change=='tmpfs': value['HostConfig']['Tmpfs']={}
            if change=='volume': value['Mounts']=[{'Type':'volume','Destination':'/data'}]
            if change=='env': value['Config']['Env']=[]
            with self.subTest(change=change):
                self.assertFalse(guard.container_ok(value,'a'*64,'sha256:'+'b'*64,guard.POSTGRES,'123-1',db=True))

    def test_internal_network_identity_and_exclusive_membership(self):
        network={'Id':'c'*64,'Internal':True,'Labels':{'payroll.auth.run':'123-1'}}
        self.assertTrue(guard.network_ok(network,'c'*64,'123-1'))
        network['Internal']=False
        self.assertFalse(guard.network_ok(network,'c'*64,'123-1'))
        info={'NetworkSettings':{'Networks':{'fixture':{'NetworkID':'c'*64}}}}
        self.assertTrue(guard.member_of_only(info,'fixture','c'*64))
        info['NetworkSettings']['Networks']['external']={'NetworkID':'d'*64}
        self.assertFalse(guard.member_of_only(info,'fixture','c'*64))


if __name__ == '__main__': unittest.main()
