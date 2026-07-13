// Any OpenAI-compatible chat completions API. Defaults to a local
// Ollama running qwen3:1.7b (same setup as the PawSwipe server).
const AI_BASE_URL = process.env.AI_BASE_URL || 'http://localhost:11434/v1';
const AI_API_KEY = process.env.AI_API_KEY || 'ollama';

export const AI_MODEL = process.env.AI_MODEL || 'qwen3:1.7b';

/** Soft switch that stops qwen3 spending its tokens on reasoning. */
export const NO_THINK = ' /no_think';

/** qwen3 is a reasoning model: strip any leaked <think> blocks. */
export function cleanReply(content: string | null | undefined): string {
  return (content || '')
    .replace(/<think>[\s\S]*?<\/think>/g, '')
    .trim();
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export async function chatCompletion(
  messages: ChatMessage[],
  opts: { temperature?: number; maxTokens?: number } = {},
): Promise<string> {
  const response = await fetch(`${AI_BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${AI_API_KEY}`,
    },
    body: JSON.stringify({
      model: AI_MODEL,
      messages,
      temperature: opts.temperature ?? 0.8,
      max_tokens: opts.maxTokens ?? 2048,
    }),
  });
  if (!response.ok) {
    throw new Error(`AI request failed: ${response.status} ${await response.text()}`);
  }
  const data: any = await response.json();
  return cleanReply(data.choices?.[0]?.message?.content);
}

/**
 * Extract a JSON value from an LLM reply that may wrap it in markdown
 * fences or prose. Small models rarely return perfectly bare JSON.
 */
export function extractJson<T>(raw: string): T {
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : raw;
  const start = candidate.search(/[[{]/);
  if (start === -1) throw new Error('No JSON found in AI reply');
  // Walk back from the end until JSON.parse succeeds
  for (let end = candidate.length; end > start; end--) {
    const slice = candidate.slice(start, end).trim();
    if (!slice.endsWith('}') && !slice.endsWith(']')) continue;
    try {
      return JSON.parse(slice) as T;
    } catch {
      /* keep walking */
    }
  }
  throw new Error('Unparseable JSON in AI reply');
}
