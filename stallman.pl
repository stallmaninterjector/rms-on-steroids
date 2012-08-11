#!/usr/bin/perl
#
#       interjection.pl
#
#   Run in a loop, automating the following sequence of actions:
#
#   1.  Scan front page of selected boards, collect list of threads.
#   2.  Scan thread for erroneous usage of "Linux", in the context of
#       describing a complete operating system.
#   3.  Interject with random Stallman picture and apt pasta, then sleep.
#   4.  At the end of each sweep, sleep for a few minutes before repeating
#       again, ad nauseum.

use warnings;
use strict;

use LWP::UserAgent;
use HTML::Form;
use Data::Dumper;
use DateTime;
use Captcha::reCAPTCHA;

my @threads;
my $output;
my $iteration = 0;
my %boards = ( g => 'zip' );                        # Hash containing boards to sweep.
my $log_file = "$ENV{HOME}/log_interjection";
my @ns_headers = (
    'User-Agent' => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.0.9) Gecko/2009050519 Iceweasel/3.0.9 (Debian-3.0.9-1)',
    'Accept-Charset' => 'iso-8859-1,*,utf-8',
    'Accept-Language' => 'en-US',
);

our $logging_enabled = 1;
our $pic_path = "/home/tom/rms/";            # Directory holding delcious Stallman pictures
our $scan_interval = 15;                           # Interval between each sweep of all boards
our $min_post_interval = 30;                        # Minimum delay after each individual interjection
our $post_interval_variation = 15;                  # Upper threshold of random additional delay after interjecting

our $total_posts = 0;
our @handsome_rms_pics = <$pic_path*>;
our @interjected;                                   # Track posts already responded to.
our $browser = LWP::UserAgent->new;
our $rms_pasta =<<FIN;
I'd just like to interject. What you're refering to as Linux, is in fact, GNU/Linux, or as I've recently taken to calling it, GNU plus Linux. Linux is not an operating system unto itself, but rather another free component of a fully functioning GNU system made useful by the GNU corelibs, shell utilities and vital system components comprising a full OS as defined by POSIX.

Many computer users run a modified version of the GNU system every day, without realizing it. Through a peculiar turn of events, the version of GNU which is widely used today is often called "Linux", and many of its users are not aware that it is basically the GNU system, developed by the GNU Project.

There really is a Linux, and these people are using it, but it is just a part of the system they use. Linux is the kernel: the program in the system that allocates the machine's resources to the other programs that you run. The kernel is an essential part of an operating system, but useless by itself; it can only function in the context of a complete operating system. Linux is normally used in combination with the GNU operating system: the whole system is basically GNU with Linux added, or GNU/Linux. All the so-called "Linux" distributions are really distributions of GNU/Linux.
FIN

open LOGGING, ">", $log_file or die $!;   # Log file location
print LOGGING "...logging to $log_file\n";



&log_msg("### ------------ interjection.pl ------------ ###");
&log_msg("###");
&log_msg("### \$pic_path:\t\t\t$pic_path");
&log_msg("### \$scan_interval:\t\t$scan_interval");
&log_msg("### \$min_post_interval:\t\t$min_post_interval");
&log_msg("### \$post_interval_variation:\t$post_interval_variation");
&log_msg("###");
&log_msg("### ----------------------------------------- ###");
&log_msg("Entering main loop...");

