#!/usr/bin/env sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <input.bin> <output.tap> [load_addr] [name]"
  echo "Example: $0 build/zxinvaders.bin dist/zxinvaders.tap 32768 ZXINVADERS"
  exit 1
fi

IN_FILE="$1"
OUT_FILE="$2"
LOAD_ADDR="${3:-32768}"
TAP_NAME="${4:-ZXINVADERS}"

if [ ! -f "$IN_FILE" ]; then
  echo "Input file not found: $IN_FILE"
  exit 1
fi

# Build a standard Spectrum CODE TAP with a header block and a data block.
perl -e '
use strict;
use warnings;

my ($in, $out, $load, $name) = @ARGV;
open my $fh, "<:raw", $in or die "Cannot open input: $!\n";
local $/;
my $data = <$fh>;
close $fh;

my $len = length($data);
die "Input too large for TAP header length field\n" if $len > 65535;

$name = substr($name, 0, 10);
$name .= " " x (10 - length($name));

my $type = 3; # CODE
my $param2 = 32768;

my $header_payload = pack("C C a10 v v v", 0x00, $type, $name, $len, $load, $param2);
my $header_chk = 0;
$header_chk ^= $_ for unpack("C*", $header_payload);
my $header_block = $header_payload . pack("C", $header_chk);

my $data_payload = pack("C", 0xFF) . $data;
my $data_chk = 0;
$data_chk ^= $_ for unpack("C*", $data_payload);
my $data_block = $data_payload . pack("C", $data_chk);

open my $outfh, ">:raw", $out or die "Cannot open output: $!\n";
print {$outfh} pack("v", length($header_block));
print {$outfh} $header_block;
print {$outfh} pack("v", length($data_block));
print {$outfh} $data_block;
close $outfh;
' "$IN_FILE" "$OUT_FILE" "$LOAD_ADDR" "$TAP_NAME"

echo "Built $OUT_FILE from $IN_FILE"
