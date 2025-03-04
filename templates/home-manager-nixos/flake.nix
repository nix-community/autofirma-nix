{
  description = "Home Manager with NixOS for AutoFirma (user-specific installation)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
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

  outputs = { self, nixpkgs, home-manager, autofirma-nix, ... }: {
    nixosConfigurations.mysystem = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      modules = [
        home-manager.nixosModules.home-manager
        
        ({ config, pkgs, ... }: {
          # Basic system configuration
          networking.hostName = "mysystem";
          time.timeZone = "Europe/Madrid";
          system.stateVersion = "23.11";

          # Home Manager configuration
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          
          # User account setup
          users.users.myuser = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
            home = "/home/myuser";
          };
          
          # Configure Home Manager for the user
          home-manager.users.myuser = { config, ... }: {
            imports = [
              autofirma-nix.homeManagerModules.default
            ];
            
            home.stateVersion = "23.11";
            
            # ===============================
            # === AutoFirma Configuration ===
            # ===============================
            programs.autofirma = {
              # Enable AutoFirma
              enable = true;
              
              # Firefox integration with specific profile(s)
              firefoxIntegration.profiles = {
                default = {
                  enable = true;
                };
              };
              
              # Custom package (uncomment if needed)
              # package = pkgs.autofirma;
              
              # Custom truststore package (uncomment if needed)
              # truststore.package = pkgs.autofirma-truststore;
              
              # AutoFirma config options
              config = {
                # Avoid confirmation dialog when closing
                omitAskOnClose = true;
                
                # Enable JMultiCard functionality
                enabledJmulticard = true;
                
                # Allow invalid signatures
                allowInvalidSignatures = false;
                
                # Use implicit mode for CAdES signatures
                cadesImplicitMode = true;
                
                # More config options available - see home_manager_options.html
              };
            };

            # ===============================
            # === DNIeRemote Configuration ===
            # ===============================
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
              
              # Custom package (uncomment if needed)
              # package = pkgs.dnieremote;
            };

            # =======================================
            # === FNMT Configurator Configuration ===
            # =======================================
            programs.configuradorfnmt = {
              # Enable FNMT certificate configuration tool
              enable = true;
              
              # Firefox integration with specific profile(s)
              firefoxIntegration.profiles = {
                default = {
                  enable = true;
                };
              };
              
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
                  "OpenSC PKCS11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
                  
                  # For smartphone NFC using DNIeRemote
                  "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
                };
              };
              
              # Define Firefox profiles 
              profiles.default = {
                id = 0; # Makes this the default profile
              };
            };
          };

          # Additional useful packages for smart card support
          environment.systemPackages = with pkgs; [
            opensc
            pcsc-lite
            pcsc-tools
            ccid
          ];

          # Enable PC/SC smart card service
          services.pcscd.enable = true;
        })
      ];
    };
  };
}