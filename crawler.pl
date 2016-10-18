# I427 Fall 2013, Assignment 2
#   Code authors: Anna Eilering
#   author email: annaeile@indiana.edu
#
#   based on skeleton code by D Crandall
#
#!/usr/bin/perl
use warnings;
use strict;

# these packages (and others! might be helpful). Check out the documentation online.
use URI::Escape;
use HTML::LinkExtor;
use LWP::RobotUA;
use HTTP::Request::Common qw(POST);
use Path::Class;
use List::Util qw(max);
use URI::URL;


# function that takes a URL as a parameter, retrieves that URL from the network, 
# and returns a string containing the HTML contents of the page
#
sub retrieve_page {
    my $url = $_[0];
    my $ua = $_[1];

# This is heavily borrowed from the awesome tutorials on perlmeme.org:
# I like seperating my url request from the $ua->request call
    my $req = POST $url, [];
    my $res = $ua->request($req);
    if ($res->is_success) {
	#print "Successfully accessed using $req\n";
	return $res->content;
    } else {
	#print "Failed to access, status: $res->status_line\n";
	return "";
    }

    # return $res->content;
    # fill in code here!
}


# function that takes a string filled with HTML code and a string representing the current URL the bot is
# at as parameters, and then returns a list of that page's abosulutized hyperlinks (URLs)
#
# This forum post was important to me figuring out how LinkExtor works:
# http://www.perlmonks.org/?node_id=188518
sub find_links {
    my $html_code = $_[0];
    my $curr_url = $_[1];

    # I really don't want to visit links that are just pictures and such, only websites and similar
    # Considering how slow the $ua->request function is at the moment anything I can strip here
    # will improve speed down the line
    my %ignored_stuff = (
                    '.png','',
                    '.jpg','',
                    '.jpeg','',
                    '.gif','',
                    '.tiff','',
                    '.bmp','',
                    '.raw','',
                    '.js','',	
                    'mailto:','',
#                    '.pgm/','',
#                    '.pbm/','',
#                    '.pnm/','',
    );


    #Not giving any args here. Absolutization is done by my make_absolute_url function.  
    my $p = HTML::LinkExtor -> new (undef, $curr_url);
    $p -> parse ($html_code);
    my @links = $p->links();
    my @results;
    foreach my $link (@links){
	my $working = normalize_url(@$link[2]);
	if(!($working =~ /.*mailto:.*/))
	{

	    my ($ext) = $working =~ /(\.[^.]+)$/;
	    
	    # this check confirms that a value for $ext was found, Otherwise we can just dump this
	    # url into the results list
	    if($ext)
	    {

#	    print $working . "\n";
#	    print "I think the extension is: " . $ext . "\n";
#	my $stupid = 0;
#	($stupid) = $working =~ /.*(mailto:).*/;
#	print $stupid . "\n";
		if (!(exists $ignored_stuff{$ext}))
		{  
		    push(@results, $working);
		}
#	print normalize_url(@$link[2]) . "\n";
		
	    } else {
		push(@results, $working);
	    }
	}
    }
    return @results;
}



# function that takes as a parameter the name of a file containing some URLs, one per line, 
#  and returns the set of URLs as a perl list of strings.
#
sub read_urls_file {
    my $filename = $_[0];

    die "Can't open file $filename!" unless open(FILE, $filename);
    my @lines=<FILE>;
    close(FILE);

    my @results;
    foreach my $line (@lines){
		chomp($line);
		my $clean = normalize_url($line);
		push(@results, $clean);
    }
    
    return @results;
}


# function that takes a URL and returns a normalized URL 
#  e.g. each of the following strings:
#
#   http://www.cnn.com/TECH 
#   http://WWW.CNN.COM/TECH/ 
#   http://www.cnn.com/TECH/index.html 
#   http://www.cnn.com/bogus/../TECH/
#
#  would return the following:
#
#   http://www.cnn.com/TECH/

