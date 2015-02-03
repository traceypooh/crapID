<? require_once('/petabox/setup.inc');

Nav::head("The Craptioning Experiment");

chdir("/var/tmp/tv/ADS") || fatal("bad box");


$ao = Paths::serverSF(0);

$filter1=($_GET['day'] && is_numeric($_GET['day']) ? "fgrep ".intval($_GET['day']) : "cat");
$filter2="head -" . ($_GET['n'] && is_numeric($_GET['n']) ? intval($_GET['n']) : 10);




$matfi = glob("*.matches");
if (count($matfi) > 100){
  echo "<h3>Picking 100 ADs at random from ".count($matfi)." matched ADs</h3>";
  shuffle($matfi);
  $matfi = array_slice($matfi,0,100);
}
else{
  sort($matfi);
  echo "<h3>".count($matfi)." matched ADs</h3>";
}


$url1=Util::url_without('n');
$url2=Util::url_without('day');
?>
show best (defaults to 10): [
<a href="<?=$url1?>&n=1">1 match</a> |
<a href="<?=$url1?>&n=10">10 matches</ a> |
<a href="<?=$url1?>&n=25">25 matches</a> |
<a href="<?=$url1?>&n=50">50 matches</a> |
<a href="<?=$url1?>&n=100000">all matches</a>
]
<br/>
show only matches found on: [
<a href="<?=$url2?>&day=20141028">20141028</a> |
<a href="<?=$url2?>&day=20141029">20141029</a> |
<a href="<?=$url2?>&day=20141030">20141030</a> |
<a href="<?=$url2?>&day=20141031">20141031</a> |
<a href="<?=$url2?>&day=20141101">20141101</a> |
<a href="<?=$url2?>&day=20141102">20141102</a> |
<a href="<?=$url2?>&day=20141103">20141103</a> |
<a href="<?=$url2?>&day=20141028">20141028</a>
]
<?


echo '<table class="tablesorter  table table-striped table-condensed table-hovertable"><tbody>';
echo '
<tr>
  <th>AD</th>
  <th>craptioned text of the AD</th>
  <th>match</th>
  <th>craptioned text of the match</th>
</tr>
';


foreach ($matfi as $fi){
  //msg($fi);
  if (!preg_match('/^([^,]+),([^,]+),([^\-]+)\-(\d+)\.txt\.hash\.matches$/', $fi, $mat))
    continue;
  list(,$id,$start,$end,$seek) = $mat;
  $start += $seek;
  $end   += $end;

  $tmp = explode("_",$id);
  $idA = array_shift($tmp)."_".array_shift($tmp)."_".join(" ",$tmp);
  
  $src = "<a href=\"//$ao/details/$id#start/$start/end/$end\">$idA #start/$start/end/$end</a>";
  
  $txt = preg_replace('/\.hash\.matches$/','',$fi);
  //echo file_get_contents($txt);
  $rowstart = ("<tr><td>$src</td><td>" .
               `cat $txt |cut -f3- |perl -pe 's/\(\d+\)\$//'  |egrep -v '^<s|sil|/s>\$'` .
               "</td>");

  $n=0;
  foreach (Util::cmd("cat $fi |$filter1 |$filter2","ARRAY","CONTINUE") as $line){
    $n++;
    if (!preg_match('=^(\S+)\s+\./[^/]+/([^/]+)\-(\d+)\.txt\.hash$=', $line, $mat))
      continue;
    list(,$fi2)=explode("\t",$line);
    list(,$score,$id2,$start2)=$mat;
    $start2=ltrim($start2,"0");

    $tmp = explode("_",$id2);
    $idA = array_shift($tmp)."_".array_shift($tmp)."_".join(" ",$tmp);

    $startend = "#start/$start2/end/".($start2+60);
    echo $rowstart . "<td>match #$n.  score: $score<br/> <a href=\"//$ao/details/$id2".$startend."\">$idA $startend</a><br/></td>";

    $txt2 = "../".preg_replace('/\.hash$/','',$fi2);
    //echo file_get_contents($txt2);
    $best = `cat $txt2 |cut -f3- |perl -pe 's/\(\d+\)\$//'  |egrep -v '^<s|sil|/s>\$'`;
    //$best .= $txt2;
    echo "<td>$best</td></tr>";
  }

  if (!$n)
    echo $rowstart . "<td>-</td><td>-</td></tr>";
}

echo "</tbody></table>";

  
