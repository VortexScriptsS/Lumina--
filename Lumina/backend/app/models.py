from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from enum import Enum

class ModelType(str, Enum):
    DEEPSEEK = "deepseek-r1-distill-qwen-7b"
    QWEN_CODER = "qwen2.5-coder-7b"

class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str
    timestamp: Optional[float] = None

class ChatRequest(BaseModel):
    message: str
    model: Optional[ModelType] = None
    context: Optional[Dict[str, Any]] = None
    source: Optional[str] = "web"  # web, roblox
    conversation_id: Optional[str] = None  # Session identifier
    history: Optional[List[ChatMessage]] = None  # Previous messages
    max_history: Optional[int] = 10  # Maximum history items to consider

class ChatResponse(BaseModel):
    response: str
    model_used: ModelType
    routing_reason: str
    processing_time: float
    thinking: Optional[str] = ""

class ModelInfo(BaseModel):
    name: str
    description: str
    size: str
    modified_at: str

class MCPRequest(BaseModel):
    action: str
    parameters: Dict[str, Any]
    plugin_key: Optional[str] = None

class MCPResponse(BaseModel):
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
