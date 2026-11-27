# kaist-openconnect

[한국어](README.md) | **English**

A small, dependency-free command-line client for connecting to the **KAIST VPN**
(Ivanti Connect Secure + AirCUVE "2Auth" two-factor) entirely from the terminal —
no browser required.

It prompts for your ID, password, and one-time code (SMS or email), completes the
two-factor handshake, and then brings the tunnel up with
[OpenConnect](https://www.infradead.org/openconnect/).

## Install

Paste this one line into your terminal — it installs everything you need
(Homebrew on macOS if missing, plus OpenConnect) and links `kvpn` onto your
`PATH`:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/predict-woo/kaist-openconnect/main/install.sh)"
```

Then just run `kvpn`. It skips anything already installed, so it's safe to
re-run — re-running also updates kvpn to the latest version. On Linux it uses
your distribution's package manager (apt/dnf/pacman/zypper) for the
dependencies.

<details>
<summary>Manual install (if you'd rather not run the installer)</summary>

Install the [requirements](#requirements) yourself, then:

```sh
git clone https://github.com/predict-woo/kaist-openconnect.git
cd kaist-openconnect
chmod +x kvpn
./kvpn
```

Optionally put it on your `PATH`:

```sh
ln -s "$PWD/kvpn" /usr/local/bin/kvpn
```

</details>

Set a default ID so you can just press Enter at the prompt:

```sh
export KVPN_USER=your_id   # add to ~/.zshrc or ~/.bashrc
```

![A full kvpn session: ID/password/realm prompts, SMS one-time code, Keychain storage offer, and OpenConnect bringing up the tunnel](docs/screenshot.png)

With stored credentials, later runs skip straight to code authentication.
On macOS, kvpn waits for the SMS code automatically:

```
$ ./kvpn
=== KAIST VPN (kvpn) ===
Using stored credentials for your_id (KAIST Members). Run `kvpn --forget` to remove.
Code sent via SMS. It may take up to a minute to arrive.
Waiting up to 60 seconds for a KVPN SMS in Messages...
```

## Why

KAIST's VPN uses Ivanti Connect Secure with an AirCUVE second factor whose OTP
step runs inside a JavaScript portal on a separate host. OpenConnect on its own
can't drive that portal, so the usual advice is "log in with a browser, copy the
`DSID` cookie, then run openconnect." This tool automates that whole dance: it
performs the portal's OTP flow over plain HTTP and hands the resulting session
cookie to OpenConnect for you.

**It does not bypass anything.** You still authenticate with your own password and
a fresh one-time code on every connection — exactly like the official client.

## Requirements

- **Python 3** (standard library only — no `pip install`)
- **[OpenConnect](https://www.infradead.org/openconnect/)** on your `PATH`
  (`brew install openconnect` on macOS)
- `sudo` rights (OpenConnect needs root to create the tunnel interface)

Developed and tested on macOS. It should work on Linux with OpenConnect's default
`vpnc-script`; reports welcome.

## Usage

Run `./kvpn` and follow the prompts. To disconnect, press **Ctrl-C** in the
terminal running it — OpenConnect tears down the tunnel and restores your routes.

### macOS: automatic SMS code entry

```sh
kvpn
```

On macOS, kvpn selects SMS delivery automatically, waits up to 60 seconds for a
new KVPN text in Mac Messages, and submits its code. If Messages access is not
permitted, kvpn explains how to grant access and automatically falls back to
manual code entry without requiring another option or restart. It also falls
back to manual entry if no code is found within 60 seconds. Linux keeps the
existing SMS/email selection and manual code entry.

To enter a code manually or use email authentication, disable automatic entry.
This mode never accesses Messages:

```sh
kvpn --no-auto-sms
```

You can also explicitly enable automatic entry with `--auto-sms`.

Before using it:

1. Make sure your iPhone's KVPN texts appear in Mac Messages. Use the same Apple
   Account and set up [Text Message Forwarding](https://support.apple.com/102545).
2. In **System Settings → Privacy & Security → Full Disk Access**, allow the app
   running kvpn (for example Terminal, iTerm2, or Emacs). You may need to quit and
   reopen that app after changing permissions.

Press `Ctrl-C` to cancel while waiting.

### macOS: sudo authentication with Touch ID (optional)

On a Mac with Touch ID, sudo can use fingerprint authentication through its PAM
configuration. kvpn uses the system sudo authentication and does not store your
fingerprint or Mac password. This setting affects other sudo commands too.

On recent macOS versions, first check that `/etc/pam.d/sudo` includes
`sudo_local`. Follow the system's `/etc/pam.d/sudo_local.template` instructions
to configure `/etc/pam.d/sudo_local` with this entry, preserving existing local
settings. There is no need to edit `/etc/pam.d/sudo` itself:

```text
auth       sufficient     pam_tid.so
```

Administrator access is required. Run `sudo -k` followed by `sudo -v` to test.
Touch ID availability depends on the execution environment and password fallback
may still be necessary. kvpn does not change this system setting automatically.

### Stored credentials

After a successful login, kvpn offers to store your credentials so future runs
jump straight to code authentication. The password goes into the
**macOS Keychain** (service `kvpn`); your ID and realm go into
`~/.config/kvpn/config.json` (user-only, `0600`). On systems without a
Keychain, the password is kept in that same `0600` file instead (kvpn warns
you first). A fresh one-time code is still required on every connection.

To remove everything that was stored:

```sh
./kvpn --forget
```

Set `KVPN_DEBUG=1` to print the internal HTTP redirect chain (useful if the login
flow changes and something breaks):

```sh
KVPN_DEBUG=1 ./kvpn
```

## Notes & troubleshooting

- **Credential storage is opt-in.** Nothing is saved unless you answer "y" at
  the store prompt; `kvpn --forget` removes it all. The `DSID` is ephemeral
  either way (it dies when you disconnect), and a fresh one-time code is
  required on every connection.
- **Stored password went stale?** If your KAIST password changes, the final
  login step will fail — run `kvpn --forget` and log in again.
- **`sudo` prompt collision:** if `sudo` misbehaves because stdin is piped, run
  `sudo -v` first, then `./kvpn`.
- **Harmless route warnings:** on connect you may see two lines like
  `Can't assign requested address` / `File exists` for a route to your own VPN IP
  or an already-present route. Every other route still installs; this doesn't
  affect connectivity.
- **If login suddenly breaks**, KAIST likely changed the portal flow. Run with
  `KVPN_DEBUG=1` and open an issue with the (redacted) hop list.

## Disclaimer

This is an unofficial, personal interoperability tool. It is **not affiliated with
or endorsed by KAIST, Ivanti, or AirCUVE**. Use it with your own account and in
accordance with your institution's acceptable-use policy. Provided "as is" without
warranty of any kind (see [LICENSE](LICENSE)).

## Acknowledgements

Built on top of the excellent [OpenConnect](https://www.infradead.org/openconnect/)
project, which does the actual VPN tunneling.
