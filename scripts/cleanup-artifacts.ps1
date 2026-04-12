$repo = "jiege455/lottery_3d_app"
$apiBase = "https://api.github.com/repos/$repo/actions/artifacts"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitHub Actions Artifact 清理工具" -ForegroundColor Cyan
Write-Host "  开发者：杰哥网络科技" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$token = Read-Host "请输入你的 GitHub Personal Access Token (需要 repo 和 actions 权限)"

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "错误：Token 不能为空！" -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept"        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

Write-Host ""
Write-Host "正在获取 Artifact 列表..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri $apiBase -Headers $headers -Method Get
} catch {
    Write-Host "错误：无法获取 Artifact 列表" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

$artifacts = $response.artifacts
$totalCount = $artifacts.Count
$totalSize = ($artifacts | Measure-Object -Property size_in_bytes -Sum).Sum / 1MB

Write-Host "找到 $totalCount 个 Artifact，总大小 $([math]::Round($totalSize, 2)) MB" -ForegroundColor Green
Write-Host ""

if ($totalCount -eq 0) {
    Write-Host "没有需要删除的 Artifact" -ForegroundColor Green
    exit 0
}

foreach ($a in $artifacts) {
    $sizeMB = [math]::Round($a.size_in_bytes / 1MB, 2)
    Write-Host "  - $($a.name) (ID: $($a.id), 大小: ${sizeMB}MB, 创建: $($a.created_at))" -ForegroundColor Gray
}

Write-Host ""
$confirm = Read-Host "确认删除以上所有 Artifact？(输入 y 确认)"

if ($confirm -ne 'y') {
    Write-Host "已取消" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
$deleted = 0
$failed = 0

foreach ($a in $artifacts) {
    try {
        Write-Host "正在删除: $($a.name) (ID: $($a.id))..." -ForegroundColor Yellow -NoNewline
        Invoke-RestMethod -Uri "$apiBase/$($a.id)" -Headers $headers -Method Delete | Out-Null
        Write-Host " 成功" -ForegroundColor Green
        $deleted++
    } catch {
        Write-Host " 失败" -ForegroundColor Red
        Write-Host "  错误: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  清理完成！" -ForegroundColor Green
Write-Host "  成功删除: $deleted 个" -ForegroundColor Green
Write-Host "  失败: $failed 个" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan
