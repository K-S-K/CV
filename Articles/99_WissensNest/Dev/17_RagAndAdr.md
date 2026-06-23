# WissensNest

## RAG (Article for the future development)

**RAG vs Tool Calling** specifically means: retrieve relevant text chunks from a knowledge base (usually via vector/semantic search) and inject them into the prompt before generation. The model sees documents, then generates.

**Tool calling** means: the model actively decides mid-generation to call a function, gets a result, and continues. It's the model _pulling_ data on demand.

They share the same goal — giving the model information beyond its training data — but the mechanism is different:

| | RAG | Tool Calling |
| --- | --- | ------------ |
| When | Before generation | During generation |
| Who decides | System/retriever | The model |
| Source | Document chunks / embeddings | APIs, functions, services |
| Example | "Here are 3 relevant passages from your docs..." | getWeather("Munich") → {temp: 12°C} |

Some people use "RAG" loosely to cover both, and in marketing copy that's sometimes acceptable. But in a discussion with .NET/backend developers, calling tool calling "RAG" would be inaccurate and could hurt credibility with people who know the difference.

The tools that we have, are genuinely RAG-adjacent is this: the PromptSnapshot mechanism (injecting stored prompt content into every conversation) is structurally similar to RAG — it's context injection at generation time. The planned persistent memory layer (user facts injected into every conversation) will be even closer to RAG in spirit.

The tool framework is best described as tool/function calling or agentic data retrieval — which is its own valuable and marketable capability.
