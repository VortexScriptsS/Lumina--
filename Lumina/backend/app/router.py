from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Dict, Any, Optional
import time
import os
import hashlib
from collections import defaultdict, deque

from .models import ChatRequest, ChatResponse, ModelInfo, MCPRequest, MCPResponse, ModelType
from .ollama_client import OllamaClient

router = APIRouter(prefix="/api", tags=["lumina"])
security = HTTPBearer()

# Initialize Ollama client
ollama_client = OllamaClient()

# Plugin key from environment
PLUGIN_KEY = os.getenv("ROBLOX_PLUGIN_KEY", "default-key")

# Simple in-memory storage for MCP analytics and conversations
mcp_analytics_cache = {}
conversation_store = {}  # conversation_id -> list of ChatMessage

# Rate limiting configuration
RATE_LIMIT_REQUESTS = 30  # requests per minute
RATE_LIMIT_WINDOW = 60    # seconds
rate_limit_store = defaultdict(deque)  # IP -> deque of timestamps

def get_client_ip(request: Request) -> str:
    """Get client IP address from request"""
    # Check for forwarded headers first
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    
    return request.client.host

def check_rate_limit(request: Request) -> bool:
    """Check if client has exceeded rate limit"""
    client_ip = get_client_ip(request)
    current_time = time.time()
    
    # Clean old entries
    rate_limit_store[client_ip] = deque(
        timestamp for timestamp in rate_limit_store[client_ip]
        if current_time - timestamp < RATE_LIMIT_WINDOW
    )
    
    # Check if under limit
    if len(rate_limit_store[client_ip]) >= RATE_LIMIT_REQUESTS:
        return False
    
    # Add current request
    rate_limit_store[client_ip].append(current_time)
    return True

def generate_session_token(request: Request) -> str:
    """Generate a simple session token for unauthenticated requests"""
    client_ip = get_client_ip(request)
    user_agent = request.headers.get("User-Agent", "")
    timestamp = str(int(time.time()))
    
    # Create a simple hash
    token_data = f"{client_ip}:{user_agent}:{timestamp}"
    return hashlib.sha256(token_data.encode()).hexdigest()[:32]

async def optional_auth(request: Request) -> Optional[HTTPAuthorizationCredentials]:
    """Optional authentication dependency"""
    authorization = request.headers.get("authorization")
    if authorization:
        try:
            scheme, credentials = authorization.split(" ", 1)
            if scheme.lower() == "bearer":
                return HTTPAuthorizationCredentials(scheme=scheme, credentials=credentials)
        except ValueError:
            pass
    return None

async def verify_chat_request(request: Request, credentials: Optional[HTTPAuthorizationCredentials] = None):
    """Enhanced verification for chat requests with rate limiting"""
    # Check rate limit first
    if not check_rate_limit(request):
        raise HTTPException(
            status_code=429, 
            detail="Rate limit exceeded. Please try again later.",
            headers={"Retry-After": str(RATE_LIMIT_WINDOW)}
        )
    
    # If no credentials provided, generate a temporary session token
    if not credentials:
        session_token = generate_session_token(request)
        return {"type": "session", "token": session_token}
    
    # Verify plugin key for authenticated requests
    if credentials.credentials != PLUGIN_KEY:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    
    return {"type": "plugin", "token": credentials.credentials}