sub normalize_url {
    my $grossURL = $_[0];
    

    ###########################################################
    # NORMALIZATION THAT PRESERVE SEMANTICS
    # per http://en.wikipedia.org/wiki/URL_normalization
    
    # step 1 lowercasize it
    $grossURL = make_lowercase($grossURL);

    # step 2 Capitalize letters in escape sequences
    $grossURL = cap_escape_sequenced($grossURL);

    # step 3 decoding percent-encoded octets of unreserved characters
    # Going to use URI for this one!
#    $grossURL = uri_unescape($grossURL);
    # doing this breaks all sorts of interesting stuff
    

    # step 4 removing the default port
    $grossURL = remove_default_port($grossURL);


    
    ###########################################################
    # NORMALIZATION THAT USUALLY PRESERVE SEMANTICS
    # per http://en.wikipedia.org/wiki/URL_normalization
 
    # Many pages are not OK with this. 
    # step 1 adding trailing /
#    $grossURL = add_trailing_whack($grossURL);    
    $grossURL = remove_trailing_whack($grossURL);

    # step 2 removing dot-segments
    $grossURL = dot_remover($grossURL);


    ###########################################################
    # NORMALIZATION THAT CHANGE SEMANTICS
    # per http://en.wikipedia.org/wiki/URL_normalization

    # step 1 removing directory index
    $grossURL = remove_directory_index($grossURL);

    # step 2 removing the fragment
    $grossURL = fragment_remover($grossURL);

    # step 3 replacing IP with domain name
    # I'm up in the air about doing this. I'm tempted to use IP to keep track of what websites I've
    # visited, this would let me use a search tree in order to see who I have visited. In that case
    # I may, in stead, translate domain names to IP addresses 

    # step 4 limiting protocols
    $grossURL = limit_protocols($grossURL);

    # step 5 removing duplicate slashes
    $grossURL = remove_duplicate_whacks($grossURL);
    #print $grossURL . "\n";
    # step 6 adding www to all websites as the first domain level assuming the webaddress is not an IP
    $grossURL = add_www($grossURL);

    # step 7 sorting the query parameters this also removes trailing ? if there are no params
    $grossURL = sort_query_params($grossURL);




    
    return $grossURL

    

    # fill in code here!
}


# function that takes a relative or absolute URL and a base URL, and returns an absolute URL
#
#  e.g. make_absolute_url("index.html", "http://www.cnn.com/") should return the string "http://www.cnn.com/index.html"
#       make_absolute_url("gov.html", "http://www.cnn.com/links/index.html") should return the string "http://www.cnn.com/links/gov.html"
#       make_absolute_url("http://www.whitehouse.gov/", "http://www.cnn.com") should return "http://www.whitehouse.gov/"
sub make_absolute_url {
    my $page = $_[0];
    my $url = $_[1];
    # fill in code here!

    # is my page already an absolute URL?
    if( $page =~ /http\:\/\//){
	# it is! just return it 
	return $page;
    } else {

	# it isn't, gotta do some stuff!
	$url = remove_cur_page($url);
	$url = $url . "/" . $page;
	$url = remove_duplicate_whacks($url);
	return $url;	
    }
}


############
# function that takes a url as a string, and returns a string that should contain only the first portion
#   of the URL(the URL less the actuall page we are on currently)
#
sub remove_cur_page{
    my $word = $_[0];

    # the targeted page should be the last thing in the string
#    my @parts = split(/\//, $word);

    $word=~ s/(\w+)\/(\w+.\w+)$/$1/;


#    my $length = @parts;
#    print $length;
#    my $page = $parts[length - 1];
#    print $page;
    #i){
#	$word =~ s/\Q$page//;
#	$word =~ s/\/\/$/\//;
#    }

    return $word;

}



#
# You'll likely need other functions. Add them here!
#





############
# function that takes a string, and converts all the uppercase letters
#   into lowercase letters
#
sub make_lowercase {
    my $word = $_[0];
    my $result = lc($word);

    return $result;
}

###########
# function that takes a string, typically a URL, that has presumably been lowercasized previously
# and converts all lowercase letters after %(escape characters) to upper case
#
sub cap_escape_sequenced{
    my $word = $_[0];
    
    $word =~ s/\%([a-z])/\%\u$1/g;  #/g will do it multiple times
    
    return $word;
}


###########
# function that takes a string, typically a URL, and removes the default port which should be the first 
# instance of :####/ in the string
#
sub remove_default_port{
    my $word = $_[0];
    
    # there should only be 1 instance of a default port in a URL and it should look something like
    # http:\\URL.COM:PORT#\<restofURLcrap>
    # I want to remove the :PORT# portion and return the cleaned URL

    $word =~ s/:[0-9]{1,5}\//\//;
    return $word;
}


###########
# function that takes a string, typically a URL, and removes the trailing whack(/)
# NOTE - this is in use instead of add_trailing_whack in normalization as websites are fine if the whatck
# is missing but if there is an extra whack they sometimes don't recognize the URL
#
sub remove_trailing_whack{
    my $word = $_[0];

    $word =~ s/\/$//;

    return $word;
}


###########
# function that takes a string, typically a URL, and adds a trailing / is one is not already
# existent
# NOTE - not in use for normalization, this seems to break many websites' 404 redirection methods
#
sub add_trailing_whack{
    my $word = $_[0];

    # Adding trailing / Directories are indicated with a trailing slash and should be included in URLs.
    # example:  http://www.example.com/alice → http://www.example.com/alice/

    if (!($word =~ /\/$/)){
	$word = $word . "\/";
    }

    return $word;
}

