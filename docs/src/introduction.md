# Introduction

Welcome to **autofirma-nix**! This project provides a suite of tools to interact with Spain’s public administration, seamlessly integrating into your NixOS and Home Manager setup. It includes:

- **Autofirma** for digitally signing documents and authenticating on various Spanish administration websites—because ink and paper are so last century.
- **DNIeRemote** for using an NFC-based national ID via an Android device—no more digging through drawers for that card reader you haven’t seen since 2010.
- **Configurador FNMT-RCM** for securely requesting personal certificates from the Spanish Royal Mint—yes, the mint that makes actual coins.
- Integration with **Mozilla Firefox** (provided on both the NixOS and the Home Manager modules) that allows Firefox to communicate with Autofirma, as required by some sites—now with automatic setup!