async def verify_plugin_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify plugin key for protected endpoints"""
    if credentials.credentials != PLUGIN_KEY:
        raise HTTPException(status_code=401, detail="Invalid plugin key")
    return credentials

@router.get("/models", response_model=list[ModelInfo])
async def get_models():
    """Get list of available Ollama models"""
    try:
        models = await ollama_client.list_models()
        return models
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch models: {str(e)}")

@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, http_request: Request, credentials: Optional[HTTPAuthorizationCredentials] = Depends(optional_auth)):
    """Process chat message with smart model routing, conversation history, and rate limiting"""
    start_time = time.time()
    
    try:
        # Enhanced verification with rate limiting
        auth_info = await verify_chat_request(http_request, credentials)
        
        # Add authentication info to context
        if not request.context:
            request.context = {}
        request.context["auth_type"] = auth_info["type"]
        request.context["client_ip"] = get_client_ip(http_request)
        # Handle conversation history
        conversation_id = request.conversation_id or f"session_{int(time.time())}"
        
        # Initialize conversation if it doesn't exist
        if conversation_id not in conversation_store:
            conversation_store[conversation_id] = []
        
        # Add current user message to history
        from .models import ChatMessage
        user_message = ChatMessage(
            role="user",
            content=request.message,
            timestamp=time.time()
        )
        conversation_store[conversation_id].append(user_message)
        
        # Limit history size
        max_history = request.max_history or 10
        if len(conversation_store[conversation_id]) > max_history * 2:  # *2 for user+assistant pairs
            conversation_store[conversation_id] = conversation_store[conversation_id][-max_history * 2:]
        
        # Determine which model to use
        if request.model:
            model = request.model
            routing_reason = "User specified model"
        else:
            model = ollama_client.route_model(request.message)
            routing_reason = "Smart routing based on content"
        
        # Enhanced context for animation requests
        enhanced_context = request.context.copy() if request.context else {}
        
        # Add conversation history to context
        if len(conversation_store[conversation_id]) > 1:
            enhanced_context["conversation_history"] = [
                {"role": msg.role, "content": msg.content} 
                for msg in conversation_store[conversation_id][-10:]  # Last 10 messages
            ]
            enhanced_context["has_history"] = True
            routing_reason += " (with conversation context)"
        
        # If this is an animation request, try to get rig information
        if model == ModelType.DEEPSEEK and ollama_client.is_animation_request(request.message):
            rig_info = await get_rig_information()
            if rig_info:
                enhanced_context["rig_information"] = rig_info
                enhanced_context["has_rigs"] = True
                enhanced_context["is_keyframe_animation"] = ollama_client.is_keyframe_animation_request(request.message)
                routing_reason += " (with rig analysis)"
                
                if ollama_client.is_keyframe_animation_request(request.message):
                    routing_reason += " - Keyframe Mode"
        
        # Generate response
        response_data = await ollama_client.generate_response(
            model=model,
            prompt=request.message,
            context=enhanced_context
        )
        
        # Add assistant response to history
        assistant_message = ChatMessage(
            role="assistant",
            content=response_data.get("response", ""),
            timestamp=time.time()
        )
        conversation_store[conversation_id].append(assistant_message)
        
        processing_time = time.time() - start_time
        
        response = ChatResponse(
            response=response_data.get("response", ""),
            model_used=response_data.get("model", model),
            routing_reason=routing_reason,
            processing_time=response_data.get("processing_time", processing_time),
            thinking=response_data.get("thinking", "")
        )
        
        # Add rate limit headers
        client_ip = get_client_ip(http_request)
        remaining_requests = RATE_LIMIT_REQUESTS - len(rate_limit_store[client_ip])
        
        # Note: In a real deployment, you'd use FastAPI's Response object to set headers
        # For now, we'll include the info in the response context
        if hasattr(response, 'headers'):
            response.headers["X-RateLimit-Limit"] = str(RATE_LIMIT_REQUESTS)
            response.headers["X-RateLimit-Remaining"] = str(max(0, remaining_requests))
            response.headers["X-RateLimit-Reset"] = str(int(time.time()) + RATE_LIMIT_WINDOW)
        
        return response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chat processing failed: {str(e)}")

async def get_rig_information():
    """Get rig information from MCP cache"""
    try:
        global mcp_analytics_cache
        
        if mcp_analytics_cache:
            # Extract rig information from cached analytics
            rig_info = extract_rig_info(mcp_analytics_cache)
            return {
                "rigs_found": rig_info,
                "workspace_components": mcp_analytics_cache.get("instance_types", {}),
                "total_instances": mcp_analytics_cache.get("total_instances", 0),
                "services": mcp_analytics_cache.get("services", {})
            }
        else:
            # No analytics cached yet, return None
            return None
            
    except Exception as e:
        print(f"Failed to get rig information: {e}")
        return None

@router.post("/mcp/explorer", response_model=MCPResponse, dependencies=[Depends(verify_plugin_key)])
async def mcp_explorer(request: MCPRequest):
    """Handle MCP explorer requests from Roblox plugin"""
    try:
        if request.action == "get_tree":
            # Return a structured response for tree requests
            return MCPResponse(
                success=True,
                data={
                    "message": "Tree structure request received",
                    "action": "get_tree",
                    "timestamp": time.time(),
                    "note": "Tree data should be sent from plugin via sync_analytics"
                },
                error=None
            )
        elif request.action == "get_instance":
            # Get specific instance details
            instance_path = request.parameters.get("path", "")
            return MCPResponse(
                success=True,
                data={
                    "path": instance_path,
                    "action": "get_instance",
                    "message": f"Instance details requested for: {instance_path}",
                    "timestamp": time.time(),
                    "note": "Instance data should be sent from plugin via sync_analytics"
                },
                error=None
            )
        elif request.action == "sync_tree":
            # Receive full tree data from plugin
            tree_data = request.parameters.get("tree", {})
            if tree_data:
                # Store tree data in cache for AI context
                global mcp_analytics_cache
                if not mcp_analytics_cache:
                    mcp_analytics_cache = {}
                mcp_analytics_cache["tree_data"] = tree_data
                mcp_analytics_cache["last_tree_sync"] = time.time()
                
                return MCPResponse(
                    success=True,
                    data={
                        "message": "Tree data synchronized successfully",
                        "services_count": len(tree_data.get("services", {})),
                        "timestamp": time.time()
                    },
                    error=None
                )
            else:
                return MCPResponse(
                    success=False,
                    data=None,
                    error="No tree data provided"
                )
        elif request.action == "sync_instance":
            # Receive specific instance data from plugin
            instance_data = request.parameters.get("instance", {})
            instance_path = request.parameters.get("path", "")
            if instance_data:
                # Store instance data in cache
                global mcp_analytics_cache
                if not mcp_analytics_cache:
                    mcp_analytics_cache = {}
                if not mcp_analytics_cache.get("instances"):
                    mcp_analytics_cache["instances"] = {}
                mcp_analytics_cache["instances"][instance_path] = instance_data
                mcp_analytics_cache["last_instance_sync"] = time.time()
                
                return MCPResponse(
                    success=True,
                    data={
                        "message": "Instance data synchronized successfully",
                        "path": instance_path,
                        "timestamp": time.time()
                    },
                    error=None
                )
            else:
                return MCPResponse(
                    success=False,
                    data=None,
                    error="No instance data provided"
                )
        elif request.action == "get_analytics":
            # Get workspace analytics including rig information
            analytics_data = request.parameters.get("analytics", {})
            return MCPResponse(
                success=True,
                data={"analytics": analytics_data, "message": "Analytics received"},
                error=None
            )
        elif request.action == "sync_analytics":
            # Store analytics for AI context
            analytics_data = request.parameters.get("analytics", {})
            
            # Store in cache for use in chat requests
            global mcp_analytics_cache
            mcp_analytics_cache = analytics_data
            mcp_analytics_cache["last_sync"] = time.time()
            
            # Extract rig information from analytics
            rig_info = extract_rig_info(analytics_data)
            
            return MCPResponse(
                success=True,
                data={
                    "rigs_found": rig_info,
                    "total_analytics": analytics_data,
                    "message": f"Found {len(rig_info)} rigs in workspace",
                    "timestamp": time.time()
                },
                error=None
            )
        elif request.action == "search":
            # Handle search requests
            query = request.parameters.get("query", "")
            return MCPResponse(
                success=True,
                data={
                    "action": "search",
                    "query": query,
                    "message": f"Search request received for: {query}",
                    "note": "Search results should be sent from plugin",
                    "timestamp": time.time()
                },
                error=None
            )
        else:
            return MCPResponse(
                success=False,
                data=None,
                error=f"Unknown action: {request.action}"
            )
            
    except Exception as e:
        return MCPResponse(
            success=False,
            data=None,
            error=f"MCP request failed: {str(e)}"
        )

def extract_rig_info(analytics_data):
    """Extract rig information from analytics data"""
    rigs = []
    
    # Look for common rig components in instance types
    instance_types = analytics_data.get("instance_types", {})
    
    # Check for rig indicators
    rig_indicators = {
        "Humanoid": instance_types.get("Humanoid", 0),
        "HumanoidDescription": instance_types.get("HumanoidDescription", 0),
        "BodyColors": instance_types.get("BodyColors", 0),
        "Motor6D": instance_types.get("Motor6D", 0),
        "Weld": instance_types.get("Weld", 0),
        "MeshPart": instance_types.get("MeshPart", 0),
        "Accessory": instance_types.get("Accessory", 0)
    }
    
    # Determine if rigs are present
    total_rig_components = sum(rig_indicators.values())
    if total_rig_components > 0:
        rigs.append({
            "type": "standard_rig",
            "components": rig_indicators,
            "total_components": total_rig_components,
            "humanoid_count": rig_indicators["Humanoid"],
            "motor_count": rig_indicators["Motor6D"]
        })
    
    # Check for R15/R6 specific indicators
    if instance_types.get("Humanoid", 0) > 0:
        rigs.append({
            "type": "character_rig",
            "format": "R15" if instance_types.get("Motor6D", 0) > 0 else "R6",
            "count": instance_types.get("Humanoid", 0)
        })
    
    return rigs

@router.get("/conversations/{conversation_id}")
async def get_conversation(conversation_id: str):
    """Get conversation history"""
    if conversation_id not in conversation_store:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    return {
        "conversation_id": conversation_id,
        "messages": conversation_store[conversation_id],
        "message_count": len(conversation_store[conversation_id])
    }

@router.delete("/conversations/{conversation_id}")
async def clear_conversation(conversation_id: str):
    """Clear conversation history"""
    if conversation_id not in conversation_store:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    conversation_store[conversation_id] = []
    return {
        "conversation_id": conversation_id,
        "message": "Conversation cleared",
        "timestamp": time.time()
    }

@router.get("/health")
async def health_check():
    """Health check endpoint with rate limiting statistics"""
    current_time = time.time()
    
    # Clean up old rate limit entries for accurate stats
    for ip in list(rate_limit_store.keys()):
        rate_limit_store[ip] = deque(
            timestamp for timestamp in rate_limit_store[ip]
            if current_time - timestamp < RATE_LIMIT_WINDOW
        )
        if not rate_limit_store[ip]:
            del rate_limit_store[ip]
    
    return {
        "status": "healthy", 
        "timestamp": current_time,
        "active_conversations": len(conversation_store),
        "total_messages": sum(len(messages) for messages in conversation_store.values()),
        "rate_limiting": {
            "tracked_ips": len(rate_limit_store),
            "requests_per_minute": RATE_LIMIT_REQUESTS,
            "window_seconds": RATE_LIMIT_WINDOW,
            "total_tracked_requests": sum(len(timestamps) for timestamps in rate_limit_store.values())
        }
    }

# Cleanup on shutdown
async def cleanup():
    await ollama_client.close()
