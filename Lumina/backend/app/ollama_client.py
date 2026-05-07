import httpx
import asyncio
import time
from typing import Optional, Dict, Any
from .models import ModelType, ModelInfo

class OllamaClient:
    def __init__(self, base_url: str = "http://localhost:11434"):
        self.base_url = base_url.rstrip('/')
        self.client = httpx.AsyncClient(timeout=60.0)
    
    async def list_models(self) -> list[ModelInfo]:
        """List all available Ollama models"""
        try:
            response = await self.client.get(f"{self.base_url}/api/tags")
            response.raise_for_status()
            data = response.json()
            
            models = []
            for model in data.get('models', []):
                models.append(ModelInfo(
                    name=model.get('name', ''),
                    description=model.get('description', ''),
                    size=str(model.get('size', '')),
                    modified_at=model.get('modified_at', '')
                ))
            return models
        except Exception as e:
            print(f"Error listing models: {e}")
            return []
    
    async def generate_response(
        self, 
        model: ModelType, 
        prompt: str, 
        context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Generate response from specified model"""
        start_time = time.time()
        
        # Roblox-specific system prompt for Luau syntax compliance
        roblox_system_prompt = """You are an expert Roblox developer and AI assistant specializing in Luau scripting, animation, and game development. 

IMPORTANT LUAU SYNTAX RULES:
- Use 'local' for variable declarations, not 'var' or 'let'
- Roblox uses 'task.spawn()' and 'task.wait()' instead of deprecated 'spawn()' and 'wait()'
- Use 'Instance.new()' to create objects, not 'new()'
- Proper event handling: Connect functions with ':Connect()'
- Use CFrame.new() for positions and rotations in 3D space
- Use Vector3.new() for 3D vectors
- Use Color3.new() for colors
- Use 'game:GetService()' to access Roblox services
- Use 'pcall()' for safe error handling
- Avoid global variables (_G) - use local scope or ModuleScripts
- Use proper parenting: instance.Parent = workspace
- For animations, use KeyframeSequence and Pose instances
- Use 'typeof()' instead of 'type()' for Roblox types

ROBLOX SERVICES:
- Workspace: 3D world container
- ServerScriptService: Server-side scripts
- ReplicatedStorage: Shared storage
- Players: Player management
- Lighting: Lighting and atmosphere
- StarterGui: UI elements
- Teams: Team management
- SoundService: Audio management

CODE EXAMPLES:
local part = Instance.new("Part")
part.Parent = workspace
part.Position = Vector3.new(0, 10, 0)

local humanoid = character:FindFirstChildOfClass("Humanoid")
if humanoid then
    humanoid:MoveTo(targetPosition)
end

task.spawn(function()
    task.wait(2)
    print("Delayed action")
end)

When providing code, ensure it follows Roblox Luau best practices and is immediately runnable in Roblox Studio."""
        
        # Build the full prompt with context if provided
        full_prompt = prompt
        if context:
            context_parts = []
            
            # Add conversation history if available
            if context.get("has_history") and context.get("conversation_history"):
                history = context["conversation_history"]
                context_parts.append("Conversation History:")
                for msg in history[-6:]:  # Last 6 messages for context
                    context_parts.append(f"  {msg['role']}: {msg['content']}")
                context_parts.append("")
            
            # Add regular context
            for k, v in context.items():
                if k not in ["rig_information", "has_rigs", "conversation_history", "has_history"]:
                    context_parts.append(f"{k}: {v}")
            
            # Add rig information for animation requests
            if context.get("has_rigs") and context.get("rig_information"):
                rig_info = context["rig_information"]
                rig_context = self._build_rig_context(rig_info)
                context_parts.append(f"Workspace Rig Analysis:\n{rig_context}")
            
            if context_parts:
                context_str = "\n".join(context_parts)
                full_prompt = f"Context:\n{context_str}\n\nUser: {prompt}"
        
        # Prepend the system prompt
        full_prompt = f"{roblox_system_prompt}\n\n{full_prompt}"
        
        # Special handling for DeepSeek models to capture thinking process
        if model == ModelType.DEEPSEEK:
            animation_instruction = ""
            if context and context.get("has_rigs"):
                if self.is_keyframe_animation_request(full_prompt):
                    animation_instruction = "\n\nIMPORTANT: This is a keyframe animation request. Output a JSON table representing a KeyframeSequence. Include Time for each keyframe and CFrame data for every bone. Format as valid Lua JSON that can be parsed by the plugin."
                else:
                    animation_instruction = "\n\nIMPORTANT: Write animation code specific to rigs found in workspace. Use the rig information to create appropriate animations for the detected character types."
            
            full_prompt = f"Please think step by step and show your reasoning process. Then provide the final answer following Roblox Luau syntax rules.{animation_instruction}\n\n{full_prompt}"
        
        payload = {
            "model": model,
            "prompt": full_prompt,
            "stream": False,
            "options": {
                "temperature": 0.7,
                "top_p": 0.9,
                "max_tokens": 2000
            }
        }
        
        try:
            response = await self.client.post(
                f"{self.base_url}/api/generate",
                json=payload
            )
            response.raise_for_status()
            data = response.json()
            
            response_text = data.get('response', '')
            
            # Extract thinking process from DeepSeek responses
            thinking = ""
            final_answer = response_text
            
            if model == ModelType.DEEPSEEK:
                # Look for thinking patterns in DeepSeek responses
                thinking_patterns = [
                    "<thinking>", "Let me think", "I need to consider",
                    "First, I'll", "Let me analyze", "Thinking step by step",
                    "I should consider", "The approach I'll take"
                ]
                
                lines = response_text.split('\n')
                thinking_lines = []
                answer_lines = []
                capture_thinking = False
                
                for line in lines:
                    line_lower = line.lower()
                    if any(pattern in line_lower for pattern in thinking_patterns):
                        capture_thinking = True
                        thinking_lines.append(line)
                    elif capture_thinking and (line.strip() == "" or 
                                            any(marker in line_lower for marker in ["answer:", "solution:", "final:", "result:"])):
                        if any(marker in line_lower for marker in ["answer:", "solution:", "final:", "result:"]):
                            capture_thinking = False
                            answer_lines.append(line)
                        else:
                            thinking_lines.append(line)
                    elif not capture_thinking:
                        answer_lines.append(line)
                    else:
                        thinking_lines.append(line)
                
                if thinking_lines:
                    thinking = '\n'.join(thinking_lines).strip()
                if answer_lines:
                    final_answer = '\n'.join(answer_lines).strip()
            
            return {
                "response": final_answer,
                "thinking": thinking if model == ModelType.DEEPSEEK else "",
                "model": model,
                "processing_time": time.time() - start_time
            }
            
        except Exception as e:
            print(f"Error generating response: {e}")
            return {
                "response": f"Error: Failed to generate response from {model}. Details: {str(e)}",
                "thinking": "",
                "model": model,
                "processing_time": time.time() - start_time
            }
    
    def route_model(self, message: str) -> ModelType:
        """Smart routing based on message content"""
        message_lower = message.lower()
        
        # Keywords that suggest animation/math tasks
        animation_keywords = [
            'animation', 'animate', 'movement', 'tween', 'lerp',
            'math', 'calculation', 'formula', 'equation', 'geometry',
            'vector', 'matrix', 'rotation', 'position', 'physics',
            'trajectory', 'interpolation', 'easing', 'curve',
            'move', 'animate', 'rotate', 'cframe'
        ]
        
        # Check if message contains animation/math keywords
        for keyword in animation_keywords:
            if keyword in message_lower:
                return ModelType.DEEPSEEK
        
        # Default to coding model
        return ModelType.QWEN_CODER
    
    def is_animation_request(self, message: str) -> bool:
        """Check if message is requesting animation help"""
        message_lower = message.lower()
        
        animation_keywords = [
            'animation', 'animate', 'movement', 'tween', 'lerp',
            'move', 'rotate', 'cframe', 'position',
            'physics', 'trajectory', 'interpolation', 'easing'
        ]
        
        return any(keyword in message_lower for keyword in animation_keywords)
    
    def is_keyframe_animation_request(self, message: str) -> bool:
        """Check if message is requesting static/recorded animation"""
        message_lower = message.lower()
        
        keyframe_keywords = [
            'static', 'recorded', 'keyframe', 'sequence',
            'pose', 'animation sequence', 'frame by frame',
            'make a.*animation', 'create.*animation'
        ]
        
        return any(keyword in message_lower for keyword in keyframe_keywords)
    
    def _build_rig_context(self, rig_info: Dict[str, Any]) -> str:
        """Build formatted rig context for AI prompt"""
        context_lines = []
        
        if "rigs_found" in rig_info:
            for rig in rig_info["rigs_found"]:
                if rig.get("type") == "character_rig":
                    context_lines.append(f"- Found {rig.get('count', 0)} character rigs ({rig.get('format', 'Unknown')} format)")
                elif rig.get("type") == "standard_rig":
                    context_lines.append(f"- Found standard rig with {rig.get('humanoid_count', 0)} humanoids and {rig.get('motor_count', 0)} motors")
        
        if "workspace_components" in rig_info:
            components = rig_info["workspace_components"]
            context_lines.append("- Key components in workspace:")
            for component, count in components.items():
                if count > 0:
                    context_lines.append(f"  * {component}: {count}")
        
        return "\n".join(context_lines)
    
    async def close(self):
        """Close the HTTP client"""
        await self.client.aclose()