###########
# function that takes a string, typically a URL, and removes any situations that look like /..../ or similar
# as these are extraneous
#
sub dot_remover{
    my $word = $_[0];

    # The segments “..” and “.” can be removed from a URL according to the algorithm described in RFC 3986 
    # (or a similar algorithm). Example:
    # http://www.example.com/../a/b/../c/./d.html → http://www.example.com/a/c/d.html

    # I want to match every case of /... and remove it trusting that dots will always be followed by a / 
    # which will replace the removed /
    $word =~ s/\/\.+//g;

    return $word;
}

###########
# function that takes a string, typically a URL, and removes the directory index if it is 
# a common index name/type
#
sub remove_directory_index{
    my $word = $_[0];
    
    # This is inspired by the root from the URL normalize module which can be found:
    # http://search.cpan.org/~toreau/URL-Normalize/lib/URL/Normalize.pm
    # by user toreau who is slightly my hero for writing this

    # well-known directory indexes
    my %indexes = (
	            'default.asp','',
	            'default.aspx','',
	            'index.cgi','',
	            'index.htm','',
	            'index.html','',
	            'index.php','',
	            'index.php5','',
	            'index.pl','',
	            'index.shtml','',
	    );

    # the targeted page should be the last thing in the string
    my @parts = split(/\//, $word);
    my $page = $parts[-1];
#   print $page;
    if($page){
		if (exists $indexes{$page}){
		$word =~ s/\Q$page//;
		$word =~ s/\/\/$/\//;
		}
	}
    return $word;

}


###########
# function that takes a string, typically a URL, and removes any fragments that look like #fragment 
# 
#
sub fragment_remover{
    my $word = $_[0];

    # The fragment component of a URL is never seen by the server and can sometimes be removed. Example:
    # http://www.example.com/bar.html#section1 → http://www.example.com/bar.html
    $word =~ s/#.+$//;

    return $word
}


###########
# function that takes a string, typically a URL, and changes https -> http
# 
#
sub limit_protocols{
    my $word = $_[0];

    # Limiting protocols. Limiting different application layer protocols. For example, the “https” 
    # scheme could be replaced with “http”. Example:
    # https://www.example.com/ → http://www.example.com/

    # I was going to do this with a hash table but some quick googling showed that the only two that I
    # would have to worry about was HTTPS -> HTTP and SFTP/FTPS->FTP(and FTP sites should not be visited)
    $word =~ s/^https/http/;

    return $word;

}

###########
# function that takes a string, typically a URL, and removes duplicate whacks
# 
#
sub remove_duplicate_whacks{
    my $word = $_[0];

    $word =~ s/([^:])\/\//$1\//g;
    return $word;
}

###########
# function that takes a string, typically a URL, and if the URL address is not an IP address and does not
# already have www, adds www to the URL
#
sub add_www{
    my $word = $_[0];

    if ((!($word =~ /^http:\/\/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.\d{1,3}/)) and
	(!($word =~ /^http:\/\/www/))){
	    $word =~ s/^http:\/\//http:\/\/www./
    }

    return $word
}


###########
# function that takes a string, typically a URL, and returns a string where any query parameters have been
# sorted alphabetically
#
sub sort_query_params{
    my $word = $_[0];
    
    # first let's make sure there's even a query param in this thing, if there is, let's got nuts!
    # otherwise we skip over this.
    if( $word =~ /\?/){
	
	# step 1 pull our queries out and dump them into an array
	my @tempqs = split(/\?/, $word);
	if( $word =~ /\?.+/){
	    my @qs = split(/\&/,$tempqs[-1]);
	    #print $qs[-1];

	    # step 2 sort them
	    @qs = sort @qs;
	    #print $qs[-1];

	    # step 3 jam them back onto the rest of the URL
	    #$word = "";
	    $word = "$tempqs[0]?";
	    foreach my $param (@qs){
		$word = $word . "&" . $param;
	    }
	} else {
	    $word = $tempqs[0];
	}
    } 
    return $word;
}

###########
# function that takes a string, a targed director and desired file name and saves that string to a file
# with that name and in that specified directory
#
sub save_string_to_file{
    my $output_directory = $_[0];
    my $file_name = $_[1];
    my $string = $_[2];

    # Inspired by some of the instructions here http://learn.perl.org/examples/read_write_file.html
    my $dir = dir($output_directory);
    my $file = $dir->file($file_name);
    
    my $file_handle = $file->openw();
    $file_handle->print($string);

}


######################################################################################################
# WORKHORSE FUNCTION FOR DFS SEARCH
#
# DFS using a stack concept
sub dfs{
    my $ua = $_[0];
    my $seeds_file = $_[1];
    my $max_pages = $_[2];
    my $output_dir = $_[3];

    my $file_id;

    my @stack = read_urls_file($seeds_file);
    print "Loaded the following seed URLS from $seeds_file\n";
    print @stack;
    print "\n";


    # I want to keep track of pages I have visited
    my %visited;

    # I need to record the file_id, the URL it relates to and the time it was visited to an
    # index.dat
    # gotta set up the index.dat file
    my $dir = dir();
    my $file = $dir->file("index.dat");

    my $file_handle = $file->openw();

    while ($max_pages > 0) # Do the preceeding code until the queue is empty
    {
	if(scalar(@stack > 0)){
	    # get the nodes from the end of the array
	    my $URL = shift(@stack);

		# first check to make sure we don't have some weird empty string, potentially from a malformed seed url file
		if(not($URL)){
			$URL = shift(@stack);
		}
		
	    # check to see if the node has been seen before
	    if (!(exists $visited{$URL}))
	    {
		#print "Current stack:\n @stack\n\n";
		print "!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!\n";
		print "Checking out $URL\n";
		print "Number of URLs left to check: $max_pages\n";
        
		# the file ID will be the time since the epoch that the URL was first accessed
		# this will be placed within the value for the key in the visited hash
		# this is convenient as this should be unique(barring time travel)
		my $this_time = time();
		$file_id = $this_time . '.html';
#	    print $file_id . "\n";
		
		# put the unseen node into the seen hash table
		$visited{$URL} = $file_id;

		# get the frontier from each node
		# this gets the raw HTML code from the website
		my $results = retrieve_page($URL, $ua);

		# dump the results(the raw HTML) into a file named using the $file_id in the
		# given output directory
		save_string_to_file($output_dir, $file_id, $results);

		my $bookkeeping = $file_id . "\t" . gmtime($this_time) . "\t" . $URL . "\n"; 
		$file_handle->print($bookkeeping);


		# this gets the links in the raw HTML code and dumps it into an array
		my @frontier = find_links($results, $URL);
		
		@stack = (@frontier,@stack);
		# print @stack , "\n\n";
		$max_pages = $max_pages - 1;

	    }
	} else {
		print "Ran out of stack!\n\n";
		
		# If this triggers then that means we still have time to visit more pages but
		# the stack is empty! 
		#foreach my $key ( keys %visited){
		#    push(@stack, $key);
		#}

		# Let's pull a random key from the hash table and see if there are new URLs in it!
		my @hash_keys    = keys %visited;

		my $URL = $hash_keys[rand @hash_keys];
		$file_id = $visited{$URL};
		print $URL . "    " . $file_id . "\n";
		 #print "Current stack:\n @stack\n\n";

		#print "Current stack:\n @stack\n\n";
		print "!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!\n";          
		print "Checking out $URL\n";
		print "Number of URLs left to check: $max_pages\n";

		# the file ID will be the time since the epoch that the URL was first accessed
		# this will be placed within the value for the key in the visited hash
		# this is convenient as this should be unique(barring time travel)
		my $this_time = time();
		#$file_id = $this_time . '.html';
#           print $file_id . "\n";

		# put the unseen node into the seen hash table
		$visited{$URL} = $file_id;

		# get the frontier from each node
		# this gets the raw HTML code from the website
		my $results = retrieve_page($URL, $ua);

		# dump the results(the raw HTML) into a file named using the $file_id in the
		# given output directory
		save_string_to_file($output_dir, $file_id, $results);

		my $bookkeeping = $file_id . "\t" . gmtime($this_time) . "\t" . $URL . "\n";
		$file_handle->print($bookkeeping);


		# this gets the links in the raw HTML code and dumps it into an array
		my @frontier = find_links($results, $URL);

		@stack = (@frontier,@stack);
		# print @stack , "\n\n";
		$max_pages = $max_pages - 1;
	    
	}
    }
}



######################################################################################################
# WORKHORSE FUNCTION FOR BFS SEARCH
#
# BFS using a queue concept
sub bfs{
    my $ua = $_[0];
    my $seeds_file = $_[1];
    my $max_pages = $_[2];
    my $output_dir = $_[3];

    my $file_id;

    my @stack = read_urls_file($seeds_file);
    print "Loaded the following seed URLS from $seeds_file\n";
    print @stack;
    print "\n";


    # I want to keep track of pages I have visited
    my %visited;

    # I need to record the file_id, the URL it relates to and the time it was visited to an
    # index.dat
    # gotta set up the index.dat file
    my $dir = dir();
    my $file = $dir->file("index.dat");

    my $file_handle = $file->openw();

    while ($max_pages > 0) # Do the preceeding code until the queue is empty
    {
	if(scalar(@stack > 0)){
	    # get the nodes from the end of the array
		# first check to make sure we don't have some weird empty string, potentially from a malformed seed url file
	    my $URL = pop(@stack);
		if(not($URL)){
			$URL = pop(@stack);
		}
		
	    # check to see if the node has been seen before
	    if (!(exists $visited{$URL}))
	    {
		#print "Current stack:\n @stack\n\n";
		print "!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!\n";
		print "Checking out $URL\n";
		print "Number of URLs left to check: $max_pages\n";
        
		# the file ID will be the time since the epoch that the URL was first accessed
		# this will be placed within the value for the key in the visited hash
		# this is convenient as this should be unique(barring time travel)
		my $this_time = time();
		$file_id = $this_time . '.html';
#	    print $file_id . "\n";
		
		# put the unseen node into the seen hash table
		$visited{$URL} = $file_id;

		# get the frontier from each node
		# this gets the raw HTML code from the website
		my $results = retrieve_page($URL, $ua);

		# dump the results(the raw HTML) into a file named using the $file_id in the
		# given output directory
		save_string_to_file($output_dir, $file_id, $results);
	    
		

		my $bookkeeping = $file_id . "\t" . gmtime($this_time) . "\t" . $URL . "\n"; 
		$file_handle->print($bookkeeping);
		# print $bookkeeping;

		# this gets the links in the raw HTML code and dumps it into an array
		my @frontier = find_links($results, $URL);
		
		@stack = (@frontier,@stack);
		# print @stack , "\n\n";
		$max_pages = $max_pages - 1;

	    }
	} else {
		print "Ran out of stack!\n\n";
		
		# If this triggers then that means we still have time to visit more pages but
		# the stack is empty! 
		#foreach my $key ( keys %visited){
		#    push(@stack, $key);
		#}

		# Let's pull a random key from the hash table and see if there are new URLs in it!
		my @hash_keys    = keys %visited;

		my $URL = $hash_keys[rand @hash_keys];
		$file_id = $visited{$URL};
		print $URL . "    " . $file_id . "\n";
		 #print "Current stack:\n @stack\n\n";

		#print "Current stack:\n @stack\n\n";
		print "!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!\n";
		print "Checking out $URL\n";
		print "Number of URLs left to check: $max_pages\n";

		# the file ID will be the time since the epoch that the URL was first accessed
		# this will be placed within the value for the key in the visited hash
		# this is convenient as this should be unique(barring time travel)
		my $this_time = time();
		#$file_id = $this_time . '.html';
#           print $file_id . "\n";

		# put the unseen node into the seen hash table
		$visited{$URL} = $file_id;

		# get the frontier from each node
		# this gets the raw HTML code from the website
		my $results = retrieve_page($URL, $ua);

		# dump the results(the raw HTML) into a file named using the $file_id in the
		# given output directory
		save_string_to_file($output_dir, $file_id, $results);

		my $bookkeeping = $file_id . "\t" . gmtime($this_time) . "\t" . $URL . "\n";
		$file_handle->print($bookkeeping);


		# this gets the links in the raw HTML code and dumps it into an array
		my @frontier = find_links($results, $URL);

		@stack = (@frontier,@stack);
		# print @stack , "\n\n";
		$max_pages = $max_pages - 1;
	    
	}
    }
}


######################################################################################################
# Worker functions for bestfirst. Most of these functions are taken whole hog from my A1
# assignment and several were given as part of that assignment

############
# function that takes a filename as a parameter, and returns a Perl list
#   of all the `words' in the file. (By `word', we mean space-delimited
#   symbols -- there still might be punctuation, numbers, nonsense words,
#   etc.)
#
# This function should work as written but feel free to modify it. This is different from the
# function I wrote as it splits each word into an entry in the list. This was given in HW1
#
sub read_file_into_list {
    my $filename = $_[0];

    die "Can't open file $filename!" unless open(FILE, $filename);
    my @lines=<FILE>;
    my @words=();

    foreach my $i ( @lines ) {
        push(@words, split(/ /, $i))
    }
    close(FILE);

    return @words;
}

############
# function that takes a list of words, and removes all of the punctuation
#   from each word, returning a new list of "cleaner" words
#
sub remove_punctuation {
    my @words = @_;
    my @result = @words;

    for my $word (@result) {
        chomp($word);
        $word =~ s/[[:punct:]]//g;
    }

    return @result;
}

############
# function that takes a list of words, and converts all the uppercase letters
#   into lowercase letters
#
sub make_list_lowercase {
    my @words = @_;
    my @result = @words;

    for my $word (@result) {
        $word =~ tr/A-Z/a-z/;
    }

    return @result;
}







######################################################################################################
# WORKHORSE FUNCTION FOR BeststFirst SEARCH
#
# Best First behaves as follows:
#	(1) after downloading a page but before extracting links, the program should compute the spam score of the page, using your code from Assignment 1;
#	(2) when adding links to the request queue, the program should also store the spam score of the page on which those links were found; 
#	(3) when choosing the next page to retrieve from the request queue, the crawler should choose the page with the lowest spam score.
#
#	I will use a hash for the request queue
sub bestfirst{
    my $ua = $_[0];
    my $seeds_file = $_[1];
    my $max_pages = $_[2];
    my $output_dir = $_[3];
	my $known_spam_file = $_[4];
	my $known_nonspam_file = $_[5];

    my $file_id;

	######
	# Doing some processing on the known spam and known nonspam files since these will not be
	# changing over the course of the program
	
	# Let's dump our known spam and known non-spam into lists
	my @spam_words = read_file_into_list($known_spam_file);
	my @notspam_words = read_file_into_list($known_nonspam_file);

	# convert all of the word lists to lower case, and remove punctuation.
	@spam_words = make_list_lowercase(remove_punctuation(@spam_words));
	@notspam_words = make_list_lowercase(remove_punctuation(@notspam_words));

	# Let's make a hash table where the word is the key and the value
	# is the number of times the words shows up in the document
	my %spamwords_count;
	for my $spamword (@spam_words)
	{
		$spamwords_count{$spamword}++;
	}
	my %notspamwords_count;
	for my $notspamword (@notspam_words)
	{
		$notspamwords_count{$notspamword}++;
	}
	
	
	# Read in the URLs from the seed and dump them into a temporary stack
    my @temp_stack = read_urls_file($seeds_file);
    print "Loaded the following seed URLS from $seeds_file\n";
    print @temp_stack;
    print "\n";
	
	my %req_queue;
	
	# This is going to populate the req_queue with the seed URLs
	# This is similar, but different in some fundamental ways, from how the rest of 
	# all URLs will be treated.
	for my $page(@temp_stack){
		my %test_count;
		# this gets the raw HTML code from the website
		my $results = retrieve_page($page, $ua);
		my @test_words = split(/ /, $results);
		@test_words = make_list_lowercase(remove_punctuation(@test_words));
		foreach my $word (@test_words)
		{
			$test_count{$word}++;
		}	
		
		my $spam_score = 0;
		foreach my $word (sort keys (%test_count))
		{
			# Get the value associated with each word in the hash, this correlated with
			# the number of times the word appears in the document
			my $count = $test_count{$word};

			##############################################################
			# Try to get the key values found in the spam and notspam
			# hash tables
			my $spam_count = 0;
			if (exists $spamwords_count{$word})
			{
				$spam_count = $spamwords_count{$word};
			}

			my $notspam_count = 0;
			if (exists $notspamwords_count{$word})
			{
				$notspam_count = $notspamwords_count{$word};
			}
			##############################################################


			##############################################################
			# Since log0 does not exist we need to check to see if either of
			# the spam or not spam counts is 0. If so just pass those values,
			# else take the log of the count and multiply it by the number
			# of times the test word appears in the test document.
			my $spam_count_value = 0;
			if($spam_count != 0)
			{
				$spam_count_value = log($spam_count) * $count;
			}
			my $notspam_count_value = 0;
			if($notspam_count != 0)
			{
				$notspam_count_value = log($notspam_count) * $count;
			}
			##############################################################

			my $word_score = $spam_count_value - $notspam_count_value;
			$spam_score = $spam_score + $word_score;
		}
	
		# put the value found into the queue 
		$req_queue{$page} = $spam_score;
	}
	
	# At this point we have a populated req_queue where the key is a URL and the value is the 
	# spam score for page residing at that URL

    # I want to keep track of pages I have visited
    my %visited;

    # I need to record the file_id, the URL it relates to and the time it was visited to an
    # index.dat
    # gotta set up the index.dat file
    my $dir = dir();
    my $file = $dir->file("index.dat");

    my $file_handle = $file->openw();
	
	my @stack;

    while ($max_pages > 0) # Do the preceeding code until the queue is empty
    {
	if(%req_queue){
	    # get the nodes we want to visit. This is the key in the queue with the lowest value associated 
		# with it
		
		my $target = (reverse sort { $req_queue{$a} <=> $req_queue{$b} } keys %req_queue)[0];
	    #print $target . "\n";
		
		
		# Currently we will just remove that from our req_queue
		delete $req_queue{$target};		
		my $URL = $target;

	    # check to see if the node has been seen before
	    if (!(exists $visited{$URL}))
	    {
		#print "Current stack:\n @stack\n\n";
		print "!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!\n";
		print "Checking out $URL\n";
		print "Number of URLs left to check: $max_pages\n";
        
		# the file ID will be the time since the epoch that the URL was first accessed
		# this will be placed within the value for the key in the visited hash
		# this is convenient as this should be unique(barring time travel)
		my $this_time = time();
		$file_id = $this_time . '.html';
#	    print $file_id . "\n";
		
		# put the unseen node into the seen hash table
		$visited{$URL} = $file_id;

		# get the frontier from each node
		# this gets the raw HTML code from the website
		my $results = retrieve_page($URL, $ua);
	
		# Let's get the spam score of the currently viewed site
		my %test_count;
		
		my @test_words = split(/ /, $results);
		@test_words = make_list_lowercase(remove_punctuation(@test_words));
		foreach my $word (@test_words)
		{
			$test_count{$word}++;
		}	
		
		my $spam_score = 0;
		foreach my $word (sort keys (%test_count))
		{
			# Get the value associated with each word in the hash, this correlated with
			# the number of times the word appears in the document
			my $count = $test_count{$word};

			##############################################################
			# Try to get the key values found in the spam and notspam
			# hash tables
			my $spam_count = 0;
			if (exists $spamwords_count{$word})
			{
				$spam_count = $spamwords_count{$word};
			}

			my $notspam_count = 0;
			if (exists $notspamwords_count{$word})
			{
				$notspam_count = $notspamwords_count{$word};
			}
			##############################################################


			##############################################################
			# Since log0 does not exist we need to check to see if either of
			# the spam or not spam counts is 0. If so just pass those values,
			# else take the log of the count and multiply it by the number
			# of times the test word appears in the test document.
			my $spam_count_value = 0;
			if($spam_count != 0)
			{
				$spam_count_value = log($spam_count) * $count;
			}
			my $notspam_count_value = 0;
			if($notspam_count != 0)
			{
				$notspam_count_value = log($notspam_count) * $count;
			}
			##############################################################

			my $word_score = $spam_count_value - $notspam_count_value;
			$spam_score = $spam_score + $word_score;
		}
	
		# put the value found into the queue 
		# $req_queue{$page} = $spam_score;
	
	
		# dump the results(the raw HTML) into a file named using the $file_id in the
		# given output directory
		save_string_to_file($output_dir, $file_id, $results);
	    
		

		my $bookkeeping = $file_id . "\t" . gmtime($this_time) . "\t" . $URL . "\n"; 
		$file_handle->print($bookkeeping);


		# this gets the links in the raw HTML code and dumps it into an array
		my @frontier = find_links($results, $URL);
		
		# we need to add the found URLs to the req_queue alongside the spam score of their 
		# parent document
		foreach my $thing (@frontier){
			$req_queue{$thing} = $spam_score;
		}
		
		# I think that it would be beneficial to add the root URL for each link I visit to the queue
		# and, I think, typically these are better then their subpages in terms of maximizing my exploration
		# of the web. I hope to exploit this by finding the root url of the $URL and add it, and a score of 0
		# to the req_queue. Due to how my req_queue runs these do not take over the req_queue but tend to rise to the top
		# especially in situations where I do not have other low spam score pages.
		
		my $root_url = URI->new( $URL );
		my $domain = 'http:\\' . $root_url->host;
		#print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
		#print $domain . "\n";
		#print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
		
		if (!(exists $visited{$domain}))
		{
			$req_queue{$domain} = 0;
		}
		
		$max_pages = $max_pages - 1;

	    }
	} else {
		print "Ran out of stack!\n\n";
		
		# If this triggers then that means we still have time to visit more pages but
		# the stack is empty! 
		#foreach my $key ( keys %visited){
		#    push(@stack, $key);
		#}

		# Let's pull a random key from the hash table and see if there are new URLs in it!
		my @hash_keys    = keys %visited;

	    my $URL = $hash_keys[rand @hash_keys];
		$file_id = $visited{$URL};
		print $URL . "    " . $file_id . "\n";
		 #print "Current stack:\n @stack\n\n";

		#print "Current stack:\n @stack\n\n";
                print "Checking out $URL\n";
                print "Number of URLs left to check: $max_pages\n";

                # the file ID will be the time since the epoch that the URL was first accessed
                # this will be placed within the value for the key in the visited hash
                # this is convenient as this should be unique(barring time travel)
                my $this_time = time();
                #$file_id = $this_time . '.html';
#           print $file_id . "\n";

                # put the unseen node into the seen hash table
                $visited{$URL} = $file_id;

                # get the frontier from each node
                # this gets the raw HTML code from the website
                my $results = retrieve_page($URL, $ua);

				# Let's get the spam score of the currently viewed site
				my %test_count;
				
				my @test_words = split(/ /, $results);
				@test_words = make_list_lowercase(remove_punctuation(@test_words));
				foreach my $word (@test_words)
				{
					$test_count{$word}++;
				}	
				
				my $spam_score = 0;
				foreach my $word (sort keys (%test_count))
				{
					# Get the value associated with each word in the hash, this correlated with
					# the number of times the word appears in the document
					my $count = $test_count{$word};

					##############################################################
					# Try to get the key values found in the spam and notspam
					# hash tables
					my $spam_count = 0;
					if (exists $spamwords_count{$word})
					{
						$spam_count = $spamwords_count{$word};
					}

					my $notspam_count = 0;
					if (exists $notspamwords_count{$word})
					{
						$notspam_count = $notspamwords_count{$word};
					}
					##############################################################


					##############################################################
					# Since log0 does not exist we need to check to see if either of
					# the spam or not spam counts is 0. If so just pass those values,
					# else take the log of the count and multiply it by the number
					# of times the test word appears in the test document.
					my $spam_count_value = 0;
					if($spam_count != 0)
					{
						$spam_count_value = log($spam_count) * $count;
					}
					my $notspam_count_value = 0;
					if($notspam_count != 0)
					{
						$notspam_count_value = log($notspam_count) * $count;
					}
					##############################################################

					my $word_score = $spam_count_value - $notspam_count_value;
					$spam_score = $spam_score + $word_score;
				}
				
				
                # dump the results(the raw HTML) into a file named using the $file_id in the
                # given output directory
                save_string_to_file($output_dir, $file_id, $results);

                my $bookkeeping = $file_id . "\t" . gmtime($this_time) . "\t" . $URL . "\n";
                $file_handle->print($bookkeeping);


                # this gets the links in the raw HTML code and dumps it into an array
                my @frontier = find_links($results, $URL);

				
				foreach my $thing (@frontier){
					$req_queue{$thing} = $spam_score;
				}
		
                # print @stack , "\n\n";
                $max_pages = $max_pages - 1;
	    
	}
    }
}

#################################################
# Main program. We expect the user to run the program using one of the following three forms:
#
#   ./crawl.pl seeds_file max_pages output_directory bfs
#   ./crawl.pl seeds_file max_pages output_directory dfs
#   ./crawl.pl seeds_file max_pages output_directory bestfirst known_spam.txt known_notspam.txt
#

# testing URL normalization code

# my $test = "https://EXAmple.com:800//bar.html";
# my $newt = normalize_url ($test);
# print $newt . "\n";

# testing making absolute URLs
# print make_absolute_url("index.html", "http://www.cnn.com/") . "\n";
# print make_absolute_url("gov.html", "http://www.cnn.com/links/index.html") . "\n";
# print make_absolute_url("http://www.whitehouse.gov/", "http://www.cnn.com") . "\n";


#my $othert =  remove_directory_index($test);
#print $othert . "\n";

# check that the user gave us 4 command line parameters
die "Command line should have at least 4 parameters." unless ($#ARGV+1 > 3);

# fetch first three variables from the command line
my $seeds_file = $ARGV[0];
my $max_pages = $ARGV[1];
my $output_directory = $ARGV[2];

######################################################
#  All of this is done regardless of the algoritm the user chooses
#

# define my useragent
# setting my string
my $ua = LWP::RobotUA->new('IUB-I427-annaeile', 'annaeile@indiana.edu');
$ua->delay(1/60);

# fetch algorithm from command line and call the appropriate subroutine
my $algorithm = $ARGV[3];
if ($algorithm eq "dfs") {
    die "dfs command line should have 4 exactly parameters." unless ($#ARGV+1 == 4);
    dfs($ua,$seeds_file,$max_pages,$output_directory);
} elsif ($algorithm eq "bfs") {
    die "bfs command line should have 4 exactly parameters." unless ($#ARGV+1 == 4);
    bfs($ua,$seeds_file,$max_pages,$output_directory);
} elsif ($algorithm eq "bestfirst") {
    die "bestfirst command line should have exactly 6 parameters." unless ($#ARGV+1 == 6);
    my $known_spam = $ARGV[4];
    my $known_nonspam = $ARGV[5];
    bestfirst($ua,$seeds_file,$max_pages,$output_directory,$known_spam,$known_nonspam);
} else {
    die "Unrecognized algorithm. Fourth parameter should be one of bfs, dfs, or bestfirst."
}


# add main body of program here!


################
# this was my testing ground, nothing is running from here
# everything is in sub routines above
#


# Let's initialize the frontier with the seed urls from the seeds file
# the frontier will contain URLs that are in the queue to be looked at.

#my @frontier = read_urls_file($seeds_file);
#print "Loaded the following seed URLS from $seeds_file\n";
#print @frontier;
#print "\n";

# my $results = retrieve_page($frontier[2], $ua);
# print $results . "\n\n\n";

# my @links = find_links($results, $frontier[2]);
#foreach my $link (@links){
#    print $link . "\n\n";
#}

#print @links;
# This is heavily influenced from the awesome tutorials on perlmeme.org:
# I like seperating my url request from the $ua->request call
#my $req = POST 'http://www.perlmeme.org', [];
#my $res = $ua->request($req, 'temp.txt');
#if ($res->is_success) {
#    print "Successfully accessed using $req\n";
#} else {
#    print "Failed to access, status: $res->status_line\n";
#}




