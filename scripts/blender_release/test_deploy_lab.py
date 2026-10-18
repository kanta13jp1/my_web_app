import tempfile
import unittest
from pathlib import Path
from deploy_lab import FILES, PREFIX, additions, preserved_map

class OverlaySafety(unittest.TestCase):
    def test_preserves_every_existing_unrelated_file(self):
        original={'/index.html':'a','/version.json':'b','/main.dart.js':'c','/echo-pump/index.html':'d'}
        result=preserved_map(original,{PREFIX+'index.html':'new'})
        for path,digest in original.items():self.assertEqual(result[path],digest)
        self.assertEqual(len(result),len(original)+1)
    def test_rejects_unrelated_overwrite_and_missing_root(self):
        with self.assertRaises(RuntimeError):preserved_map({'/index.html':'a'},{'/index.html':'bad'})
        with self.assertRaises(RuntimeError):preserved_map({}, {PREFIX+'index.html':'new'})
    def test_only_complete_approved_asset_set_can_be_uploaded(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)
            for name in FILES:(p/name).write_bytes(b'original lab asset')
            files,blobs,details=additions(p)
            self.assertEqual(set(files),{PREFIX+n for n in FILES})
            self.assertEqual(len(details),6)
            (p/'unrelated.txt').write_text('do not publish')
            with self.assertRaises(RuntimeError):additions(p)

if __name__=='__main__':unittest.main()
