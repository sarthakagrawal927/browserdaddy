import plistlib
from pathlib import Path
import unittest

from web_url_registration import validate


class WebURLRegistrationTests(unittest.TestCase):
    def test_product_info_does_not_claim_web_links(self):
        info = plistlib.loads((Path(__file__).resolve().parents[1] / "Support/Info.plist").read_bytes())
        validate(info)

    def test_web_handlers_are_rejected(self):
        for scheme in ("http", "https", "HTTPS"):
            with self.subTest(scheme=scheme), self.assertRaisesRegex(ValueError, "must not register"):
                validate({"CFBundleURLTypes": [{"CFBundleURLSchemes": [scheme]}]})

    def test_unrelated_deep_link_is_allowed(self):
        validate({"CFBundleURLTypes": [{"CFBundleURLSchemes": ["browserdaddy"]}]})


if __name__ == "__main__":
    unittest.main()
