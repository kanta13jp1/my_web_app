import unittest
from preserve_live_labs import validated_files,PREFIX,NAMES
class PreservationTests(unittest.TestCase):
    def rows(self):return [{'path':PREFIX+n,'status':'ACTIVE','hash':'a'*64} for n in NAMES]
    def test_exact_set(self):self.assertEqual(set(validated_files(self.rows())),NAMES)
    def test_missing_is_rejected(self):
        with self.assertRaises(RuntimeError):validated_files(self.rows()[:-1])
    def test_unknown_or_traversal_is_rejected(self):
        for suffix in ['extra.png','../index.html']:
            with self.assertRaises(RuntimeError):validated_files(self.rows()+[{'path':PREFIX+suffix,'status':'ACTIVE','hash':'a'*64}])
    def test_pending_or_bad_hash_is_rejected(self):
        for key,value in [('status','PENDING'),('hash','bad')]:
            rows=self.rows();rows[0][key]=value
            with self.assertRaises(RuntimeError):validated_files(rows)
if __name__=='__main__':unittest.main()
