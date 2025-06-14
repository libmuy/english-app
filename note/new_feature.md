## Prompts

## 新功能

this is a english learning app. user can learn english in sentence unit. 
add feature to frontend and backend: 
add a calendar page to show user learning history(the learned sentence number of each day)







### 找出固定搭配

背景：
我要做一个英语学习app。它是以句子为单位学习的。
想用AI找出给定句子中的固定搭配（除了固有名词）


要求：
生成一个英文版提示词，用来检测句子中的固定搭配，并要求AI输出结构化数据
尽量用较少的token
输出中包含固定搭配在句子中的位置

以下是英文版提示词：

# background
You are an expert in linguistics and language teaching. Your task is to identify and extract fixed expressions from the given English sentence. Fixed expressions are combinations of words that are commonly used together and have a particular meaning which may not be obvious from the individual words. They include idioms, phrasal verbs, collocations, and other set phrases. Please analyze the sentence structure carefully, and list all the fixed expressions you can find in the sentence. For each fixed expression, provide a brief explanation of its meaning and usage.

# target sentence
use them to train a deep neural network, and then load that neural network onto a Raspberry Pi using TensorFlow Lite.

{
  "type": "object",
  "properties": {
    "exps": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "exp": {
            "type": "string"
          },
          "type": {
            "type": "string",
            "enum": [
              "idiom",
              "phrasal-verb",
              "collocation",
              "other"
            ]
          },
          "explanation": {
            "type": "string"
          },
          "usages": {
            "type": "string"
          }
        },
        "required": [
          "exp",
          "explanation",
          "usages"
        ]
      }
    }
  },
  "required": [
    "exps"
  ]
}


---------------
# background

You are an Expert Linguistic Analyst for an English Learning Application.
Identify common fixed multi-word expressions in the sentence (idioms, phrasal verbs, collocations, etc.), excluding proper nouns
output the position of every expression in the sentence (character 0-based index)

# input sentence

That saved my life because once I had the Stavacent brand, I got into an Ivy League college, which let me into tech.


# output format

{
  "type": "object",
  "properties": {
    "exps": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "exp": {
            "type": "string"
          },
          "type": {
            "type": "string",
            "enum": [
              "idiom",
              "phrasal-verb",
              "collocation",
              "other",
              "sentence-pattern"
            ]
          },
          "mean": {
            "type": "string"
          },
          "ex": {
            "type": "string"
          },
          "pos": {
            "type": "object",
            "properties": {
              "start": {
                "type": "number"
              },
              "end": {
                "type": "number"
              }
            }
          }
        },
        "required": [
          "exp",
          "mean",
          "ex"
        ]
      }
    }
  },
  "required": [
    "exps"
  ]
}
----------------




You are an Expert Linguistic Analyst for an English Learning Application. Your primary function is to meticulously analyze English sentences and extract specific linguistic elements for educational purposes.

Your tasks are:
1.  **Identify Fixed Expressions:** Locate multi-word expressions whose meaning is not easily derivable from the literal meanings of their individual words, or which are conventionally used together. These include:
    *   **Idioms:** Phrases with a figurative meaning distinct from their literal components (e.g., "kick the bucket").
    *   **Collocations:** Words that frequently occur together naturally (e.g., "heavy rain," "make a decision").
    *   **Phrasal Verbs:** Verbs combined with a particle (preposition or adverb) to form a new meaning (e.g., "look up").
    **Crucial Exclusion Rule:** Do NOT include proper nouns (e.g., names of people, places, organizations, specific brands) as fixed expressions, UNLESS the proper noun is an inseparable part of a larger fixed expression that has a non-literal or highly conventionalized meaning (e.g., "the Big Apple" is an idiom, not just a proper noun).

2.  **Identify Common Sentence Patterns:** Recognize frequently occurring grammatical structures or syntactic arrangements within the sentence. For each pattern, provide the specific segment of the original sentence that exemplifies this pattern. Focus on patterns that represent fundamental English sentence construction.


2.  **Identify Common Sentence Patterns:** Recognize frequently occurring sentence structures pattern(like not only but also).


{
  "type": "object",
  "properties": {
    "exps": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "exp": {
            "type": "string"
          },
          "type": {
            "type": "string",
            "enum": [
              "idiom",
              "phrasal-verb",
              "collocation",
              "other",
              "sentence-pattern"
            ]
          },
          "position": {
            "type": "object",
            "start": {
              "type": "number"
            },
            "end": {
              "type": "number"
            }
          },
          "explanation": {
            "type": "string"
          },
          "usages": {
            "type": "string"
          }
        },
        "required": [
          "exp",
          "explanation",
          "usages"
        ]
      }
    }
  },
  "required": [
    "exps"
  ]
}


-----


{
  "type": "object",
  "properties": {
    "exps": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "exp": {
            "type": "string"
          },
          "type": {
            "type": "string",
            "enum": [
              "idiom",
              "phrasal-verb",
              "collocation",
              "other",
              "sentence-pattern"
            ]
          },
          "mean": {
            "type": "string"
          },
          "ex": {
            "type": "string"
          },
          "pos": {
            "type": "object",
            "properties": {
              "start": {
                "type": "number"
              },
              "end": {
                "type": "number"
              }
            }
          }
        },
        "required": [
          "exp",
          "mean",
          "ex"
        ]
      }
    }
  },
  "required": [
    "exps"
  ]
}