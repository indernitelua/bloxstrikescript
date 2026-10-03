# Automatic publication

Push to main or run Publish netanyahu manually in Actions. Worker tests run before publication. Only the already obfuscated netanyahu.core.lua is uploaded to D1.

Add repository secrets under Settings > Secrets and variables > Actions:

- CLOUDFLARE_API_TOKEN: restricted to the account containing netanyahu-configs, with Workers Scripts Edit and Account Settings Read.
- LICENSE_ADMIN_TOKEN: the existing ADMIN_TOKEN secret of netanyahu-licenses.

No tokens belong in repository files. The Worker publisher discovers the existing account and keeps DB bindings. Obfuscation remains manual. Do not commit private keys, Excel ledgers or plaintext core.
