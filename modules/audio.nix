{ config, pkgs, lib, ... }:
{
  # Audio module: enable modern PipeWire stack and disable legacy services.
  # This file configures system services related to audio and explains
  # each setting briefly.

  # rtkit provides realtime privileges for audio processes (low-latency).
  security.rtkit.enable = true;

  # Disable legacy PulseAudio service to avoid conflicts with PipeWire.
  services.pulseaudio.enable = false;

  # Enable PipeWire and related backends. Each attribute toggles support
  # for a particular compatibility layer or backend.
  services.pipewire = {
    enable = true;                  # turn on PipeWire system service
    alsa.enable = true;             # ALSA compatibility via PipeWire
    alsa.support32Bit = true;       # include 32-bit ALSA support for legacy apps
    pulse.enable = true;            # provide PulseAudio compatibility layer
    # JACK support: install `pkgs.pipewire.jack` and use `pw-jack` in the
    # session, instead of enabling the deprecated impurity switch.
  };
}
