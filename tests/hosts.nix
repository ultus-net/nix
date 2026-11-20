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
  # The console is on for every headless host. The test proves the socket is
  # up and that cockpit-ws serves its own login page on loopback, which a
  # generic error page cannot fake. The firewall keeps 9090 closed, so the port
  # is deliberately not opened.
  base-server = mkHostTest "base-server" ../roles/base.nix
    [ ({ lib, ... }: { networking.hostName = lib.mkForce "machine"; }) ]
    ''
      machine.wait_for_unit("cockpit.socket")
      machine.succeed("curl -kfsSL https://localhost:9090/ | grep -q 'cockpit/static/login.js'")
      machine.succeed("curl -kfsSLo /dev/null -w '%{http_code}' https://localhost:9090/cockpit/static/login.js | grep -qx 200")
    '';

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

  # The dev-server host runs the Podman runtime plus the console, and its role
  # import is what a desktop swap rewrites. A socket unit alone would pass even
  # with a runtime that cannot answer, so the test asks the API behind it.
  elitedesk-800-g4 = mkHostTest "elitedesk-800-g4" ../hosts/elitedesk-800-g4/default.nix [ ]
    ''
      machine.wait_for_unit("podman.socket")
      machine.wait_for_unit("cockpit.socket")
      machine.succeed("test -L /run/docker.sock")
      machine.succeed("podman info > /dev/null")
      machine.succeed("docker info > /dev/null")
    '';

  # The preview host only has to prove its desktop wiring evaluates and
  # installs: the Dux user unit and the display manager. SDDM is reached
  # through display-manager.service, so that is the unit name to assert.
  dux-vm = mkHostTest "dux-vm" ../hosts/dux-vm/default.nix [ ] ''
    machine.succeed("test -f /etc/systemd/user/dms.service")
    machine.succeed("test -e /etc/systemd/system/display-manager.service")
  '';

  # Hyprland 0.57 loads its Lua config from the XDG config directories, so the
  # test proves the Lua files are installed, the obsolete .conf is gone, and a
  # display manager is wired. The compositor itself needs a GPU and cannot run
  # here; the session name is asserted at evaluation time.
  hyprland-vm = mkHostTest "hyprland-vm" ../hosts/hyprland-vm/default.nix [
    ({ config, ... }: {
      assertions = [
        {
          assertion = config.programs.hyprland.enable;
          message = "hyprland-vm must enable programs.hyprland, which provides the session file";
        }
        {
          assertion = config.services.displayManager.defaultSession == "hyprland";
          message = "hyprland-vm must select the hyprland session";
        }
        {
          assertion = config.services.displayManager.autoLogin.user == "hyprland";
          message = "hyprland-vm must start the preview session without a greeter";
        }
      ];
    })
  ] ''
    machine.succeed("test -f /etc/xdg/hypr/hyprland.lua")
    machine.succeed("grep -q 'require(\"looknfeel\")' /etc/xdg/hypr/hyprland.lua")
    machine.succeed("test ! -e /etc/xdg/hypr/hyprland.conf")
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
