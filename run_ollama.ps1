$Host.UI.RawUI.WindowTitle = "Ollama"
$env:OLLAMA_NO_NETWORK = "1"
$env:OLLAMA_HOST = "0.0.0.0"
$env:OLLAMA_NUM_CTX = "8192"

ollama serve