# Security

Never commit credentials, API keys, access tokens, private keys, session transcripts, local memory, or machine-specific configuration.

Before publishing a change, search the diff for home-directory paths, provider tokens, hostnames, email addresses, and copied runtime state. Treat every script that can modify the operating system, scheduled tasks, firewall, security exclusions, or repositories as code that requires review and explicit approval.

If a secret is accidentally committed, revoke or rotate it immediately. Removing the file in a later commit is not sufficient because Git history may retain it.
