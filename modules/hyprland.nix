{ config, pkgs, lib, ... }:
{
  options = {
    hyprland.enable = lib.mkEnableOption "Enable Omarchy-style Hyprland config";
  };

  config = lib.mkIf config.hyprland.enable {
    environment.systemPackages = with pkgs; [
      hyprland alacritty brave nautilus yazi lazygit lazydocker neovim feh libva-utils zsh btop powertop bluetui networkmanager waybar swww grim slurp
    ];
    users.defaultUserShell = pkgs.zsh;

    # Hyprland 0.57 resolves its config through hyprutils `findConfig`, which
    # looks for `hyprland.lua` in XDG_CONFIG_HOME and then XDG_CONFIG_DIRS. The
    # old `.conf` dialect is no longer read: a host without this file boots the
    # stock example config with no bar and no keybindings.
    programs.hyprland.enable = true;

    # SDDM's X11 greeter works without a GPU. Wayland mode needs a greeter
    # compositor, which the session compositor does not provide.
    services.xserver.enable = true;
    services.displayManager = {
      sddm.enable = true;
      defaultSession = "hyprland";
    };

    environment.etc = {
      # Hyprland adds the config directory to package.path, so these names
      # resolve as `require("looknfeel")` and friends.
      "xdg/hypr/hyprland.lua".text = ''
        require("monitors")
        require("input")
        require("looknfeel")
        require("bindings")
        require("windows")
        require("autostart")
      '';
      "xdg/hypr/looknfeel.lua".text = ''
        hl.config({
          general = {
            gaps_in = 5,
            gaps_out = 10,
            border_size = 2,
            col = {
              active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
              inactive_border = "rgba(595959aa)",
            },
            resize_on_border = false,
            allow_tearing = false,
            layout = "dwindle",
          },
          decoration = {
            rounding = 0,
            shadow = { enabled = true, range = 2, render_power = 3, color = 0xee1a1a1a },
            blur = { enabled = true, size = 3, passes = 1, vibrancy = 0.17 },
          },
          animations = { enabled = true },
          dwindle = { preserve_split = true, force_split = 2 },
          master = { new_status = "master" },
          misc = {
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            focus_on_activate = true,
          },
        })

        hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
        hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
        hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
        hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
        hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

        hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
        hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
        hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
        hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
        hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
        hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
      '';
      "xdg/hypr/input.lua".text = ''
        hl.config({
          input = {
            kb_layout = "us",
            follow_mouse = 1,
            repeat_rate = 40,
            repeat_delay = 600,
            sensitivity = 0,
            touchpad = {
              natural_scroll = true,
              clickfinger_behavior = false,
              scroll_factor = 0.4,
            },
          },
        })

        -- Alacritty is the only client that scrolls line by line on a touchpad.
        hl.window_rule({
          name = "alacritty-touchpad-scroll",
          match = { class = "Alacritty" },
          scroll_touchpad = 1.5,
        })
      '';
      "xdg/hypr/bindings.lua".text = ''
        local terminal = "alacritty"
        local browser = "brave"

        hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal))
        hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus --new-window"))
        hl.bind("SUPER + B", hl.dsp.exec_cmd(browser))
        hl.bind("SUPER + N", hl.dsp.exec_cmd(terminal .. " -e nvim ~/Documents/Notes"))
        hl.bind("SUPER + Y", hl.dsp.exec_cmd(terminal .. " -e yazi"))
        hl.bind("SUPER + L", hl.dsp.exec_cmd(terminal .. " -e lazygit"))
        hl.bind("SUPER + C", hl.dsp.exec_cmd(terminal .. " -e lazydocker"))

        -- Region screenshot, annotated in satty before it is saved.
        hl.bind("Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | satty --filename -]]))
      '';
      "xdg/hypr/autostart.lua".text = ''
        hl.on("hyprland.start", function()
          hl.exec_cmd("waybar")
          hl.exec_cmd("swww-daemon")
        end)
      '';
      "xdg/hypr/windows.lua".text = ''
        hl.window_rule({
          name = "float-dialogs",
          match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor)$" },
          float = true,
        })

        hl.window_rule({
          name = "browser-size",
          match = { class = "^(firefox|brave)$" },
          size = { 1200, 800 },
        })
      '';
      "xdg/hypr/monitors.lua".text = ''
        hl.monitor({
          output = "",
          mode = "preferred",
          position = "auto",
          scale = 1,
        })
      '';
    };
  };
}
