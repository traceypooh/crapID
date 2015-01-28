<? require_once('/petabox/setup.inc');

Nav::head("The Craptioning Experiment");

chdir("/var/tmp/tv/ADS") || fatal("bad box");


$ao = Paths::serverSF(0);


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

echo '<table class="tablesorter  table table-striped table-condensed table-hovertable"><tbody>';
echo '
<tr>
  <th>AD</th>
  <th>craptioned text of the AD</th>
  <th>best 10 matches (score, clip)</th>
</tr>
';


foreach ($matfi as $fi){
  //msg($fi);
  if (!preg_match('/^([^,]+),([^,]+),([^\-]+)\-(\d+)\.txt\.hash\.matches$/', $fi, $mat))
    continue;
  list(,$id,$start,$end,$seek) = $mat;
  $start += $seek;
  $end   += $end;

  echo "<tr><td><a href=\"//$ao/details/$id#start/$start/end/$end\">$id#start/$start/end/$end</a></td><td>";
  
  $txt = preg_replace('/\.hash\.matches$/','',$fi);
  //echo file_get_contents($txt);
  echo `cat $txt |cut -f3- |perl -pe 's/\(\d+\)\$//'  |egrep -v '^<s|sil|/s>\$'`;

  $best = '';
  foreach (Util::cmd("cat $fi |head -10","ARRAY","CONTINUE") as $line){
    if (!preg_match('=^(\S+)\s+\./[^/]+/([^/]+)\-(\d+)\.txt\.hash$=', $line, $mat))
      continue;
    list(,$score,$id2,$start2)=$mat;
    $start2=ltrim($start2,"0");
    $best .= "$score <a href=\"//$ao/details/$id2#start/$start2/end/".($start2+30)."\">$id2</a>\n";
  }
  
  echo "</td><td><pre>$best</pre></td></tr>";
}

echo "</tbody></table>";

  
