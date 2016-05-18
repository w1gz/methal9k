#!/usr/bin/env python3

import json
import sys
from adapt.entity_tagger import EntityTagger
from adapt.tools.text.tokenizer import EnglishTokenizer
from adapt.tools.text.trie import Trie
from adapt.intent import IntentBuilder
from adapt.parser import Parser
from adapt.engine import DomainIntentDeterminationEngine


tokenizer = EnglishTokenizer()
trie = Trie()
tagger = EntityTagger(trie, tokenizer)
parser = Parser(tokenizer, tagger)
engine = DomainIntentDeterminationEngine()


# -----------------
# Domain1 - weather
# -----------------
engine.register_domain('Domain1')

# define vocabulary
weather_keyword = [
    "weather"
]
for wk in weather_keyword:
    engine.register_entity(wk, "WeatherKeyword", domain='Domain1')

weather_types = [
    "snow",
    "rain",
    "wind",
    "sleet",
    "sun"
]
for wt in weather_types:
    engine.register_entity(wt, "WeatherType", domain='Domain1')

# regex for finding the location
engine.register_regex_entity("in (?P<Location>.*)", domain='Domain1')

# structure intent
weather_intent = IntentBuilder("WeatherIntent")\
    .require("WeatherKeyword")\
    .optionally("WeatherType")\
    .require("Location")\
    .build()
engine.register_intent_parser(weather_intent, domain='Domain1')



# -----------------
# Domain2 - time
# -----------------
engine.register_domain('Domain2')

time_keywords = [
    "time"
]
for mk in time_keywords:
    engine.register_entity(mk, "TimeKeyword", domain='Domain2')

engine.register_regex_entity("in (?P<Location>.*)")

time_intent = IntentBuilder("TimeIntent")\
    .require("TimeKeyword")\
    .optionally("Location")\
    .build()
engine.register_intent_parser(time_intent, domain='Domain2')



if __name__ == "__main__":
    for intent in engine.determine_intent(' '.join(sys.argv[1:])):
        if intent and intent.get('confidence') > 0:
            print(json.dumps(intent, indent=4))
