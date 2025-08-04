{
  description = "Omenix Fan Control for HP Omen laptops";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      omenix = pkgs.rustPlatform.buildRustPackage {
        pname = "omenix";
        version = "0.1.0";

        src = pkgs.lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            let baseName = baseNameOf path; in
            (pkgs.lib.cleanSourceFilter path type) ||
            (type == "directory" && baseName == "assets") ||
            (type == "regular" && pkgs.lib.hasSuffix ".png" baseName);
        };

        cargoLock = {
          lockFile = ./Cargo.lock;
        };

        nativeBuildInputs = with pkgs; [
          pkg-config
          gcc
        ];

        buildInputs = with pkgs; [
          gtk3
          libappindicator-gtk3
          libayatana-appindicator
          openssl
          xdotool
        ];

        meta = with pkgs.lib; {
          description = "Fan control application for HP Omen laptops";
          homepage = "https://github.com/noahpro99/omenix";
          license = licenses.mit;
          platforms = platforms.linux;
          mainProgram = "omenix";
        };
      };
    in
    {
      packages.${system} = {
        default = omenix;
        omenix = omenix;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${omenix}/bin/omenix";
          meta = {
            description = "Omenix Fan Control GUI";
            mainProgram = "omenix";
          };
        };

        omenix-daemon = {
          type = "app";
          program = "${omenix}/bin/omenix-daemon";
          meta = {
            description = "Omenix Fan Control Daemon";
            mainProgram = "omenix-daemon";
          };
        };
      };

      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.omenix;
        in
        {
          options.services.omenix = {
            enable = mkEnableOption "Omenix fan control daemon";

            package = mkOption {
              type = types.package;
              default = omenix;
              description = "The omenix package to use.";
            };
          };

          config = mkIf cfg.enable {
            systemd.services.omenix-daemon = {
              description = "Omenix Fan Control Daemon";
              wantedBy = [ "multi-user.target" ];
              after = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                ExecStart = "${cfg.package}/bin/omenix-daemon";
                Restart = "on-failure";
                RestartSec = 5;
                User = "root";
              };
            };

            environment.systemPackages = [ cfg.package ];
          };
        };

      devShells.${system}.default = pkgs.mkShell
        {
          buildInputs = with pkgs; [
            # Runtime libraries
            gtk3
            xdotool
            libappindicator-gtk3
            libayatana-appindicator
          ];

          nativeBuildInputs = with pkgs; [
            # Build tools
            cargo
            rustc
            rust-analyzer
            clippy
            bashInteractive
            gcc
            openssl
            pkg-config
            libiconv
          ];

          shellHook = ''
            # Make sure dynamic linker can find the GTK/AppIndicator .so files
            export LD_LIBRARY_PATH="${
              pkgs.lib.makeLibraryPath [
                pkgs.libayatana-appindicator
                pkgs.libappindicator-gtk3
                pkgs.gtk3
              ]
            }:$LD_LIBRARY_PATH"

            # Helpful for some GTK apps so schemas/icons resolve
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share:${pkgs.hicolor-icon-theme}/share:$XDG_DATA_DIRS"
            
            echo "🔧 Omenix development environment loaded"
            echo "📦 Build the project with: cargo build"
            echo "🚀 Run daemon with: cargo run --bin omenix-daemon"
            echo "🎯 Run GUI with: cargo run --bin omenix"
            echo ""
            echo "📋 For NixOS users:"
            echo "   # Add to configuration.nix:"
            echo "   services.omenix.enable = true;  # Enables the daemon"
            echo ""
            echo "   # Add to Hyprland config for GUI:"
            echo "   exec-once = omenix"
            echo ""
            echo "📋 For non-NixOS users:"
            echo "   nix run github:noahpro99/omenix  # Runs the GUI"
          '';

        };
    };
}

