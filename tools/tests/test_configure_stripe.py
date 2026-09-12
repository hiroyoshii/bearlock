import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('configure_stripe', Path(__file__).parents[1] / 'configure_stripe.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class CheckoutConfigurationTests(unittest.TestCase):
    def test_rejects_unsafe_or_test_destinations(self):
        for url in ['http://buy.stripe.com/abc', 'https://buy.stripe.com.evil.org/abc',
                    'https://buy.stripe.com@evil.org/abc', 'https://buy.stripe.com:443/abc',
                    'https://buy.stripe.com/abc?redirect=https://evil.org',
                    'javascript:alert(1)', 'https://buy.stripe.com/test_abc',
                    'https://buy.stripe.com/abc#fragment', 'sk_live_secret']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                m.validate_url(url)

    def test_test_mode_is_explicit(self):
        self.assertEqual(m.validate_url('https://buy.stripe.com/test_fixture', True),
                         'https://buy.stripe.com/test_fixture')

    def test_render_both_languages_and_disable_without_leaving_old_link(self):
        with tempfile.TemporaryDirectory() as temp:
            site = Path(temp)
            for prefix in ['', 'en/']:
                path = site / prefix / 'support/development/index.html'
                path.parent.mkdir(parents=True)
                path.write_text('before' + m.START + 'old' + m.END + 'after')
            m.configure(site, 'https://buy.stripe.com/test_fixture', allow_test=True)
            for lang,prefix in [('ja',''),('en','en/')]:
                page = (site / prefix / 'support/development/index.html').read_text()
                self.assertIn('?locale=' + lang, page)
                self.assertIn('referrerpolicy="no-referrer"', page)
                self.assertTrue(page.startswith('before'))
                self.assertTrue(page.endswith('after'))
            m.configure(site, '')
            for path in site.rglob('index.html'):
                self.assertNotIn('buy.stripe.com', path.read_text())
                self.assertIn('role="status"', path.read_text())

    def test_bad_template_does_not_partially_update_site(self):
        with tempfile.TemporaryDirectory() as temp:
            site = Path(temp)
            pages = []
            for prefix in ['', 'en/']:
                path = site / prefix / 'support/development/index.html'
                path.parent.mkdir(parents=True)
                path.write_text(m.START + 'old' + (m.END if not prefix else 'missing end'))
                pages.append((path, path.read_text()))
            with self.assertRaises(ValueError):
                m.configure(site, '')
            for path, original in pages:
                self.assertEqual(path.read_text(), original)

if __name__ == '__main__':
    unittest.main()
