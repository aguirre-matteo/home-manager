{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cliphist;
in
{
  meta.maintainers = [
    lib.hm.maintainers.janik
    lib.maintainers.khaneliman
  ];

  imports = [
    (lib.mkRenamedOptionModule
      [ "services" "cliphist" "systemdTarget" ]
      [
        "services"
        "cliphist"
        "systemdTargets"
      ]
    )
  ];

  options.services.cliphist = {
    enable = lib.mkEnableOption "cliphist, a clipboard history “manager” for wayland";

    package = lib.mkPackageOption pkgs "cliphist" { };

    allowImages = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Store images in clipboard history.
      '';
    };

    extraOptions = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "-max-dedupe-search"
        "10"
        "-max-items"
        "500"
      ];
      description = ''
        Flags to append to the cliphist command.
      '';
    };

    systemdTargets = lib.mkOption {
      type = with lib.types; either (listOf str) str;
      default = [ config.wayland.systemd.target ];
      example = "sway-session.target";
      description = ''
        The systemd targets that will automatically start the cliphist service.

        When setting this value to `["sway-session.target"]`,
        make sure to also enable {option}`wayland.windowManager.sway.systemd.enable`,
        otherwise the service may never be started.

        Note: A single string value is deprecated, please use a list.
      '';
    };
  };

  config =
    let
      extraOptionsStr = lib.escapeShellArgs cfg.extraOptions;
    in
    lib.mkIf cfg.enable {
      assertions = [
        (lib.hm.assertions.assertPlatform "services.cliphist" pkgs lib.platforms.linux)
      ];

      home.packages = [ cfg.package ];

      systemd.user.services.cliphist = {
        Unit = {
          Description = "Clipboard management daemon";
          PartOf = lib.toList cfg.systemdTargets;
          After = lib.toList cfg.systemdTargets;
        };

        Service = {
          Type = "simple";
          ExecStart = "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --watch ${lib.getExe cfg.package} ${extraOptionsStr} store";
          Restart = "on-failure";
        };

        Install = {
          WantedBy = lib.toList cfg.systemdTargets;
        };
      };

      systemd.user.services.cliphist-images = lib.mkIf cfg.allowImages {
        Unit = {
          Description = "Clipboard management daemon - images";
          PartOf = lib.toList cfg.systemdTargets;
          After = lib.toList cfg.systemdTargets;
        };

        Service = {
          Type = "simple";
          ExecStart = "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --type image --watch ${lib.getExe cfg.package} ${extraOptionsStr} store";
          Restart = "on-failure";
        };

        Install = {
          WantedBy = lib.toList cfg.systemdTargets;
        };
      };
    };
}
