# Cloudflare Pages setup

This repository includes a static App Store support site under `site/`.

## URLs

Use these paths after deployment:

- Privacy Policy URL: `https://<your-domain>/privacy/`
- Support URL: `https://<your-domain>/support/`
- English Privacy Policy URL: `https://<your-domain>/en/privacy/`
- English Support URL: `https://<your-domain>/en/support/`

Replace `<your-domain>` with the Cloudflare Pages domain or the custom domain.

## Cloudflare Pages dashboard

1. Create a Cloudflare Pages project.
2. Connect this Git repository.
3. Set the build command to empty.
4. Set the output directory to `site`.
5. Deploy.

## Wrangler direct upload

From the repository root:

```sh
npx wrangler pages deploy site --project-name bearlock
```

The root `wrangler.toml` also sets:

```toml
name = "bearlock"
pages_build_output_dir = "site"
```

## GitHub Actions deployment

The workflow `.github/workflows/cloudflare-pages.yml` deploys `site/` with Cloudflare's official `cloudflare/wrangler-action@v3`.

It runs on:

- Pushes to `main` when `site/**`, `wrangler.toml`, or the workflow changes.
- Pull requests touching the same files, as Cloudflare preview deployments.
- Manual `workflow_dispatch`.

Add these repository secrets in GitHub:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`

The API token should have Cloudflare Pages edit permission for the account/project.

## Before App Store submission

- Confirm `support@hiyozoo.com` is the correct support address.
- Open `/privacy/` and `/support/` in a private browser window.
- Confirm the pages load without authentication.
- Enter the final URLs in App Store Connect.
