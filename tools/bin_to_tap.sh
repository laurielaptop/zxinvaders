#!/usr/bin/env sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
  echo "Usage: $0 <input.bin> <output.tap> [load_addr] [name] [entry_addr]"
  echo "Example: $0 build/zxinvaders.bin dist/zxinvaders.tap 32768 ZXINVADERS 32768"
  exit 1
fi

IN_FILE="$1"
OUT_FILE="$2"
LOAD_ADDR="${3:-32768}"
TAP_NAME="${4:-ZXINVADERS}"
ENTRY_ADDR="${5:-$LOAD_ADDR}"

if [ ! -f "$IN_FILE" ]; then
  echo "Input file not found: $IN_FILE"
  exit 1
fi

# Build a Spectrum TAP with:
# 1) BASIC autostart loader program (line 10)
# 2) CODE header + data block
perl -e '
use strict;
use warnings;

my ($in, $out, $load, $name, $entry) = @ARGV;
open my $fh, "<:raw", $in or die "Cannot open input: $!\n";
local $/;
my $data = <$fh>;
close $fh;

my $len = length($data);
die "Input too large for TAP header length field\n" if $len > 65535;

for my $n ($load, $entry) {
  die "Address out of range (0..65535): $n\n" if $n < 0 || $n > 65535;
}

$name = substr($name, 0, 10);
$name .= " " x (10 - length($name));

sub tap_block {
  my ($payload) = @_;
  my $chk = 0;
  $chk ^= $_ for unpack("C*", $payload);
  my $blk = $payload . pack("C", $chk);
  return pack("v", length($blk)) . $blk;
}

sub header_payload {
  my ($type, $nm, $length, $p1, $p2) = @_;
  return pack("C C a10 v v v", 0x00, $type, $nm, $length, $p1, $p2);
}

# BASIC loader line:
# 10 LOAD "" CODE : RANDOMIZE USR <entry>
# Numbers in program lines include CHR$ 14 + 5-byte numeric form.
my $entry_text = "$entry";
my $entry_num = pack("C C C C C C", 0x0E, 0x00, 0x00, ($entry & 0xFF), (($entry >> 8) & 0xFF), 0x00);

my $line = join("",
  chr(0xEF), " ", chr(34), chr(34), " ", chr(0xAF),
  " : ",
  chr(0xF9), " ", chr(0xC0), " ", $entry_text, $entry_num,
  chr(0x0D)
);

my $line_len = length($line);
my $basic_data = pack("n v", 10, $line_len) . $line;
my $basic_len = length($basic_data);

my $basic_header = header_payload(0, $name, $basic_len, 10, $basic_len);
my $basic_payload = pack("C", 0xFF) . $basic_data;

my $code_header = header_payload(3, $name, $len, $load, 32768);
my $code_payload = pack("C", 0xFF) . $data;

my $tap = "";
$tap .= tap_block($basic_header);
$tap .= tap_block($basic_payload);
$tap .= tap_block($code_header);
$tap .= tap_block($code_payload);

open my $outfh, ">:raw", $out or die "Cannot open output: $!\n";
print {$outfh} $tap;
close $outfh;
' "$IN_FILE" "$OUT_FILE" "$LOAD_ADDR" "$TAP_NAME" "$ENTRY_ADDR"

echo "Built $OUT_FILE from $IN_FILE"
