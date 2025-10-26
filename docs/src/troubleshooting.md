# Troubleshooting

Encountering issues? Here are some tips to get you back on track:

## Security devices do not seem to update or do not appear

If you have installed AutoFirma and enabled Firefox integration, but Firefox does not
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
AutoFirma before this renewal, it is possible that OpenSC has cached your old certificates.
To fix this, you need to delete the OpenSC cache. [By default, it is located at
$HOME/.cache/opensc](https://github.com/OpenSC/OpenSC/wiki/Environment-variables).

```console
$ rm -rf $HOME/.cache/opensc
```

## DNIeRemote Android App Compatibility

The DNIeSmartConnect Android app may not be available on Google Play for modern Android devices (Android 13 and later). This is because the app has not been updated to meet current Google Play requirements. However, the app itself still works on modern Android devices and can be installed using alternative methods.

### Installation Options

#### Option A: Install via APK from APKCombo

1. **Allow installation from unknown sources**
   - Android 9+ (Pie and newer): `Settings` > `Apps & notifications` > `Special app access` > `Install unknown apps` > select the app (Chrome, your file manager, etc.) > Enable "Allow from this source".

2. **Download the APK with APKCombo**
   - Visit: https://apkcombo.com/playstore-downloader/
   - Package name: `es.gob.fnmt.dniesmartconnect`
   - APKCombo fetches the APK securely from Play servers.

3. **Install the APK**
   - Open the downloaded APK and follow the prompts.

4. **Post-install**
   - Grant necessary permissions and test the DNIeRemote integration with the PC side.

#### Option B: Install on a compatible device and transfer the APK

1. **On a compatible Android device, install from Google Play**
   - Search for "DNIeSmartConnect" on Google Play Store and install the app.

2. **Transfer/export the APK to your target device**
   - Use a backup/transfer method (e.g., USB, Bluetooth, cloud storage, or an APK extractor/backup tool) to get the APK file from the compatible device to your target device.

3. **Install on the target device**
   - Ensure unknown sources are allowed for the installer (as described in Option A, Step 1), then install the APK from the transferred location.

4. **Post-install**
   - Grant permissions and verify that DNIeRemote works with your PC.

### Security Verification

To verify the legitimacy of any downloaded APK, use `apksigner verify --print-certs your-app.apk`. Authenticate that the APK's signing certificate matches the official one from Google Play (CNP-FNMT). This confirms that your download is the genuine, untampered DNIeSmartConnect app.

### Additional Resources

For more detailed instructions and background information, see this blog post: [Como instalar DNIeRemote en Android 13 o posterior](https://www.jasoft.org/Blog/post/como-instalar-dnieremote-en-android-13-o-posterior)

