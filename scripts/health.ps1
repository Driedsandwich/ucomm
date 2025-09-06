#Requires -Version 5
$start = Get-Date
# エミュレート出力
$ts = (Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ")
Write-Output ('{"ok":true,"code":200,"ts":"' + $ts + '","latency_ms":1234,"agent":"cli-bins-poc"}')