from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import StreamingResponse
import os
import json
import asyncio
from dotenv import load_dotenv

from .router import router, cleanup

# Load environment variables
load_dotenv()

# Create FastAPI app
app = FastAPI(
    title="Lumina API",
    description="AI-powered platform for Roblox Studio development",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],  # React dev server
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(router)

# Serve static files (for production)
if os.path.exists("../frontend/build"):
    app.mount("/static", StaticFiles(directory="../frontend/build"), name="static")

@app.get("/")
async def root():
    return {
        "message": "Lumina API - AI-powered platform for Roblox Studio",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/api/health",
        "streaming_chat": "/api/chat/stream"
    }

@app.post("/api/chat/stream")
async def stream_chat(request_data: dict):
    """Streaming chat endpoint for real-time response typing"""
    from .router import ollama_client, conversation_store, check_rate_limit, get_client_ip
    from .models import ChatRequest, ChatMessage, ModelType
    
    async def generate_stream():
        try:
            # Parse request data
            message = request_data.get("message", "")
            model_name = request_data.get("model")
            context = request_data.get("context", {})
            conversation_id = request_data.get("conversation_id")
            source = request_data.get("source", "web")
            
            # Create ChatRequest object
            chat_request = ChatRequest(
                message=message,
                model=ModelType(model_name) if model_name else None,
                context=context,
                source=source,
                conversation_id=conversation_id
            )
            
            # Initialize conversation if needed
            if conversation_id and conversation_id not in conversation_store:
                conversation_store[conversation_id] = []
            
            # Add user message to history
            if conversation_id:
                user_message = ChatMessage(
                    role="user",
                    content=message,
                    timestamp=asyncio.get_event_loop().time()
                )
                conversation_store[conversation_id].append(user_message)
            
            # Determine model
            if model_name:
                model = ModelType(model_name)
                routing_reason = "User specified model"
            else:
                model = ollama_client.route_model(message)
                routing_reason = "Smart routing based on content"
            
            # Build enhanced context
            enhanced_context = context.copy() if context else {}
            if conversation_id and len(conversation_store[conversation_id]) > 1:
                enhanced_context["conversation_history"] = [
                    {"role": msg.role, "content": msg.content} 
                    for msg in conversation_store[conversation_id][-6:]
                ]
                enhanced_context["has_history"] = True
                routing_reason += " (with conversation context)"
            
            # Send initial metadata
            yield f"data: {json.dumps({'type': 'start', 'model': model, 'routing_reason': routing_reason})}\n\n"
            
            # Generate response with streaming
            payload = {
                "model": model,
                "prompt": message,
                "stream": True,
                "options": {
                    "temperature": 0.7,
                    "top_p": 0.9,
                    "max_tokens": 2000
                }
            }
            
            # Stream from Ollama
            async with ollama_client.client.stream(
                f"{ollama_client.base_url}/api/generate",
                json=payload
            ) as response:
                full_response = ""
                thinking = ""
                is_thinking = False
                
                async for line in response.aiter_lines():
                    if line.strip():
                        try:
                            data = json.loads(line)
                            if "response" in data:
                                chunk = data["response"]
                                full_response += chunk
                                
                                # Check for thinking patterns in DeepSeek responses
                                if model == ModelType.DEEPSEEK:
                                    thinking_patterns = ["<thinking>", "let me think", "i need to consider", "first, i'll"]
                                    chunk_lower = chunk.lower()
                                    
                                    if any(pattern in chunk_lower for pattern in thinking_patterns):
                                        is_thinking = True
                                    
                                    if is_thinking:
                                        thinking += chunk
                                        yield f"data: {json.dumps({'type': 'thinking', 'content': chunk})}\n\n"
                                    else:
                                        yield f"data: {json.dumps({'type': 'content', 'content': chunk})}\n\n"
                                else:
                                    yield f"data: {json.dumps({'type': 'content', 'content': chunk})}\n\n"
                                
                            if data.get("done", False):
                                break
                        except json.JSONDecodeError:
                            continue
                
                # Add assistant response to history
                if conversation_id:
                    assistant_message = ChatMessage(
                        role="assistant",
                        content=full_response,
                        timestamp=asyncio.get_event_loop().time()
                    )
                    conversation_store[conversation_id].append(assistant_message)
                
                # Send completion message
                yield f"data: {json.dumps({'type': 'done', 'response': full_response, 'thinking': thinking})}\n\n"
                
        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'error': str(e)})}\n\n"
    
    return StreamingResponse(
        generate_stream(),
        media_type="text/plain",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Content-Type": "text/event-stream"
        }
    )

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on application shutdown"""
    await cleanup()

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=True
    )
