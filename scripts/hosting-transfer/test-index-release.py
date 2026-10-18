import importlib.util,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('release',Path(__file__).with_name('index-release.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class GuardTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.out=Path(self.temp.name);m.OUT=self.out
  self.data={'before_version':'sites/my-web-app-b67f4/versions/old','files':{'/index.html':'old','/main.dart.js':'keep'},'config':{'rewrites':[{'glob':'**','path':'/index.html'}]}}
  (self.out/'checkpoint.json').write_text(json.dumps(self.data))
 def assert_not_published(self,mocked):
  self.assertFalse(any('/releases?' in x.args[1] for x in mocked.call_args_list))
 def test_concurrent_live_release_stops_before_clone(self):
  with patch.object(m,'live',return_value='another'),patch.object(m,'call') as c:
   with self.assertRaises(AssertionError):m.deploy()
   c.assert_not_called()
 def test_clone_file_loss_stops_before_publication(self):
  with patch.object(m,'live',return_value=self.data['before_version']),patch.object(m,'call',return_value={'done':True,'response':{'name':'sites/my-web-app-b67f4/versions/staged'}}) as c,patch.object(m,'files',return_value={'/index.html':'old'}):
   with self.assertRaises(AssertionError):m.deploy()
   self.assert_not_published(c)
 def test_config_difference_stops_before_publication(self):
  def fake(method,path,body=None):
   return {'done':True,'response':{'name':'sites/my-web-app-b67f4/versions/staged'}} if method=='POST' else {'config':{}}
  with patch.object(m,'live',return_value=self.data['before_version']),patch.object(m,'call',side_effect=fake) as c,patch.object(m,'files',return_value=self.data['files']):
   with self.assertRaises(AssertionError):m.deploy()
   self.assert_not_published(c)
if __name__=='__main__':unittest.main()
