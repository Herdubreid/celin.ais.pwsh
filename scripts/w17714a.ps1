class w17714a : jdeForm {
  [void] ok($fm) {
    $s = $this.set($fm)
    $r = step-celin.ais.script "$s do(11)"
    [jdeForm]::update($r)
  }
  [void] cancel() {
    $r = step-celin.ais.script "do(12)"
    [jdeForm]::update($r)
  }
  w17714a($rs) : base($rs) {}
}
# Add the returnControlIDs
$ctrlIDs["w17714a"] = "605|152|299|481|206|173|508|510|208|210"
# Add the type
[jdeForm]::types.add(@{ Name = "*W17714A*"; Type = [w17714a] })
