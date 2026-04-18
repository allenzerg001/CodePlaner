import * as crypto from 'crypto';

function uuidHex24(): string {
  return crypto.randomUUID().replace(/-/g, '').slice(0, 24);
}

export function openaiToAnthropicRequest(req: any): any {
  const messages = req.messages || [];
  let system = "";
  const anthropicMessages: any[] = [];

  for (const msg of messages) {
    if (msg.role === "system") {
      system = msg.content;
    } else if (msg.role === "tool") {
      anthropicMessages.push({
        role: "user",
        content: [
          {
            type: "tool_result",
            tool_use_id: msg.tool_call_id || "",
            content: msg.content,
          }
        ],
      });
    } else {
      anthropicMessages.push(msg);
    }
  }

  const result: any = {
    model: req.model || "",
    messages: anthropicMessages,
    max_tokens: req.max_tokens || 4096,
  };

  if (system) {
    result.system = system;
  }
  if (req.temperature !== undefined) {
    result.temperature = req.temperature;
  }

  const tools = req.tools;
  if (tools) {
    result.tools = tools.map((t: any) => {
      const fn = t.function || {};
      return {
        name: fn.name || "",
        description: fn.description || "",
        input_schema: fn.parameters || { type: "object", properties: {} },
      };
    });
  }

  return result;
}

export function anthropicToOpenAIRequest(req: any): any {
  const messages: any[] = [];
  const system = req.system || "";
  if (system) {
    messages.push({ role: "system", content: system });
  }

  for (const msg of (req.messages || [])) {
    const content = msg.content || "";
    if (Array.isArray(content)) {
      const textParts: string[] = [];
      for (const part of content) {
        if (part.type === "text") {
          textParts.push(part.text);
        } else if (part.type === "tool_result") {
          messages.push({
            role: "tool",
            tool_call_id: part.tool_use_id || "",
            content: part.content || "",
          });
        }
      }
      if (textParts.length > 0) {
        messages.push({ role: msg.role, content: textParts.join("\n") });
      }
    } else {
      messages.push(msg);
    }
  }

  const result: any = {
    model: req.model || "",
    messages: messages,
  };

  if (req.max_tokens !== undefined) {
    result.max_tokens = req.max_tokens;
  }
  if (req.temperature !== undefined) {
    result.temperature = req.temperature;
  }

  const tools = req.tools;
  if (tools) {
    result.tools = tools.map((t: any) => ({
      type: "function",
      function: {
        name: t.name || "",
        description: t.description || "",
        parameters: t.input_schema || {},
      },
    }));
  }

  return result;
}

export function openaiToAnthropicResponse(resp: any): any {
  const choice = (resp.choices && resp.choices[0]) || {};
  const message = choice.message || {};
  const usage = resp.usage || {};

  const content: any[] = [];
  const finishReason = choice.finish_reason || "stop";

  const toolCalls = message.tool_calls;
  if (toolCalls && toolCalls.length > 0) {
    for (const tc of toolCalls) {
      content.push({
        type: "tool_use",
        id: tc.id || `toolu_${uuidHex24()}`,
        name: tc.function?.name || "",
        input: JSON.parse(tc.function?.arguments || "{}"),
      });
    }
  } else if (message.content) {
    content.push({ type: "text", text: message.content });
  }

  const stopReasonMap: Record<string, string> = {
    "stop": "end_turn",
    "length": "max_tokens",
    "tool_calls": "tool_use",
  };

  return {
    id: `msg_${resp.id || uuidHex24()}`,
    type: "message",
    role: "assistant",
    content: content,
    model: resp.model || "",
    stop_reason: stopReasonMap[finishReason] || "end_turn",
    usage: {
      input_tokens: usage.prompt_tokens || 0,
      output_tokens: usage.completion_tokens || 0,
    },
  };
}

export function anthropicToOpenAIResponse(resp: any): any {
  const content = resp.content || [];
  const usage = resp.usage || {};

  const textParts: string[] = [];
  const toolCalls: any[] = [];
  for (const part of content) {
    if (part.type === "text") {
      textParts.push(part.text);
    } else if (part.type === "tool_use") {
      toolCalls.push({
        id: part.id || "",
        type: "function",
        function: {
          name: part.name || "",
          arguments: JSON.stringify(part.input || {}),
        },
      });
    }
  }

  const stopReasonMap: Record<string, string> = {
    "end_turn": "stop",
    "max_tokens": "length",
    "tool_use": "tool_calls",
  };

  const message: any = {
    role: "assistant",
    content: textParts.length > 0 ? textParts.join("\n") : null,
  };
  if (toolCalls.length > 0) {
    message.tool_calls = toolCalls;
  }

  return {
    id: `chatcmpl-${resp.id || uuidHex24()}`,
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: resp.model || "",
    choices: [
      {
        index: 0,
        message: message,
        finish_reason: stopReasonMap[resp.stop_reason] || "stop",
      }
    ],
    usage: {
      prompt_tokens: usage.input_tokens || 0,
      completion_tokens: usage.output_tokens || 0,
      total_tokens: (usage.input_tokens || 0) + (usage.output_tokens || 0),
    },
  };
}
