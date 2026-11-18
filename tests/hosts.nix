{ self, pkgs }:
let
  # QEMU supplies its own root disk and bootloader. Everything else stays as the
  # host defines it.
  qemuDefaults = { lib, ... }: {
    fileSystems = lib.mkForce {
      "/" = {
        device = "/dev/vda";
        fsType = "ext4";
      };
    };
    swapDevices = lib.mkForce [ ];

    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  };

  mkHostTest = name: hostModule: extraModules: extraChecks:
    pkgs.testers.runNixOSTest {
      inherit name;

      node.specialArgs = { inputs = self.inputs; };

      nodes.machine = {
        imports = [ hostModule qemuDefaults ] ++ extraModules;
      };

      testScript = ''
        start_all()
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("sshd.service")
        machine.succeed("systemctl is-active firewall.service")
        ${extraChecks}
      '';
    };
in
{
  base-server = mkHostTest "base-server" ../roles/base.nix
    [ ({ lib, ... }: { networking.hostName = lib.mkForce "machine"; }) ]
    "";

  # QEMU has no NVIDIA GPU, so the host runs on modesetting there.
  tower = mkHostTest "tower" ../hosts/tower/default.nix
    [
      ({ lib, ... }: {
        services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
        boot.blacklistedKernelModules = lib.mkForce [ ];
      })
    ]
    ''
      machine.wait_for_unit("docker.service")
    '';

  # fwupd's unit ships linked rather than enabled, so `is-enabled` reports it
  # not-enabled. TLP is enabled by this host's config and only this host's.
  work-laptop = mkHostTest "work-laptop" ../hosts/work-laptop/default.nix [ ] ''
    machine.succeed("systemctl is-enabled tlp.service")
  '';
}
