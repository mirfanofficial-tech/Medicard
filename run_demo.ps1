# One-click MVP demo: static data, no backend, works with NO internet.
#   .\run_demo.ps1            -> debug build in Chrome on http://localhost:8080
#   .\run_demo.ps1 -Build     -> release web build served on http://localhost:8080
# The browser's own text renderer (--web-renderer html) is used on purpose: it needs no
# files from Google's servers, and it draws Urdu and emoji with the system fonts.
param([switch]$Build)

Set-Location "$PSScriptRoot\app"

if ($Build) {
    flutter build web --release --web-renderer html --dart-define-from-file=env/demo.json
    Set-Location build\web
    Write-Host "Serving the demo on http://localhost:8080  (Ctrl+C to stop)"
    python -m http.server 8080
} else {
    flutter run -d chrome --web-port 8080 --web-renderer html --dart-define-from-file=env/demo.json
}
