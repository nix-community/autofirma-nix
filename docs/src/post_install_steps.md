# Post-install steps

After installing AutoFirma, you’ll need to add a local self-signed certificate so your browser can talk to AutoFirma without throwing its hands up in panic. Below are the steps for installing (and uninstalling) the certificate.

## Installing the self-signed certificate

Make sure Firefox is open and then run:

```console
$ autofirma-setup
```

This generates a special certificate and plugs it into your browser’s trust store, allowing safe, squeaky-clean WebSocket communication with AutoFirma. Once it’s done, close and restart Firefox, and you’ll be all set!

## Uninstalling the self-signed certificate

If you ever decide you no longer need AutoFirma’s local certificate, run:

```console
$ autofirma-setup --uninstall
```

Give your browser a quick restart, and it’ll be as though AutoFirma never set foot in your certificate store in the first place. Perfect for tidying up or debugging!

