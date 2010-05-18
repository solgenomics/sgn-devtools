use strict;
use warnings;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html/;

my $page = CXGN::Page->new('Page Internal Name','Robert Buels');

$page->header(('Page Title') x 2);

print info_section_html(title => 'New Page',
			contents => <<EOHTML);
This is a new page.
EOHTML

$page->footer;
