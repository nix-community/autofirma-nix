# Troubleshooting

Encountering issues? Here are some tips to get you back on track:

## Security devices not updating

If Firefox doesn’t detect security devices, clearing the `pkcs11.txt` file from your Firefox profile often resolves the issue:

```console
$ rm ~/.mozilla/firefox/myprofile/pkcs11.txt
$ firefox
```

Restart Firefox, and the devices should appear.

## Missing certificates after DNIe pin request

If OpenSC PKCS#11 requests a PIN but shows no certificates, and logs indicate expired ones, clearing the OpenSC cache might help:

```console
$ rm -rf $HOME/.cache/opensc
```

Retry signing, and the issue should resolve if the certificates are valid.

