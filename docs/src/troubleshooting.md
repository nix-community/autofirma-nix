# Troubleshooting

Encountering issues? Here are some tips to get you back on track:

## Security devices do not seem to update or do not appear

If you have installed Autofirma and enabled Firefox integration, but Firefox does not
detect the security devices, you may need to remove the `pkcs11.txt` file from the
Firefox profile folder. For instance, if you enabled the Home Manager module and the
profile is named `myprofile`, the file is located in `~/.mozilla/firefox/myprofile/pkcs11.txt`.

Removing it and restarting Firefox should solve the issue:

```console
$ rm ~/.mozilla/firefox/myprofile/pkcs11.txt
$ firefox
```

## Missing certificates even though the DNIe PIN was requested

If OpenSC PKCS#11 prompts you for a password but no certificates are available for
signing, you might see something like the following in the Autofirma logs (when
running it from a terminal):

```console
$ autofirma
...
INFO: El almacen externo 'OpenSC PKCS#11' ha podido inicializarse, se anadiran sus entradas y se detiene la carga del resto de almacenes
...
INFO: Se ocultara el certificado por no estar vigente: java.security.cert.CertificateExpiredException: NotAfter: Sat Oct 26 15:03:27 GMT 2024
...
INFO: Se ocultara el certificado por no estar vigente: java.security.cert.CertificateExpiredException: NotAfter: Sat Oct 26 15:03:27 GMT 2024
...
SEVERE: Se genero un error en el dialogo de seleccion de certificados: java.lang.reflect.InvocationTargetException
....
SEVERE: El almacen no contiene ningun certificado que se pueda usar para firmar: es.gob.afirma.keystores.AOCertificatesNotFoundException: No se han encontrado certificados validos en el almacen
```

This occurs because your certificates have expired, as indicated by the “NotAfter:” date.

If the certificates are not expired because you recently renewed them, but you used
Autofirma before this renewal, it is possible that OpenSC has cached your old certificates.
To fix this, you need to delete the OpenSC cache. [By default, it is located at
$HOME/.cache/opensc](https://github.com/OpenSC/OpenSC/wiki/Environment-variables).

```console
$ rm -rf $HOME/.cache/opensc
```

