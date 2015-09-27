#!/usr/bin/env perl
use strict;
use warnings;

# Packages
use Mail::IMAPClient;   # For IMAP access into gmail - this is recommended over POP3 by Google
use IO::Socket::SSL;    # For secure connection to gmail
use Term::ReadKey;      # To read password from terminal without echoing onto promp 
use Email::MIME 1.901;  # To parse the mail

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Subroutines
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Read the password without echoing on screen
sub read_password {
  local $| = 1;
  print "Enter password: ";

  ReadMode "noecho";
  my $password = <STDIN>;
  ReadMode "restore";

  die "$0: unexpected end of input"
    unless defined $password;

  print "\n";
  chomp $password; 
  $password;
}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Connect to the IMAP server via SSL
my $socket = IO::Socket::SSL->new(
   PeerAddr => 'imap.gmail.com',
   PeerPort => 993,
  )
  or die "socket(): $@";

# Build up a client attached to the SSL socket.
# Login is automatic as usual when we provide User and Password
my $client = Mail::IMAPClient->new(
   Socket   => $socket,
   User     => 'username',      # Add username here
   Password => read_password,   # Read password from terminal
   #Password => 'userpassword', # Or just hard code it!
  )
  or die "new(): $@";

# Do something just to see that it's all ok
# This just prints all folder names
print "I'm authenticated\n" if $client->IsAuthenticated();
my @folders = $client->folders();
# print join("\n* ", 'Folders:', @folders), "\n";

# Check no. of unread mails in each folder
foreach my $f ($client->folders) {
        print   "The $f folder has ",
                $client->unseen_count($f)||0, 
                " unseen messages.\n";          
}

# Select the appropriate folder - such as "INBOX". Here it is "dvlsi_assign_01"
$client->select("dvlsi_assign_01")
  or die "$0: select dvlsi_assign_01: ", $client->LastError, "\n";

# Add some search criteria
my $search_str = "DVLSI_ASSIGNMENT_01";
#my @messages = $client->search(SUBJECT => $search_str);                # Subject must contain search string
my @messages = $client->search(SUBJECT => $search_str, 'UNSEEN');       # That and message shd be unread/unseen
die "$0: search: $@" if defined $@;


foreach my $id (@messages) {
  die "$0: funky ID ($id)" unless $id =~ /\A\d+\z/;

  my $str = $client->message_string($id)
    or die "$0: message_string: $@";

  my $n = 1;
  Email::MIME->new($str)->walk_parts(sub {
    my($part) = @_;
    return unless $part->content_type =~ /\bname="([^"]+)"/;    # " grr...
    
    my $name = "./$search_str-$id-" . $n++ . "-$1";             # Modification of the file-name
    print "$0: writing $name...\n";
    open my $fh, ">", $name
      or die "$0: open $name: $!";
    print $fh $part->content_type =~ m!^text/!
                ? $part->body_str
                : $part->body
      or die "$0: print $name: $!";
    close $fh
      or warn "$0: close $name: $!";

  });
}


# Say bye
$client->logout();

#Acknowledgement pages:
#http://stackoverflow.com/questions/2453548/how-can-i-download-imap-mail-attachments-over-ssl-and-save-them-locally-using-pe