while (1) {
    &log_msg("Iteration $iteration");
    for (sort keys %boards) {
#       Aggregate listing of threads on front page of board,
#       pass each thread to &scan_posts to read.

        my ($srvr, $board) = ($boards{$_}, $_);
        my $board_url = "http://$boards{$board}.4chan.org/$board/imgboard.html";
        my $page = ($browser->get($board_url, @ns_headers))->content;
        $@ and print STDERR "$!\n";
        push @threads, $page =~ /<span id="nothread(\d+)">/g;

        &scan_posts("http://$srvr.4chan.org/$board/res/$_.html") for @threads;
    }

    &log_msg("Ending iteration $iteration. Will resume in $scan_interval seconds.\n");
    sleep($scan_interval);  # long pause between sweeps.
    $iteration++;
}
sub random_string(;$)
{
	my $length = shift || 8;
	my @char = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);

	my $string;
	$string .= $char[rand @char] while ($length--);

	return $string;
}
sub invoke_curl($)
{
	my ($options) = shift;

	my $command = "curl $options --progress-bar -f ";
	$output = `$command`;
	print "\n";

	return $?;
}
sub scan_posts {
    my $thread_url = shift;
    my %posts;
    my $page = ($browser->get($thread_url, @ns_headers))->content;


#   'name' attribute holds post number, post body is inside blockquote tags.
    %posts = $page =~
        /<a name="(\d+)"><\/a>.*?<blockquote>(.*?)<\/blockquote>/gs;


    for my $no (sort keys %posts) {
        $_ = $posts{$no}; 
               
#       Strip any remaining tags in post body.
        s/<.*?>.*?<\/.*?>//g;
        s/<.*?>//g;


#       If post contains 'Linux' or some obvious variant, not follwed
#       by 'kernel' **AND** no mention of GNU/Linux or GNU plus Linux, 
#       then respond.

        if (/L\s*                       # (L)inux
                (
                    i\W*n\W*u\W*     |  # L(inu)x
                    l\W*u\W*n\W*i\W* |  # (Luni)x So it does mistake "Unix" for incorrct usage of "Linux"
                    o\W*o\W*n\W*i\W*    # L(ooni)x
                )
            x                           # Linu(x)
            (?!\s+kernel)/ix
                && ! /GNU\s*(\/|plus|with|and|\+)\s*(Linux|Lunix)/i) {

            my $transpose = $1 =~ /u\s*n\s*i\s*/; 
            next if grep {$_ == $no} @interjected;

            &log_msg("URL: $thread_url post: $no");
            &log_msg("POST: $_");
            &log_msg("* Transposed! *") if $transpose;

            &interject($thread_url, $no, $page, $transpose);
            push @interjected, $no;
            $total_posts++;
            &log_msg("Interjection to post $no successful. Freedom delivered! Total posts: $total_posts");
        }
    }
}

sub interject {
#   Prepare pasta, fill form fields, find submit
#   button and click it, then sleep for a semi-
#   random amount of time.
	chomp(my $os = `uname -s`);
    return if (invoke_curl("http://www.google.com/recaptcha/api/challenge?k=6Ldp2bsSAAAAAAJ5uyx_lx34lJeEpTLVkP5k04qc"));
	
	my ($challenge) = $output =~ m/challenge : '([A-z0-9-]+)',/;
	my $outfile = random_string() . ".jpg";
	return if (invoke_curl("http://www.google.com/recaptcha/api/image?c=$challenge -o $outfile"));

	my $vericode;

		if ($os) {
			print "Enter the CAPTCHA here:\n";
			if ($os eq "Darwin") {
				system "qlmanage -p $outfile &> /dev/null &"; # Haven't tested this myself.
			} elsif ($os eq "Linux") {
				system "display $outfile &> /dev/null &";
			}
		} else {
			print "Open $outfile to see the CAPTCHA, then enter it here:\n";
		}

		$vericode = <>; # Wait for input

		if ($os) {
			system "pkill -f $outfile"; # Kills the program displaying the image
		}

	# Reset the referrer and delete the image
	unlink $outfile;

    my ($url, $post_no, $page, $transpose) = @_;
    my ($form, $interjection, $submit_button, $pic);

    $interjection = ">>$post_no\n\n" . $rms_pasta;
    $interjection =~ s/Linux/Lunix/g if $transpose;
    $pic = &select_pic;
    &log_msg("attached pic: $pic");  

    $form = HTML::Form->parse($page, $url);
    $form->value('com', $interjection);
    $form->value('recaptcha_challenge_field', $challenge);
    $form->value('recaptcha_response_field', $vericode);
    $form->value('upfile', $pic);
    $submit_button = (grep {$_->type eq 'submit'} $form->inputs)[0];
    $browser->request($submit_button->click($form));

    sleep($min_post_interval + rand($post_interval_variation)); 
}

sub log_msg {
    my $msg = shift;
    exit if ! $logging_enabled;
    my $now = DateTime->now;
    syswrite LOGGING, $now->ymd . " " . $now->hms . ": $msg\n" or die $!;
}

sub select_pic {
#   Select a file from the array and remove its entry.

    log "No more sexy RMS pictures left... ;_;\n" && exit if ! @handsome_rms_pics;
    return splice @handsome_rms_pics, int(rand(@handsome_rms_pics)), 1;
}
