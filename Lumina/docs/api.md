# Lumina API Documentation

## Overview

Lumina provides a RESTful API for AI-powered Roblox Studio development. The API handles intelligent model routing, chat interactions, and MCP (Model Context Protocol) integration.

## Base URL

```
http://localhost:8000
```

## Authentication

Most endpoints are public, but MCP-related endpoints require authentication via Bearer token:

```
Authorization: Bearer your-plugin-key
```

## Endpoints

### Health Check

**GET** `/api/health`

Check if the API is running properly.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1699123456.789
}
```

---

### Models

**GET** `/api/models`

List all available Ollama models.

**Response:**
```json
[
  {
    "name": "deepseek-r1-distill-qwen-7b",
    "description": "DeepSeek distilled model for math and animation",
    "size": "4.7GB",
    "modified_at": "2024-01-15T10:30:00Z"
  },
  {
    "name": "qwen2.5-coder-7b",
    "description": "Qwen coding model for general programming",
    "size": "4.1GB",
    "modified_at": "2024-01-10T15:45:00Z"
  }
]
```

---

### Chat

**POST** `/api/chat`

Send a message to the AI with smart model routing.

**Request Body:**
```json
{
  "message": "How do I create a smooth animation in Roblox?",
  "model": "deepseek-r1-distill-qwen-7b",  // Optional
  "context": {  // Optional
    "game_name": "My Game",
    "place_id": 123456789
  },
  "source": "web"  // "web" or "roblox"
}
```

**Response:**
```json
{
  "response": "To create smooth animations in Roblox, you can use TweenService...",
  "model_used": "deepseek-r1-distill-qwen-7b",
  "routing_reason": "Smart routing based on content",
  "processing_time": 2.34
}
```

**Model Routing Logic:**

The API automatically routes messages to the most appropriate model:

- **deepseek-r1-distill-qwen-7b** for:
  - Animation and movement
  - Math calculations and formulas
  - Physics and vectors
  - Geometry and trajectories
  - Interpolation and easing

- **qwen2.5-coder-7b** for:
  - Lua scripting
  - Roblox API usage
  - General coding questions
  - Debugging and optimization

---

### MCP Explorer (Authenticated)

**POST** `/api/mcp/explorer`

Handle Model Context Protocol requests from Roblox Studio plugin.

**Request Headers:**
```
Authorization: Bearer your-plugin-key
Content-Type: application/json
```

**Request Body:**
```json
{
  "action": "get_tree",
  "parameters": {}
}
```

**Available Actions:**

#### get_tree
Get the complete Roblox Studio explorer tree.

**Parameters:** None

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "MCP explorer integration coming soon"
  }
}
```

#### get_instance
Get details for a specific instance.

**Parameters:**
```json
{
  "path": "Workspace.Baseplate"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "path": "Workspace.Baseplate",
    "message": "Instance details coming soon"
  }
}
```

---

## Error Responses

All endpoints return consistent error responses:

```json
{
  "detail": "Error message describing what went wrong"
}
```

**Common HTTP Status Codes:**
- `200` - Success
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (invalid plugin key)
- `500` - Internal Server Error

---

## Rate Limiting

Currently, there are no rate limits implemented. However, in a production environment, consider implementing:
- Request rate limiting per IP
- Concurrent request limits
- Request size limits

---

## Websocket Support (Future)

Future versions will support WebSocket connections for real-time communication:

```javascript
const ws = new WebSocket('ws://localhost:8000/ws/chat');

ws.onmessage = function(event) {
    const response = JSON.parse(event.data);
    console.log('AI Response:', response.response);
};
```

---

## Integration Examples

### Python Backend Integration

```python
import requests

# Send chat message
response = requests.post('http://localhost:8000/api/chat', json={
    'message': 'How do I create a moving platform?',
    'source': 'web'
})

data = response.json()
print(f"Model used: {data['model_used']}")
print(f"Response: {data['response']}")
```

### Roblox Plugin Integration

```lua
local HttpService = game:GetService("HttpService")

local function sendMessage(message)
    local response = HttpService:RequestAsync({
        Url = "http://localhost:8000/api/chat",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer your-plugin-key"
        },
        Body = HttpService:JSONEncode({
            message = message,
            source = "roblox"
        })
    })
    
    if response.Success then
        local data = HttpService:JSONDecode(response.Body)
        return data.response
    else
        return "Error: " .. response.StatusCode
    end
end
```

### React Frontend Integration

```javascript
import axios from 'axios';

const sendChatMessage = async (message) => {
    try {
        const response = await axios.post('/api/chat', {
            message: message,
            source: 'web'
        });
        
        return response.data;
    } catch (error) {
        console.error('Chat error:', error);
        throw error;
    }
};
```

---

## Development

### Running in Development Mode

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### API Documentation (Swagger)

When running the backend, visit:
- `http://localhost:8000/docs` - Interactive API documentation
- `http://localhost:8000/redoc` - Alternative documentation view

### Testing

```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests
pytest tests/
```

---

## Model Configuration

### Adding New Models

To add new Ollama models:

1. Pull the model in Ollama:
   ```bash
   ollama pull new-model-name
   ```

2. Update the routing logic in `backend/app/ollama_client.py`:
   ```python
   def route_model(self, message: str) -> ModelType:
       # Add your routing logic here
       pass
   ```

3. Update the ModelType enum in `backend/app/models.py`:
   ```python
   class ModelType(str, Enum):
       DEEPSEEK = "deepseek-r1-distill-qwen-7b"
       QWEN_CODER = "qwen2.5-coder-7b"
       NEW_MODEL = "new-model-name"
   ```

### Custom Routing Logic

Modify the `route_model` method in `OllamaClient` to implement custom routing based on:
- Message content analysis
- User preferences
- Context information
- Performance metrics

---

## Security Considerations

1. **Plugin Key Security:** Never expose your plugin key in client-side code
2. **Input Validation:** All inputs are validated using Pydantic models
3. **CORS Configuration:** CORS is configured for localhost development only
4. **Rate Limiting:** Implement rate limiting for production use
5. **HTTPS:** Use HTTPS in production environments

---

## Monitoring and Logging

The backend provides structured logging for:
- Request/response times
- Model usage statistics
- Error tracking
- Performance metrics

Enable debug mode by setting `DEBUG=true` in your `.env` file.
