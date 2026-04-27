$cnt = 0
$total = 0
$cutoff = (Get-Date).AddMinutes(-90)
Get-ChildItem -Path 'artifacts/tests/runs/baseline_v0' -Directory -Filter 'scenario_*' | ForEach-Object {
    $total++
    $sess = Get-ChildItem $_.FullName -Directory -Filter 'session_*' | Sort-Object Name -Descending | Select-Object -First 1
    if ($sess -and $sess.LastWriteTime -gt $cutoff) { $cnt++ }
}
Write-Host "Total scenarios: $total, recently updated: $cnt"
