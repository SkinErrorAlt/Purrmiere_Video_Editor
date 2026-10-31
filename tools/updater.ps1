# Purrmiere updater: a very basic window that pulls the latest from the repo and starts the editor.
# Launched by "Update and Play.bat". No build step: the engine ships prebuilt in the repo.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'project'))) { $Root = (Get-Location).Path }
$GodotFile = Join-Path $PSScriptRoot 'godot_path.txt'
$FfDir = Join-Path $Root 'project\addons\purrcore\bin'
$FfDlls = @('avcodec-63.dll','avformat-63.dll','avutil-61.dll','swscale-10.dll','swresample-7.dll','avfilter-12.dll','purrcore.windows.template_debug.x86_64.dll')

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Purrmiere Updater'
$form.Size = New-Object System.Drawing.Size(560, 380)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(24, 22, 30)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Purrmiere'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(232, 150, 255)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 16)
$form.Controls.Add($title)

$status = New-Object System.Windows.Forms.Label
$status.Text = 'Starting...'
$status.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$status.ForeColor = [System.Drawing.Color]::White
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(22, 60)
$form.Controls.Add($status)

$bar = New-Object System.Windows.Forms.ProgressBar
$bar.Style = 'Marquee'
$bar.MarqueeAnimationSpeed = 30
$bar.Location = New-Object System.Drawing.Point(22, 90)
$bar.Size = New-Object System.Drawing.Size(500, 18)
$form.Controls.Add($bar)

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = 'Vertical'
$log.Font = New-Object System.Drawing.Font('Consolas', 9)
$log.BackColor = [System.Drawing.Color]::FromArgb(16, 15, 20)
$log.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
$log.Location = New-Object System.Drawing.Point(22, 120)
$log.Size = New-Object System.Drawing.Size(500, 160)
$form.Controls.Add($log)

$playBtn = New-Object System.Windows.Forms.Button
$playBtn.Text = 'Play'
$playBtn.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$playBtn.Size = New-Object System.Drawing.Size(140, 36)
$playBtn.Location = New-Object System.Drawing.Point(382, 292)
$playBtn.BackColor = [System.Drawing.Color]::FromArgb(150, 70, 190)
$playBtn.ForeColor = [System.Drawing.Color]::White
$playBtn.FlatStyle = 'Flat'
$playBtn.Enabled = $false
$form.Controls.Add($playBtn)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Text = 'Close'
$closeBtn.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$closeBtn.Size = New-Object System.Drawing.Size(100, 36)
$closeBtn.Location = New-Object System.Drawing.Point(22, 292)
$closeBtn.BackColor = [System.Drawing.Color]::FromArgb(50, 48, 58)
$closeBtn.ForeColor = [System.Drawing.Color]::White
$closeBtn.FlatStyle = 'Flat'
$closeBtn.Add_Click({ $form.Close() })
$form.Controls.Add($closeBtn)

function Say($text) {
	$status.Text = $text
	$log.AppendText($text + "`r`n")
	[System.Windows.Forms.Application]::DoEvents()
}
function Log($text) {
	$log.AppendText($text + "`r`n")
	[System.Windows.Forms.Application]::DoEvents()
}

function Find-Godot {
	if ($env:GODOT -and (Test-Path $env:GODOT)) { return $env:GODOT }
	if (Test-Path $GodotFile) {
		$p = (Get-Content $GodotFile -ErrorAction SilentlyContinue | Select-Object -First 1)
		if ($p -and (Test-Path $p)) { return $p }
	}
	$guesses = @(
		"$env:USERPROFILE\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe",
		"$env:USERPROFILE\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe",
		"$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
	)
	foreach ($g in $guesses) { if (Test-Path $g) { return $g } }
	return $null
}

