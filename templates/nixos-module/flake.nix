{
  description = "NixOS system with AutoFirma (system-wide installation)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    autofirma-nix = {
      url = "github:nix-community/autofirma-nix";
      # For stable release: url = "github:nix-community/autofirma-nix/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs = { self, nixpkgs, autofirma-nix, ... }: {
    nixosConfigurations.mysystem = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      modules = [
        autofirma-nix.nixosModules.default
        
        ({ config, pkgs, ... }: {
          # Basic system configuration
          networking.hostName = "mysystem";
          time.timeZone = "Europe/Madrid";
          system.stateVersion = "23.11";

          users.users.myuser = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
          };

          # ===============================
          # === AutoFirma Configuration ===
          # ===============================
          programs.autofirma = {
            # Enable AutoFirma
            enable = true;
            
            # Enable Firefox integration
            firefoxIntegration.enable = true;
            
            # Fix Java certificates (deprecated)
            # fixJavaCerts = false;
            
            # Custom package (uncomment if needed)
            # package = pkgs.autofirma;
            
            # Custom truststore package (uncomment if needed)
            # truststore.package = pkgs.autofirma-truststore;
          };

          # =======================================
          # === DNIeRemote Configuration ===
          # =======================================
          programs.dnieremote = {
            # Enable DNIeRemote for using smartphone as DNIe reader
            enable = true;
            
            # Skip intro screen and go directly to USB or WiFi setup
            # Possible values: "no" (default), "usb", "wifi"
            jumpIntro = "no";
            
            # Port for WiFi connection to smartphone
            wifiPort = 9501;
            
            # Port for USB connection to smartphone
            usbPort = 9501;
            
            # Whether to open the firewall for the WiFi port
            openFirewall = false;
            
            # Custom package (uncomment if needed)
            # package = pkgs.dnieremote;
          };

          # =======================================
          # === FNMT Configurator Configuration ===
          # =======================================
          programs.configuradorfnmt = {
            # Enable FNMT certificate configuration tool
            enable = true;
            
            # Enable Firefox integration
            firefoxIntegration.enable = true;
            
            # Custom package (uncomment if needed)
            # package = pkgs.configuradorfnmt;
          };

          # =============================
          # === Firefox Configuration ===
          # =============================
          programs.firefox = {
            enable = true;
            
            # Set up security devices for DNIe access
            policies = {
              SecurityDevices = {
                # For physical smart card readers (like DNIe)
                "OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
                
                # For smartphone NFC using DNIeRemote
                "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
              };
            };
          };

          # Enable PC/SC smart card service
          services.pcscd.enable = true;
        })
      ];
    };
  };
}
