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

  # The preview host only has to prove its desktop wiring evaluates and
  # installs: the Dux user unit and the display manager. SDDM is reached
  # through display-manager.service, so that is the unit name to assert.
  dux-vm = mkHostTest "dux-vm" ../hosts/dux-vm/default.nix [ ] ''
    machine.succeed("test -f /etc/systemd/user/dms.service")
    machine.succeed("test -e /etc/systemd/system/display-manager.service")
  '';

  # The preview host has to prove its desktop wiring installs and that the
  # session starts without a greeter. A Wayland session cannot run in the test
  # VM, so the greeter path is checked at evaluation time instead.
  noctalia-vm = mkHostTest "noctalia-vm" ../hosts/noctalia-vm/default.nix [
    ({ config, ... }: {
      assertions = [
        {
          assertion = (config.services.greetd.settings.initial_session.user or null) == "noctalia";
          message = "noctalia-vm must start the preview session from greetd's initial_session";
        }
        {
          assertion = (config.services.greetd.settings.initial_session.command or null) == "${config.programs.umbriel.package}/bin/start-umbriel";
          message = "noctalia-vm must start the Umbriel session, not another command";
        }
      ];
    })
  ] ''
    machine.succeed("grep -q 'WantedBy=umbriel-session.target' /etc/systemd/user/noctalia.service")
    machine.succeed("test -e /etc/systemd/system/display-manager.service")
    machine.succeed("test -x /run/current-system/sw/bin/luciole")
  '';
}
