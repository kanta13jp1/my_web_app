---
title: "LLM Prompt Engineering in Practice: CoT, Few-Shot, and System Prompt Design"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# LLM Prompt Engineering in Practice: CoT, Few-Shot, and System Prompt Design

Stop getting mediocre answers from great models. Practical prompt engineering techniques from real indie dev usage.

## Why Prompt Design Matters

```
Same model, same question — different prompts:
  Poor prompt design  → "adequate answer"
  Good prompt design  → "exceeds expectation"

Cost implication:
  haiku + excellent prompt  vs  sonnet + sloppy prompt
  → Same quality, 4× cost difference
```

## 1. System Prompt: Define the Role Precisely

```python
# ❌ BAD: vague role
system = "You are an AI assistant."

# ✅ GOOD: specific role + constraints + output format
system = """You are a productivity coach for indie developers.

## Your role
- Prioritize daily tasks
- Identify focus blockers
- Give actionable improvement suggestions

## Response rules
- Maximum 3 suggestions (more creates confusion)
- Avoid overly technical jargon
- End each suggestion with a concrete "try this" action

## Do not
- Give medical, legal, or investment advice
- Frame suggestions as criticism of the user's behavior"""
```

**Claude API**:

```python
response = client.messages.create(
  model="claude-haiku-4-5",
  system=system,  # system parameter, not injected in messages
  messages=[{"role": "user", "content": user_input}]
)
```

## 2. Chain of Thought (CoT): Make the Model Think Step by Step

```python
# ❌ BAD: ask for conclusion directly (reasoning gets sloppy)
prompt = "Should I do this task today?"

# ✅ GOOD: specify the reasoning steps
prompt = """Evaluate the following task.

Task: {task}

Reasoning steps:
1. Check deadline (today / this week / later)
2. Check impact (affects only me / affects others)
3. Estimate time (under 15 min / over 1 hour)
4. Based on above: do today / do this week / defer

Think through each step before giving your final answer."""
```

**When CoT helps vs. doesn't**:

```
✅ Use CoT for:
  Multi-condition decisions
  Math and logical reasoning
  Bug root cause analysis
  Text quality evaluation

❌ Skip CoT for:
  Simple classification (sentiment analysis)
  Short text generation
  → haiku + simple prompt is enough
```

## 3. Few-Shot: Lock Down the Output Format With Examples

```python
# ❌ BAD: describe the format only
prompt = "Classify this task into 3 priority levels."

# ✅ GOOD: show examples
prompt = """Classify each task by priority.

Example:
Input: "Gather documents for tax return (deadline: March 15)"
Output: Priority: HIGH | Reason: hard deadline, legal requirement | Today's action: locate withholding slip

Input: "Organize bookshelf"
Output: Priority: LOW | Reason: no deadline, low impact | Today's action: add to backlog list

Now classify:
Input: {task}
Output:"""
```

## 4. Prompt Caching — 89% Cost Reduction

```python
# Cache the system prompt after the first request
messages = [
  {
    "role": "user",
    "content": [
      {
        "type": "text",
        "text": long_system_prompt,  # 2000+ tokens
        "cache_control": {"type": "ephemeral"}  # mark for caching
      },
      {
        "type": "text",
        "text": user_input
      }
    ]
  }
]

# First call: normal cost
# Subsequent calls (within 5 min): cache hit → ~90% input cost reduction
```

## Version Control Your Prompts

```python
# prompts.py — treat prompts like code
PRODUCTIVITY_COACH_V1 = "..."
PRODUCTIVITY_COACH_V2 = """
...
[v2: switched output to JSON format]
"""

# Test with promptfoo
# promptfoo.yaml
prompts:
  - id: v1
    raw: "{{PRODUCTIVITY_COACH_V1}}"
  - id: v2
    raw: "{{PRODUCTIVITY_COACH_V2}}"

tests:
  - vars:
      task: "Prepare presentation slides"
    assert:
      - type: contains
        value: "Priority"
```

## Summary

```
Define role, constraints, format → System Prompt
Complex decisions                → Chain of Thought
Lock output structure            → Few-Shot examples
Cut API costs                    → Prompt Caching (cache_control)
Maintain quality over time       → Version control + promptfoo
```

Prompt engineering is spec-writing for the model. A precise system prompt plus a handful of examples consistently beats long explanations — and runs cheaper on haiku than sloppy prompts on sonnet.

