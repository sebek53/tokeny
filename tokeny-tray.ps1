# Ikona w zasobniku: dzisiejsze tokeny Claude Code, odswiezane co minute.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$root = Join-Path $env:USERPROFILE ".claude\projects"

function Get-Today {
    # ponytail: dzien liczony wg UTC z logow, przesuniecie ~2h wokol polnocy
    $day = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $t = @{ in = 0; out = 0; cw = 0; cr = 0 }
    $seen = @{}
    Get-ChildItem $root -Recurse -Filter *.jsonl |
        Where-Object { $_.LastWriteTime -ge (Get-Date).Date.AddDays(-1) } |
        ForEach-Object {
            foreach ($line in [IO.File]::ReadLines($_.FullName)) {
                if ($line -notlike "*`"usage`"*" -or $line -notlike "*$day*") { continue }
                try { $d = $line | ConvertFrom-Json } catch { continue }
                $m = $d.message
                if (-not $m.usage -or -not "$($d.timestamp)".StartsWith($day)) { continue }
                if ($seen.ContainsKey($m.id)) { continue }
                $seen[$m.id] = 1
                $t.in += [int64]$m.usage.input_tokens
                $t.out += [int64]$m.usage.output_tokens
                $t.cw += [int64]$m.usage.cache_creation_input_tokens
                $t.cr += [int64]$m.usage.cache_read_input_tokens
            }
        }
    $t
}

function Short($n) {
    if ($n -ge 1e6) { "{0:0.#}M" -f ($n / 1e6) } elseif ($n -ge 1e3) { "{0:0}k" -f ($n / 1e3) } else { "$n" }
}

# Prawdziwy limit z konta (ten sam co /usage). Nieoficjalne API; token odswieza sam Claude Code.
$script:usage = $null; $script:usageAt = [datetime]::MinValue
# Czy jest zapisany (niepusty) token logowania Claude Code
function Test-Login {
    try {
        $c = Get-Content (Join-Path $env:USERPROFILE ".claude\.credentials.json") -Raw | ConvertFrom-Json
        [bool]$c.claudeAiOauth.accessToken
    } catch { $false }
}
function Get-Usage {
    # serwer daje 429 przy czestym pytaniu, wiec max raz na 5 min
    if (((Get-Date) - $script:usageAt).TotalMinutes -lt 5) { return $script:usage }
    $script:usageAt = Get-Date
    $script:usage = Get-UsageNow
    $script:usage
}
function Get-UsageNow {
    try {
        $c = Get-Content (Join-Path $env:USERPROFILE ".claude\.credentials.json") -Raw | ConvertFrom-Json
        $r = Invoke-RestMethod "https://api.anthropic.com/api/oauth/usage" -TimeoutSec 10 -Headers @{
            Authorization = "Bearer $($c.claudeAiOauth.accessToken)"; "anthropic-beta" = "oauth-2025-04-20" }
        $reset = if ($r.five_hour.resets_at) { ' reset ' + ([datetime]$r.five_hour.resets_at).ToLocalTime().ToString('HH:mm') }
        "5h: $([int]$r.five_hour.utilization)%$reset | 7d: $([int]$r.seven_day.utilization)%"
    } catch {
        $wait = $_.Exception.Response.Headers['retry-after']
        if ($wait) { $script:usageAt = (Get-Date).AddSeconds([int]$wait - 300) }
        $null
    }
}

# ponytail: szacunek okna 5h (start = pelna godzina pierwszej wiadomosci), Anthropic nie publikuje limitu w tokenach
function Get-Reset {
    $since = (Get-Date).AddHours(-10)
    $ts = Get-ChildItem $root -Recurse -Filter *.jsonl |
        Where-Object { $_.LastWriteTime -ge $since } |
        ForEach-Object { [IO.File]::ReadLines($_.FullName) } |
        Where-Object { $_ -like "*`"usage`"*" -and $_ -match '"timestamp":"([^"]+)"' } |
        ForEach-Object { [datetime]::Parse($matches[1]).ToLocalTime() } |
        Where-Object { $_ -ge $since } | Sort-Object
    $end = $null
    foreach ($t in $ts) {
        if (-not $end -or $t -ge $end) { $end = $t.Date.AddHours($t.Hour + 5) }
    }
    if ($end -and $end -gt (Get-Date)) { $end }
}


# Male okienko zawsze na wierzchu; przeciagnij lewym, prawy = menu.
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = "None"
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(217, 119, 87)
$form.Size = New-Object System.Drawing.Size 190, 60
$form.StartPosition = "Manual"
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point ($wa.Right - 200), ($wa.Bottom - 70)

$label = New-Object System.Windows.Forms.Label
$label.Dock = "Fill"
$label.ForeColor = [System.Drawing.Color]::White
$label.Font = New-Object System.Drawing.Font "Segoe UI", 9, ([System.Drawing.FontStyle]::Bold)
$label.TextAlign = "MiddleCenter"
$label.Text = "liczę..."
$form.Controls.Add($label)

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Items.Add("Odswiez").add_Click({ Update-Box })
# Logowanie robi sam Claude Code (/login); my tylko otwieramy terminal.
$menu.Items.Add("Zaloguj Claude (procenty limitu)").add_Click({
    Start-Process cmd -ArgumentList '/k', 'echo Wpisz /login i zaloguj sie w przegladarce, potem zamknij okno. & claude'
    $script:usageAt = [datetime]::MinValue
})
$menu.Items.Add("Zamknij").add_Click({ $form.Close() })
$label.ContextMenuStrip = $menu

$script:drag = $null
$label.add_MouseDown({ if ($_.Button -eq "Left") { $script:drag = $_.Location } })
$label.add_MouseUp({ $script:drag = $null })
$label.add_MouseMove({
    if ($script:drag) { $form.Location = New-Object System.Drawing.Point ($form.Left + $_.X - $script:drag.X), ($form.Top + $_.Y - $script:drag.Y) }
})

$tip = New-Object System.Windows.Forms.ToolTip

function Update-Box {
    $t = Get-Today
    $label.Text = "Dziś: wyj $(Short $t.out)  wej $(Short $t.in)`ncache $(Short ($t.cw + $t.cr))`n$(if ($u = Get-Usage) { $u } elseif (-not (Test-Login)) { 'brak % - prawy klik: Zaloguj' } elseif ($r = Get-Reset) { 'reset ~' + $r.ToString('HH:mm') + ' (za ' + [int]($r - (Get-Date)).TotalMinutes + ' min)' } else { 'okno 5h wolne' })"
    $tip.SetToolTip($label, "Wyjscie $('{0:N0}' -f $t.out)`nWejscie $('{0:N0}' -f $t.in)`nCache zapis $('{0:N0}' -f $t.cw)`nCache odczyt $('{0:N0}' -f $t.cr)")
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 60000
$timer.add_Tick({ Update-Box })
$timer.Start()
$form.add_Shown({ Update-Box })
[System.Windows.Forms.Application]::Run($form)
