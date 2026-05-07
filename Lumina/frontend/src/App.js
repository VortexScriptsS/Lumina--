import React, { useState, useEffect } from 'react';
import {
  Container,
  Grid,
  Paper,
  Typography,
  TextField,
  Button,
  Box,
  Chip,
  CircularProgress,
  Alert,
  Card,
  CardContent,
  Divider
} from '@mui/material';
import {
  Send as SendIcon,
  SmartToy as BotIcon,
  Code as CodeIcon,
  Animation as AnimationIcon
} from '@mui/icons-material';
import axios from 'axios';
import ReactMarkdown from 'react-markdown';

function App() {
  const [message, setMessage] = useState('');
  const [chatHistory, setChatHistory] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [models, setModels] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchModels();
  }, []);

  const fetchModels = async () => {
    try {
      const response = await axios.get('/api/models');
      setModels(response.data);
    } catch (err) {
      console.error('Failed to fetch models:', err);
    }
  };

  const sendMessage = async () => {
    if (!message.trim()) return;

    const userMessage = {
      type: 'user',
      content: message,
      timestamp: new Date().toISOString()
    };

    setChatHistory(prev => [...prev, userMessage]);
    setMessage('');
    setIsLoading(true);
    setError('');

    try {
      const response = await axios.post('/api/chat', {
        message: message,
        source: 'web'
      });

      const botMessage = {
        type: 'bot',
        content: response.data.response,
        model: response.data.model_used,
        routingReason: response.data.routing_reason,
        processingTime: response.data.processing_time,
        thinking: response.data.thinking || '',
        timestamp: new Date().toISOString()
      };

      setChatHistory(prev => [...prev, botMessage]);
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to send message');
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const getModelIcon = (model) => {
    if (model.includes('deepseek')) {
      return <AnimationIcon />;
    }
    return <CodeIcon />;
  };

  const getModelColor = (model) => {
    if (model.includes('deepseek')) {
      return 'secondary';
    }
    return 'primary';
  };

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Box sx={{ mb: 4, textAlign: 'center' }}>
        <Typography variant="h3" component="h1" gutterBottom>
          Lumina
        </Typography>
        <Typography variant="subtitle1" color="text.secondary">
          AI-Powered Platform for Roblox Studio Development
        </Typography>
      </Box>

      <Grid container spacing={3}>
        <Grid item xs={12} md={8}>
          <Paper sx={{ p: 3, height: '70vh', display: 'flex', flexDirection: 'column' }}>
            <Typography variant="h6" gutterBottom>
              Chat Interface
            </Typography>
            
            <Box sx={{ flexGrow: 1, overflow: 'auto', mb: 2 }}>
              {chatHistory.map((msg, index) => (
                <Box key={index} sx={{ mb: 2 }}>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 1 }}>
                    {msg.type === 'user' ? (
                      <Typography variant="subtitle2" color="primary">
                        You
                      </Typography>
                    ) : (
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <BotIcon fontSize="small" />
                        <Typography variant="subtitle2" color="text.secondary">
                          AI Assistant
                        </Typography>
                        {msg.model && (
                          <Chip
                            icon={getModelIcon(msg.model)}
                            label={msg.model}
                            size="small"
                            color={getModelColor(msg.model)}
                            variant="outlined"
                          />
                        )}
                      </Box>
                    )}
                  </Box>
                  
                  <Paper
                    sx={{
                      p: 2,
                      ml: msg.type === 'user' ? 4 : 0,
                      mr: msg.type === 'bot' ? 4 : 0,
                      bgcolor: msg.type === 'user' ? 'primary.dark' : 'background.paper'
                    }}
                  >
                    <ReactMarkdown>{msg.content}</ReactMarkdown>
                    
                    {msg.thinking && msg.thinking !== '' && (
                      <Box sx={{ mt: 2, p: 2, bgcolor: 'background.default', borderRadius: 1 }}>
                        <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 'bold' }}>
                          🧠 AI Thinking Process:
                        </Typography>
                        <Typography variant="body2" color="text.secondary" sx={{ mt: 1, fontStyle: 'italic' }}>
                          {msg.thinking}
                        </Typography>
                      </Box>
                    )}
                  </Paper>
                  
                  {msg.routingReason && (
                    <Typography variant="caption" color="text.secondary" sx={{ ml: 2 }}>
                      Model selected: {msg.routingReason} • {msg.processingTime.toFixed(2)}s
                      {msg.thinking && msg.thinking !== '' && ' • 🧠 Deep analysis'}
                    </Typography>
                  )}
                </Box>
              ))}
              
              {isLoading && (
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                  <CircularProgress size={20} />
                  <Typography variant="body2" color="text.secondary">
                    AI is thinking...
                  </Typography>
                </Box>
              )}
            </Box>

            {error && (
              <Alert severity="error" sx={{ mb: 2 }}>
                {error}
              </Alert>
            )}

            <Box sx={{ display: 'flex', gap: 1 }}>
              <TextField
                fullWidth
                multiline
                maxRows={3}
                variant="outlined"
                placeholder="Ask about Lua scripting, animations, math calculations, or Roblox development..."
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                onKeyPress={handleKeyPress}
                disabled={isLoading}
              />
              <Button
                variant="contained"
                onClick={sendMessage}
                disabled={isLoading || !message.trim()}
                sx={{ minWidth: '120px' }}
              >
                <SendIcon sx={{ mr: 1 }} />
                Send
              </Button>
            </Box>
          </Paper>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ mb: 2 }}>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Available Models
              </Typography>
              {models.length > 0 ? (
                models.map((model, index) => (
                  <Box key={index} sx={{ mb: 1 }}>
                    <Typography variant="body2">
                      {model.name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      Size: {model.size}
                    </Typography>
                  </Box>
                ))
              ) : (
                <Typography variant="body2" color="text.secondary">
                  Loading models...
                </Typography>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Smart Routing
              </Typography>
              <Divider sx={{ mb: 2 }} />
              
              <Box sx={{ mb: 2 }}>
                <Chip
                  icon={<AnimationIcon />}
                  label="Animation/Math"
                  color="secondary"
                  variant="outlined"
                  sx={{ mb: 1 }}
                />
                <Typography variant="caption" display="block" color="text.secondary">
                  deepseek-r1-distill-qwen-7b
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Topics: animation, movement, math, physics, vectors
                </Typography>
              </Box>

              <Box>
                <Chip
                  icon={<CodeIcon />}
                  label="Coding/Scripting"
                  color="primary"
                  variant="outlined"
                  sx={{ mb: 1 }}
                />
                <Typography variant="caption" display="block" color="text.secondary">
                  qwen2.5-coder-7b
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Topics: Lua scripting, Roblox API, general coding
                </Typography>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Container>
  );
}

export default App;
