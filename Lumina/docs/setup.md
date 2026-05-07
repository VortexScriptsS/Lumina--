# Lumina Setup Guide

## Prerequisites

Before installing Lumina, ensure you have the following installed:

### Required Software
- **Python 3.8+** - For the FastAPI backend
- **Node.js 16+** - For the React frontend
- **Ollama** - For running AI models locally
- **Roblox Studio** - For plugin integration

### System Requirements
- **RAM**: 8GB minimum (16GB recommended for AI models)
- **Storage**: 10GB free space (for AI models)
- **OS**: Windows 10/11, macOS 10.15+, or Linux

## Installation Steps

### 1. Install Ollama

**Windows:**
```bash
# Download and install from https://ollama.ai/download
# After installation, run in Command Prompt:
ollama --version
```

**macOS:**
```bash
# Download and install from https://ollama.ai/download
# After installation, run in Terminal:
ollama --version
```

**Linux:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### 2. Pull Required AI Models

```bash
# Start Ollama service (Linux/macOS)
ollama serve

# In another terminal, pull the models
ollama pull deepseek-r1-distill-qwen-7b
ollama pull qwen2.5-coder-7b

# Verify models are installed
ollama list
```

### 3. Set Up Python Backend

```bash
# Navigate to backend directory
cd backend

# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create environment file
cp .env.example .env

# Edit .env file with your configuration
# Set your plugin key and other settings
```

### 4. Set Up React Frontend

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
npm install

# Verify installation
npm run start
```

### 5. Install Roblox Studio Plugin

**Windows:**
1. Navigate to `%LOCALAPPDATA%\Roblox\RobloxStudio\Plugins`
2. Create a new folder named `Lumina`
3. Copy all files from `roblox-plugin` directory to this folder
4. Restart Roblox Studio

**macOS:**
1. Navigate to `~/Library/Application Support/Roblox/RobloxStudio/Plugins`
2. Create a new folder named `Lumina`
3. Copy all files from `roblox-plugin` directory to this folder
4. Restart Roblox Studio

## Configuration

### Backend Configuration (.env)

```env
# Ollama Configuration
OLLAMA_BASE_URL=http://localhost:11434

# Plugin Security
ROBLOX_PLUGIN_KEY=your-secret-key-here

# Server Configuration
PORT=8000
DEBUG=true
```

### Plugin Configuration

Edit the `CONFIG` table in `roblox-plugin/Main.lua`:

```lua
local CONFIG = {
    BACKEND_URL = "http://localhost:8000",
    PLUGIN_KEY = "your-secret-key-here",
    PLUGIN_NAME = "Lumina AI Assistant",
    PLUGIN_VERSION = "1.0.0"
}
```

## Running Lumina

### Start All Services

1. **Start Ollama Service:**
   ```bash
   ollama serve
   ```

2. **Start Python Backend:**
   ```bash
   cd backend
   # Activate virtual environment if using one
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

3. **Start React Frontend:**
   ```bash
   cd frontend
   npm start
   ```

4. **Enable Roblox Plugin:**
   - Open Roblox Studio
   - Go to View → Toolbars
   - Enable "Lumina" toolbar
   - Click the Lumina button to open the plugin

### Verify Installation

1. **Check Backend Health:**
   ```bash
   curl http://localhost:8000/api/health
   ```

2. **Check Frontend:**
   - Open browser to `http://localhost:3000`
   - Should see Lumina interface

3. **Check Plugin:**
   - In Roblox Studio, click Lumina toolbar button
   - Should see plugin interface

## Troubleshooting

### Common Issues

**Ollama Connection Failed:**
- Ensure Ollama service is running: `ollama serve`
- Check if models are installed: `ollama list`
- Verify OLLAMA_BASE_URL in .env file

**Backend Won't Start:**
- Check Python version: `python --version`
- Verify virtual environment activation
- Check for port conflicts (change PORT in .env)

**Frontend Won't Load:**
- Ensure Node.js is installed: `node --version`
- Clear npm cache: `npm cache clean --force`
- Delete node_modules and reinstall: `rm -rf node_modules && npm install`

**Plugin Not Visible:**
- Verify plugin files are in correct directory
- Check Roblox Studio version compatibility
- Restart Roblox Studio completely

**Plugin Connection Error:**
- Check backend is running on correct port
- Verify PLUGIN_KEY matches between backend and plugin
- Check firewall settings for localhost connections

### Debug Mode

Enable debug logging by setting `DEBUG=true` in your `.env` file. This will provide detailed logs for troubleshooting.

### Getting Help

1. Check the [API Documentation](api.md) for detailed endpoint information
2. Review console logs in all three components (backend, frontend, plugin)
3. Ensure all services are running on their expected ports
4. Verify network connectivity between components

## Next Steps

Once installed, you can:

1. **Test the Web Interface:** Send messages through the React frontend
2. **Test the Plugin:** Use the plugin directly in Roblox Studio
3. **Explore MCP Features:** Enable MCP integration for Studio Explorer access
4. **Customize Models:** Adjust routing logic in the backend
5. **Extend Functionality:** Add new features to any component

For advanced configuration and development, see the [API Documentation](api.md).
