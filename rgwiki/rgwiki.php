<?php
#Display the requested article or 'Main' if not specified
if(isset($_GET['display'])) {
	if (get_magic_quotes_gpc())
	{
		$article_tmp = $_GET['display'];
		#only accept word chars, -, _, and ,
		$article = preg_replace("/(\w+)/", "\\1",  $article_tmp );
	} else {
		$article_tmp = addslashes($_GET['display']);
		$article = preg_replace("/(\w+)/", "\\1",  $article_tmp );
	}
} else {
	$article = 'Main';
}

### CONFIGURATION ###
$dbase = '/Users/msporleder/Sites/php/rgwiki';  #files go here
$sec_pass = 'assword'; #password for updating

 #This goes at the top of each page; include your css, etc here
   #some javascript to show/hide the editor is included here
$static_top = <<<TOP
<html> <DIV id="head"> <title> $article </title> </DIV>

<script>
function toggleLayer(whichLayer)
{
var style2 = document.getElementById(whichLayer).style;
if (style2.visibility == "hidden") { style2.visibility = ""; } else { style2.visibility = "hidden"; }
}
</script>
TOP;
 # Footer before the edit screen
$static_middle = <<<MIDDLE
<DIV id="foot"> <hr /><a href={$_SERVER['SCRIPT_NAME']}>rgWiki Home</a> </DIV>
<a href="javascript:toggleLayer('edit');" title="Edit Article">Edit</a>
MIDDLE;

 #The edit form
$edit_top = <<<EDIT_TOP
<DIV id="edit" style="visibility: hidden" >
<form method="POST" action={$_SERVER['REQUEST_URI']}>
Update Password: <input type=password name="sec_pass"> <br />
<textarea name="rgtext" rows=24 cols=64>
EDIT_TOP;
 #contents are displayed in the flow here
$edit_bottom = <<<EDIT_BOTTOM
</textarea><br />
<input type=submit value="commit">
</form>
</DIV>
EDIT_BOTTOM;

$static_bottom = <<<BOTTOM
</html>
BOTTOM;
### END CONFIGURATION ###

#Update the page if form is submitted and password matches
$file = "$dbase/$article.wiki";
if (dirname($file) != $dbase )
{
	trigger_error("articles must be in $dbase", E_USER_ERROR);
}
if( (isset($_POST['rgtext'])) and ($_POST['sec_pass'] == "$sec_pass") ) {
	$wfh = fopen("$file", "w");
	$contents = stripslashes($_POST['rgtext']);
	fwrite($wfh, $contents);
#Else just display the page as-is
} elseif (file_exists($file)) {
	$contents = stripslashes(file_get_contents($file));
} else {
#Or error (this will happen on empty pages)
	echo("This space intentionally left blank until you fill it in");
}

#Handles links (reformat them)
$discontents = preg_replace("/\[(?!http\:\/\/)(\w*)\]/", "<a href=?display=\\1>\\1</a>", "$contents");
$discontents = preg_replace("/\[(http\:\/\/.*)\]/", "<a href=\\1>\\1</a>", "$discontents");
#Displays the viewable/clickable version
echo($static_top);
echo("<DIV id=\"body\">");
echo(nl2br($discontents));
echo("</DIV>");
echo($static_middle);
echo($edit_top);
echo(htmlspecialchars($contents));
echo($edit_bottom);
echo($static_bottom);
?>
