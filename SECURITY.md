# Security

## Threat model

Odak runs as your normal user. The only part that runs as root is the website blocking helper, so that is where the risk is.

**What is installed.** When you click Install Helper and enter your admin password, Odak installs:

- `/Library/PrivilegedHelperTools/app.odak.block`, a short shell script owned by `root:wheel`, mode 755. Your user cannot modify it.
- `/etc/sudoers.d/app_odak`, owned by `root:wheel`, mode 440, containing one line:

  ```
  yourname ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/app.odak.block
  ```

  It is validated with `visudo -cf` before installation. The file name has no dot because sudo skips files in `/etc/sudoers.d` whose names contain one.

**What this means.** Any process running as your user can run the helper as root without a password. That is the point of the rule, so assume anything on your account can call it. The helper is written so that this grants very little:

- It accepts only three commands: `on <domains...>`, `off` and `status`. `off` and `status` take no arguments. Anything else exits with an error.
- Every domain must match a strict regex: lowercase letters, digits and hyphens, dot-separated labels of at most 63 characters, at least two labels, at most 253 characters total. If any argument does not match, the helper exits without changing anything. No spaces, newlines, IP addresses, wildcards or shell metacharacters can get through.
- Domains are only ever mapped to `0.0.0.0` and `::`. The helper cannot point a name at a real address, so it cannot be used to redirect traffic.
- It only edits the lines between `# >>> ODAK BLOCK` and `# <<< ODAK BLOCK` in `/etc/hosts`. Everything else in the file is preserved. The new file is written next to `/etc/hosts` and renamed over it, so a failure leaves the old file in place.
- It only calls standard system tools by absolute path (`awk`, `mktemp`, `chmod`, `chown`, `mv`, `rm`, `id`, `dscacheutil`, `killall`). sudo resets the environment, and the script also runs as `bash -p` and sets its own `PATH`, `IFS` and `LC_ALL`, so variables such as `BASH_ENV` or exported functions are ignored.

The worst a malicious local process can do with it is block domains or clear Odak's block. A process that already runs as your user can do more harmful things than that.

**What Odak does not do.** It makes no network requests, has no update mechanism, and does not collect data. App hiding uses public `NSWorkspace` APIs and needs no privileges.

**Removing it.** See "Removing everything by hand" in the [README](README.md#removing-everything-by-hand).

## Reporting a vulnerability

Please do not open a public issue. Email security@example.com (placeholder, to be replaced) with a description and, if possible, steps to reproduce. I will reply within a week and credit you in the changelog unless you prefer otherwise.

Only the latest release is supported.
