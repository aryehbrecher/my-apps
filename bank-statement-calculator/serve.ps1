$port = if ($args[0]) { [int]$args[0] } else { 8768 }
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$port/"
$mime = @{
  '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8'
  '.js'='application/javascript; charset=utf-8'
  '.css'='text/css; charset=utf-8'; '.json'='application/json; charset=utf-8'
  '.png'='image/png'; '.jpg'='image/jpeg'; '.svg'='image/svg+xml'; '.ico'='image/x-icon'
}
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request; $resp = $ctx.Response
    $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
    if ($path -eq '/') { $path = '/index.html' }
    $file = Join-Path $root $path.TrimStart('/')
    if (Test-Path $file -PathType Leaf) {
      $ext = [IO.Path]::GetExtension($file).ToLower()
      $ct = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
      $bytes = [IO.File]::ReadAllBytes($file)
      $resp.ContentType = $ct
      $resp.SendChunked = $true
      try { $resp.OutputStream.Write($bytes, 0, $bytes.Length) } catch {}
    } else {
      $resp.StatusCode = 404
      $msg = [Text.Encoding]::UTF8.GetBytes("Not found: $path")
      $resp.SendChunked = $true
      try { $resp.OutputStream.Write($msg, 0, $msg.Length) } catch {}
    }
    try { $resp.OutputStream.Close() } catch {}
  }
} finally { $listener.Stop() }
