# Generate binary disassembly, using objdump.
# After that make a try to put strings from .rodata section into code
# for easier code understanding.

use strict;

my $file = shift;

# find the .rodata section offset and size
my $sections = `objdump -h --section=.rodata $file | tail -2 | head -1`;

my @fields = split(/ +/, $sections);
my $size = hex('0x' . @fields[3]);
my $addrStart = hex('0x' . @fields[4]);
my $addrEnd = $addrStart + $size;
my $offset = hex('0x' . @fields[6]);

# read .rodata section into memory
open(BIN, $file) || die("Can't open file $file");
binmode(BIN);
seek(BIN, $offset, 0);
my $data;
my $read = read(BIN, $data, $size);

my $asm = `objdump -d $file`;
for my $line (split(/\n/, $asm)) {
  $line =~ s/(0x[0-9a-fA-F]+)/findString($1)/ge;
  $line =~ s/(movabs \$0x([^,]+)),/findChars($1, $2)/ge;
  print "$line\n";
}

sub findChars() {
  my ($instruction, $bytes) = @_;
  $bytes =~ s/(..)/toByte($1)/ge;
  return "$instruction('$bytes'),";
}

sub toByte() {
  my $hex = shift;
  return chr(hex('0x' . $hex));
}

sub findString() {
  my $addr = shift;
  my $addrD = hex($addr);
  if (($addrStart <= $addrD) && ($addrD < $addrEnd)) {
    $addr .= getString($addrD);
  }
  return $addr;
}

sub getString() {
  my $addr = shift;
  my $offset = $addr - $addrStart;
  my $subData = substr($data, $offset);
  my $string = unpack "Z*", $subData;
  $string =~ s/[\x00-\x1F]/_/g;
  return '("'.$string.'")';
}
