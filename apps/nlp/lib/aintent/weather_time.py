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


def register_weather():
    engine.register_domain('Domain1')

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

    engine.register_regex_entity("in (?P<Location>.*)", domain='Domain1')

    weather_intent = IntentBuilder("WeatherIntent")\
        .require("WeatherKeyword")\
        .optionally("WeatherType")\
        .require("Location")\
        .build()
    engine.register_intent_parser(weather_intent, domain='Domain1')


def register_time():
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


def run(intent):
    intent = "".join(map(chr, intent))
    for i in engine.determine_intent(intent):
        if i and i.get('confidence') > 0:
            return json.dumps(i)
        else:
            return "{}"


if __name__ == "__main__":
    register_weather()
    register_time()
    intent_res = run(' '.join(sys.argv[1:]))
    print(json.dumps(intent_res, indent=4))


