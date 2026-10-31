# Launch Claude Code connected to local Ollama and HammeRR MCP
$env:ANTHROPIC_BASE_URL = "http://localhost:11434"
$env:ANTHROPIC_API_KEY = "ollama"

Write-Host "Starting Claude Code with HammeRR MCP..." -ForegroundColor Cyan
Write-Host "Ensure the HammeRR editor is open and running at http://127.0.0.1:7377/mcp." -ForegroundColor Yellow

claude --mcp-config .mcp.json

