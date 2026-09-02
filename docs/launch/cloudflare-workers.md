# Cloudflare Workers setup

This repository includes a static App Store support site under `site/`.

The site is deployed as Cloudflare Workers Static Assets. No build step is required.

## URLs

Use these paths after deployment:

- Privacy Policy URL: `https://<your-domain>/privacy/`
- Support URL: `https://<your-domain>/support/`
- English Privacy Policy URL: `https://<your-domain>/en/privacy/`
- English Support URL: `https://<your-domain>/en/support/`

Replace `<your-domain>` with the workers.dev URL or the custom domain.

## Cloudflare dashboard setup

If setting this up from the Cloudflare dashboard:

1. Create a Workers application.
2. Connect this Git repository.
3. Use the root `wrangler.toml`.
4. Leave the build command empty.
5. Use `npx wrangler deploy` as the deploy command if Cloudflare asks for one.
6. Deploy.

The root `wrangler.toml` configures the static assets:

```toml
name = "bearlock"
compatibility_date = "2026-09-02"
workers_dev = true

[assets]
directory = "./site"
not_found_handling = "404-page"
```

## GitHub Actions deployment

The workflow `.github/workflows/cloudflare-workers.yml` deploys `site/` with Cloudflare's official `cloudflare/wrangler-action@v3`.

It runs on:

- Pushes to `main` when `site/**`, `wrangler.toml`, or the workflow changes.
- Pull requests touching the same files.
- Manual `workflow_dispatch`.

Add these repository secrets in GitHub:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`

The API token should have Workers edit permission for the account.

## Manual deploy

From the repository root:

```sh
npx wrangler deploy
```

## Before App Store submission

- Confirm `support@hiyozoo.com` is the correct support address.
- Open `/privacy/` and `/support/` in a private browser window.
- Confirm the pages load without authentication.
- Enter the final URLs in App Store Connect.
