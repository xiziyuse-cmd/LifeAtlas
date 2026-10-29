import unittest
from auto_release import read_version,parse_badging
class ReleaseMetadataTest(unittest.TestCase):
    def test_version_uses_numeric_build(self):
        self.assertEqual(read_version('name: lifeatlas\nversion: 2.1.1+29\n'), ('2.1.1',29))
    def test_bad_version_rejected(self):
        with self.assertRaises(RuntimeError): read_version('version: latest')
    def test_actual_apk_identity(self):
        self.assertEqual(parse_badging("package: name='com.example.lifeatlas' versionCode='29' versionName='2.1.1'\nsdkVersion:'24'"),{'packageName':'com.example.lifeatlas','build':29,'version':'2.1.1','minSdk':24})
    def test_other_package_or_unknown_sdk_rejected(self):
        for text in ["package: name='other.app' versionCode='29' versionName='2.1.1'\nsdkVersion:'24'", "package: name='com.example.lifeatlas' versionCode='29' versionName='2.1.1'"]:
            with self.assertRaises(RuntimeError): parse_badging(text)
if __name__=='__main__': unittest.main()
