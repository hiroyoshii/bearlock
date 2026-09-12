"""Render public Stripe Payment Links into the static support pages (no API keys)."""
import argparse
import html
import json
import os
from pathlib import Path
import re
from urllib.parse import urlsplit

START = '<!-- stripe-checkout:start -->'
END = '<!-- stripe-checkout:end -->'


def validate_url(value, allow_test=False):
    if not isinstance(value, str):
        raise ValueError('Payment Link must be a string')
    value = value.strip()
    if not value:
        return ''
    parsed = urlsplit(value)
    if (parsed.scheme != 'https' or parsed.netloc != 'buy.stripe.com'
            or not re.fullmatch(r'/[A-Za-z0-9_]+', parsed.path)
            or parsed.query or parsed.fragment):
        raise ValueError('Use the original https://buy.stripe.com/... Payment Link without query parameters')
    if parsed.path.startswith('/test_') and not allow_test:
        raise ValueError('Test Payment Links cannot be published; use --allow-test only for local previews')
    return value


def configure(site, url, allow_test=False):
    url = validate_url(url, allow_test)
    # Validate both templates before writing either file.
    changes = []
    for locale, prefix in [('ja', ''), ('en', 'en/')]:
        path = site / prefix / 'support/development/index.html'
        page = path.read_text()
        if page.count(START) != 1 or page.count(END) != 1:
            raise ValueError(f'Missing or duplicate checkout markers in {path}')
        if url:
            label = '金額を選んで応援する' if locale == 'ja' else 'Choose an amount and support'
            checkout = html.escape(url + '?locale=' + locale, quote=True)
            block = f'<a class="support-pay" href="{checkout}" referrerpolicy="no-referrer">{label}</a>'
        else:
            message = '応援のお支払いは準備中です。受付開始までお待ちください。' if locale == 'ja' else 'Support payments are not available yet. Please check back later.'
            block = f'<p class="payment-unavailable" role="status">{message}</p>'
        before, rest = page.split(START)
        _, after = rest.split(END)
        changes.append((path, before + START + '\n' + block + '\n' + END + after))
    for path, page in changes:
        path.write_text(page)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--site', type=Path, default=Path('site'))
    parser.add_argument('--url', default=os.environ.get('BEARLOCK_STRIPE_PAYMENT_LINK'))
    parser.add_argument('--allow-test', action='store_true')
    parser.add_argument('--require-live', action='store_true')
    args = parser.parse_args()
    url = args.url
    if url is None:
        url = json.loads((args.site / 'stripe-payment-link.json').read_text())['url']
    url = validate_url(url, args.allow_test)
    if args.require_live and (not url or '/test_' in url):
        parser.error('A live Payment Link is required')
    configure(args.site, url, args.allow_test)
    print('Stripe checkout links configured.' if url else 'Stripe checkout disabled: no Payment Link configured.')
