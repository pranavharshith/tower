# Coverage measurement script with threshold gate
# Usage: .\scripts\coverage.ps1 [threshold]
# Default threshold: 70%

param(
    [int]$Threshold = 70
)

Write-Host "📊 Running Flutter Tests with Coverage..." -ForegroundColor Cyan
flutter test --coverage

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Tests failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📈 Generating Coverage Report..." -ForegroundColor Cyan

# Check if lcov is available
$lcovPath = Get-Command genhtml -ErrorAction SilentlyContinue
if (-not $lcovPath) {
    Write-Host "⚠️  lcov not found. Please install it manually:" -ForegroundColor Yellow
    Write-Host "  - Windows: Install via MSYS2 or WSL" -ForegroundColor Yellow
    Write-Host "  - macOS: brew install lcov" -ForegroundColor Yellow
    Write-Host "  - Linux: sudo apt-get install lcov" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Continuing without HTML report generation..." -ForegroundColor Yellow
} else {
    # Generate HTML report
    genhtml coverage/lcov.info -o coverage/html
    Write-Host ""
    Write-Host "✅ Coverage report generated: coverage/html/index.html" -ForegroundColor Green
}

Write-Host ""

# Extract line coverage percentage
$lcovContent = Get-Content coverage/lcov.info -Raw
$linesMatch = [regex]::Match($lcovContent, "lines:(\d+),(\d+)")

if (-not $linesMatch.Success) {
    Write-Host "❌ Could not extract coverage data" -ForegroundColor Red
    exit 1
}

$coveredLines = [int]$linesMatch.Groups[1].Value
$totalLines = [int]$linesMatch.Groups[2].Value
$coveragePercent = ($coveredLines / $totalLines) * 100

Write-Host "📊 Line Coverage: ${coveragePercent}%" -ForegroundColor Cyan
Write-Host "🎯 Threshold: ${Threshold}%" -ForegroundColor Cyan
Write-Host ""

# Check if coverage meets threshold
if ($coveragePercent -lt $Threshold) {
    Write-Host "❌ Coverage ${coveragePercent}% is below threshold ${Threshold}%" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Coverage ${coveragePercent}% meets threshold ${Threshold}%" -ForegroundColor Green
    exit 0
}
