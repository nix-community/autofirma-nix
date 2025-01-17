# Security

AutoFirma chats with remote servers in a couple of different ways to handle document signing and authentication. Here’s the lowdown on these scenarios and how certificates fit into the bigger picture.

## Browser-based scenario

In most cases, your friendly web browser takes care of the heavy lifting for server authentication: it connects to the remote server and confirms the server’s identity with its own certificate store. After that, the browser opens a WebSocket to AutoFirma, relaying commands back and forth. For this communication to work, a SSL certificate is created and added to Firefox; depending on the installation method you chose is located either in `/etc/AutoFirma` or in `$HOME/.afirma/AutoFirma`.

## Direct connection scenario

Sometimes, the browser tells AutoFirma to talk directly to the remote server. In that case, AutoFirma itself must determine which Certificate Authorities (CAs) are valid. This is where certificate management in AutoFirma becomes important.

## Managing certificates in autofirma-nix

AutoFirma trusts a certificate only if it meets two conditions:

1. **Official Provider**  
   It must come from one of the providers published in the Spanish Government’s authorized list.

2. **System CA Store**  
   It must also appear in your system’s *ca-bundle* (or *cacerts*) on NixOS. If your NixOS configuration blocks or adds a certificate, AutoFirma respects that setting.

If a certificate is missing from the system CA store or explicitly blocked, AutoFirma will ignore it—even if it shows up on the official list.

### Relevant NixOS options

- **`security.pki.certificateFiles`**  
  Adds extra certificates to the global truststore. If a certificate is on the official list, and you include it here, AutoFirma will trust it.

- **`security.pki.caCertificateBlacklist`**  
  Blocks specific certificates. Even if one is on the official list, AutoFirma ignores it if it appears here.

#### Minimal example

```nix
{
  security.pki = {
    certificateFiles = [
      ./my-certificate.crt
    ];
    caCertificateBlacklist = [
      "Izenpe.com"
    ];
  };
  programs.autofirma.enable = true;
}
```

In this snippet, if `./my-certificate.crt` is on the official list, AutoFirma will trust it, while any certificate from `Izenpe.com` is blacklisted, no matter what.

