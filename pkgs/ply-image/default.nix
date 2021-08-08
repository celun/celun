{ stdenv
, fetchgit
, libpng
, libdrm
, pkgconfig}:

stdenv.mkDerivation {
  pname = "ply-image";
  version = "2016-01-11";

  src = fetchgit {
    url = https://chromium.googlesource.com/chromiumos/third_party/ply-image;
    rev = "6cf4e4cd968bb72ade54e423e2b97eb3a80c6de9";
    sha256 = "152hh9r04hjqrpfqskqh876vlf5dfqiwx719nyjq1y2qr8a9akm7";
  };

  nativeBuildInputs = [
    pkgconfig
  ];
  buildInputs = [
    libpng
    (libdrm.override {
      withValgrind = false;
    })
  ];

  # Required for static build
  NIX_LDFLAGS = "-lz";

  installPhase = ''
    mkdir -p $out/bin
    cp -v src/ply-image $out/bin/
  '';
}
