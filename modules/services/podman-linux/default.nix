{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.podman;
  toml = pkgs.formats.toml { };
in
{
  meta.maintainers = [
    lib.hm.maintainers.bamhm182
    lib.maintainers.n-hass
  ];

  imports = [
    ./builds.nix
    ./containers.nix
    ./images.nix
    ./install-quadlet.nix
    ./networks.nix
    ./services.nix
    ./volumes.nix
  ];

  options.services.podman = {
    enable = lib.mkEnableOption "Podman, a daemonless container engine";

    settings = {
      containers = lib.mkOption {
        type = toml.type;
        default = { };
        description = "containers.conf configuration";
      };

      storage = lib.mkOption {
        type = toml.type;
        description = "storage.conf configuration";
      };

      registries = {
        search = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "docker.io" ];
          description = ''
            List of repositories to search.
          '';
        };

        insecure = lib.mkOption {
          default = [ ];
          type = lib.types.listOf lib.types.str;
          description = ''
            List of insecure repositories.
          '';
        };

        block = lib.mkOption {
          default = [ ];
          type = lib.types.listOf lib.types.str;
          description = ''
            List of blocked repositories.
          '';
        };
      };

      policy = lib.mkOption {
        default = { };
        type = lib.types.attrs;
        example = lib.literalExpression ''
          {
            default = [ { type = "insecureAcceptAnything"; } ];
            transports = {
              docker-daemon = {
                "" = [ { type = "insecureAcceptAnything"; } ];
              };
            };
          }
        '';
        description = ''
          Signature verification policy file.
          If this option is empty the default policy file from
          `skopeo` will be used.
        '';
      };

      mounts = lib.mkOption {
        default = [ ];
        type = lib.types.listOf lib.types.str;
        description = "mounts.conf configuration";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [ (lib.hm.assertions.assertPlatform "podman" pkgs lib.platforms.linux) ];

    home.packages = [ cfg.package ];

    services.podman.settings.storage = {
      storage.driver = lib.mkDefault "overlay";
    };

    xdg.configFile = {
      "containers/policy.json".source =
        if cfg.settings.policy != { } then
          pkgs.writeText "policy.json" (builtins.toJSON cfg.settings.policy)
        else
          "${pkgs.skopeo.policy}/default-policy.json";
      "containers/registries.conf".source = toml.generate "registries.conf" {
        registries = lib.mapAttrs (n: v: { registries = v; }) cfg.settings.registries;
      };
      "containers/storage.conf".source = toml.generate "storage.conf" cfg.settings.storage;
      "containers/containers.conf".source = toml.generate "containers.conf" cfg.settings.containers;
      "containers/mounts.conf" = lib.mkIf (cfg.settings.mounts != [ ]) {
        text = builtins.concatStringsSep "\n" cfg.settings.mounts;
      };
    };
  };
}