function Ask-Godot {
	$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = 'Find your Godot 4.7.2 (mono) .exe'
	$dlg.Filter = 'Godot (*.exe)|*.exe'
	if ($dlg.ShowDialog() -eq 'OK') {
		Set-Content -Path $GodotFile -Value $dlg.FileName -Encoding utf8
		return $dlg.FileName
	}
	return $null
}

$script:Godot = $null

function Run-Update {
	# 1. Git
	Say 'Checking for Git...'
	$git = (Get-Command git -ErrorAction SilentlyContinue)
	if (-not $git) {
		Say 'Git is not installed.'
		Log 'Install Git from https://git-scm.com/download/win, then run this again.'
		$bar.Style = 'Blocks'; $bar.Value = 0
		return $false
	}
	Log('Git: ' + $git.Source)

	# 2. Pull
	Say 'Getting the latest version...'
	Push-Location $Root
	$pull = (& git pull --ff-only 2>&1 | Out-String)
	$code = $LASTEXITCODE
	Pop-Location
	Log($pull.Trim())
	if ($code -ne 0) {
		Say 'Could not update automatically.'
		Log 'If you changed files here, the update was held back. You can still play the version you have.'
	} else {
		Say 'Up to date.'
	}

	# 3. Engine files (not kept in Git; fetched once from the URL in tools\engine_url.txt)
	Say 'Checking the engine files...'
	$missing = @()
	foreach ($d in $FfDlls) { if (-not (Test-Path (Join-Path $FfDir $d))) { $missing += $d } }
	if ($missing.Count -gt 0) {
		Log ('Missing: ' + ($missing -join ', '))
		$urlFile = Join-Path $PSScriptRoot 'engine_url.txt'
		$url = $null
		if (Test-Path $urlFile) { $url = (Get-Content $urlFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1) }
		if ($url) {
			Say 'Downloading the engine (one time)...'
			$zip = Join-Path $env:TEMP 'purrmiere_engine.zip'
			try {
				[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
				Invoke-WebRequest -Uri $url.Trim() -OutFile $zip -UseBasicParsing
				Say 'Unpacking the engine...'
				Expand-Archive -Path $zip -DestinationPath $FfDir -Force
				Remove-Item $zip -ErrorAction SilentlyContinue
				$still = @(); foreach ($d in $FfDlls) { if (-not (Test-Path (Join-Path $FfDir $d))) { $still += $d } }
				if ($still.Count -eq 0) { Log 'Engine files installed.' } else { Say 'Engine still incomplete.'; Log ('Still missing: ' + ($still -join ', ')) }
			} catch {
				Say 'Could not download the engine.'
				Log ($_.Exception.Message)
				Log 'See FRIEND_SETUP.md to add the engine files by hand.'
			}
		} else {
			Say 'Engine files are missing.'
			Log 'See FRIEND_SETUP.md for the one-time engine download, or add tools\engine_url.txt with the download link.'
		}
	} else {
		Log 'Engine files present.'
	}

	# 4. Godot
	Say 'Looking for Godot...'
	$script:Godot = Find-Godot
	if (-not $script:Godot) {
		Log 'Godot was not found. Click Play and point to your Godot 4.7.2 (mono) .exe.'
	} else {
		Log('Godot: ' + $script:Godot)
	}

	$bar.Style = 'Blocks'; $bar.Maximum = 100; $bar.Value = 100
	Say 'Ready. Press Play.'
	return $true
}

$playBtn.Add_Click({
	if (-not $script:Godot) { $script:Godot = Ask-Godot }
	if (-not $script:Godot) { Say 'No Godot selected.'; return }
	$proj = Join-Path $Root 'project'
	Say 'Starting Purrmiere...'
	Start-Process -FilePath $script:Godot -ArgumentList @('--path', $proj)
	Start-Sleep -Milliseconds 600
	$form.Close()
})

$form.Add_Shown({
	$form.Activate()
	[System.Windows.Forms.Application]::DoEvents()
	$ok = Run-Update
	$playBtn.Enabled = $true
})

[void]$form.ShowDialog()
