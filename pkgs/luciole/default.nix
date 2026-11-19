{ pkgs, buildRevision ? "0b37f2cc760c241ce2cf78dbdc4744f18a5b66b7" }:
with pkgs;
let
  lib = pkgs.lib;
  rev = buildRevision;
  sha256 = "sha256-M0fW1rZWz3cVIWDtnWUx4GnnzoWOEJUa4bhfqKLyTRs=";
  stb' = stb.overrideAttrs (_: {
    version = "unstable-2025-10-26";
    src = fetchFromGitHub {
      owner = "nothings";
      repo = "stb";
      rev = "f1c79c02822848a9bed4315b12c8c8f3761e1296";
      hash = "sha256-BlyXJtAI7WqXCTT3ylww8zoG0hBxaojJnQDvdQOXJPE=";
    };
  });

  pixbufWithGlycin = gdk-pixbuf.overrideAttrs (previous: {
    version = "2.44.6";
    src = fetchurl {
      url = "https://download.gnome.org/sources/gdk-pixbuf/2.44/gdk-pixbuf-2.44.6.tar.xz";
      hash = "sha256-FAwtC4mfz4U+6SsmNzydwijbzeCCCkJGaT9DKKJ0Zvo=";
    };
    buildInputs = (previous.buildInputs or [ ]) ++ [ libglycin glycin-loaders shared-mime-info ];
    preBuild = (previous.preBuild or "") + ''
      export XDG_DATA_DIRS="${glycin-loaders}/share:${shared-mime-info}/share:''${XDG_DATA_DIRS:-}"
    '';
    mesonFlags = builtins.filter (
      flag: !(lib.any (name: lib.hasPrefix "-D${name}=" flag) [
        "glycin" "builtin_loaders" "png" "jpeg" "gif" "tiff" "others" "legacy_xpm"
      ])
      ) previous.mesonFlags
      ++ [
        "-Dglycin=enabled"
        "-Dbuiltin_loaders=glycin"
        "-Dpng=disabled"
        "-Djpeg=disabled"
        "-Dgif=disabled"
        "-Dtiff=disabled"
        "-Dothers=disabled"
        "-Dlegacy_xpm=disabled"
      ];
  });

  svgWithGlycin = librsvg.override { gdk-pixbuf = pixbufWithGlycin; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "luciole";
  version = rev;

  src = fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "luciole";
    rev = rev;
    sha256 = sha256;
  };

  nativeBuildInputs = [ meson ninja pkg-config python3 wayland-scanner autoAddDriverRunpath makeWrapper ];
  nativeCheckInputs = [ dbus glib ];

  buildInputs = [
    wayland
    wayland-protocols
    libglvnd
    libxkbcommon
    freetype
    fontconfig
    cairo
    glib
    curl
    libxml2
    pango
    harfbuzz
    libpng
    libarchive
    xz
    acl
    libwebp
    pixbufWithGlycin
    svgWithGlycin
    glycin-loaders
    stb'
    nlohmann_json
    tomlplusplus
  ];

  preConfigure = lib.optionalString stdenv.cc.isGNU ''
    export AR="${stdenv.cc.cc}/bin/gcc-ar"
    export RANLIB="${stdenv.cc.cc}/bin/gcc-ranlib"
  '';

  mesonBuildType = "release";

  postFixup = ''
    wrapProgram "$out/bin/luciole" \
      --prefix PATH : "${lib.makeBinPath [ xdg-terminal-exec ffmpeg ffmpegthumbnailer poppler-utils _7zz ]}" \
      --suffix GIO_EXTRA_MODULES : "${lib.makeSearchPath "lib/gio/modules" [ gvfs glib-networking dconf.lib ]}" \
      --suffix XDG_DATA_DIRS : "${glib.getSchemaDataDirPath gsettings-desktop-schemas}:${lib.makeSearchPath "share" [ adwaita-icon-theme shared-mime-info glycin-loaders ]}"
  '';

  mesonFlags = [ "-Dtests=disabled" (lib.mesonOption "build_revision" buildRevision) ];

  passthru.glycinLoaders = glycin-loaders;

  meta = with lib; {
    description = "Luciole, a native Wayland file manager using Noctalia rendering and controls (in development)";
    homepage = "https://github.com/noctalia-dev/luciole";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = finalAttrs.pname;
  };
})
