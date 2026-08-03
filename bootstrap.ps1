<#
.SYNOPSIS
    shinte ワークスペースのサブプロジェクトを clone する。

.DESCRIPTION
    core / engine / suteme / prokishi / kicho / ikkyoku は github.com/ShinteLab/<名前> の
    独立したリポジトリで、このワークスペースリポジトリでは追跡していない。
    このスクリプトは未取得のものだけを clone する（既にあるものは触らない）。

    モジュール間の参照は replace の相対パス指定なので、6 つとも
    このスクリプトの隣に並んでいる必要がある。

.EXAMPLE
    .\bootstrap.ps1
    .\bootstrap.ps1 -Protocol ssh
#>
[CmdletBinding()]
param(
    # clone に使うプロトコル。既定は https。
    [ValidateSet('https', 'ssh')]
    [string]$Protocol = 'https',

    # clone 後に各モジュールの go build / go test を流す。
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'

$org = 'ShinteLab'
$projects = 'core', 'engine', 'suteme', 'prokishi', 'kicho', 'ikkyoku'
$root = $PSScriptRoot

foreach ($p in $projects) {
    $dir = Join-Path $root $p
    if (Test-Path (Join-Path $dir '.git')) {
        Write-Host "skip   $p (取得済み)" -ForegroundColor DarkGray
        continue
    }
    if (Test-Path $dir) {
        Write-Warning "$p は存在するが git リポジトリではない。手動で確認すること。"
        continue
    }

    if ($Protocol -eq 'ssh') {
        $url = "git@github.com:$org/$p.git"
    } else {
        $url = "https://github.com/$org/$p.git"
    }

    Write-Host "clone  $p <- $url" -ForegroundColor Cyan
    git clone $url $dir
    if ($LASTEXITCODE -ne 0) { throw "clone に失敗した: $p" }
}

if (-not $Verify) {
    Write-Host "`n完了。go コマンドは各サブディレクトリで実行すること。" -ForegroundColor Green
    return
}

Write-Host "`n--- verify ---" -ForegroundColor Green
$failed = @()
foreach ($p in $projects) {
    Write-Host "== $p ==" -ForegroundColor Cyan
    Push-Location (Join-Path $root $p)
    try {
        go build ./...
        if ($LASTEXITCODE -ne 0) { $failed += "$p (build)"; continue }
        go test ./...
        if ($LASTEXITCODE -ne 0) { $failed += "$p (test)" }
    } finally {
        Pop-Location
    }
}

if ($failed.Count -gt 0) {
    Write-Host "`n失敗: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nすべて通過。" -ForegroundColor Green
