"""
Applet: LOTR Quotes
Summary: Lord of the Rings Quotes
Description: Displays a random quote from a LOTR movie character
Author: pandincus and Ilya Zinger

Thanks to:
* 1. https://the-one-api.dev/ for the Lord of the Rings API, which we use as our
      source of truth for quotes and character information
* 2. https://elmah.io/tools/base64-image-encoder/ for the base64 image encoder, which
      we used to encode the pixel art images into base64 strings
"""

load("render.star", "render")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("http.star", "http")
load("secret.star", "secret")
load("random.star", "random")
load("encoding/csv.star", "csv")
load("cache.star", "cache")

ONE_RING_ROOT_API = "https://the-one-api.dev/v2"
API_KEY_ENCRYPTED = "AV6+xWcEl2FxUXXBCofv20FrllxVMcsXrXECb2capXAwiViRZudepczQSt5y4rrBQVGdfpr3uxwQNlJbIzXyoJZLBY7pRZX9MgJieuz3HWHIbqTlKEWgOVPF6YRJ5p5FVb0ukIrQUbINObJTeWlBT+r+x04Tpr/9DZo="
ALL_QUOTES_API = ONE_RING_ROOT_API + "/quote?limit=2500&character={characterIds}"
ALL_MOVIES_API = ONE_RING_ROOT_API + "/movie"
CSV_ENDPOINT = "https://gist.githubusercontent.com/pandincus/af0e64d66c646613d0d7081a1183c964/raw/14bf66b15d236ebdb27f04bfcbda4fd6eb6b2574/LOTR_Base64_Characters.csv"

# We cache for 4 hours
# This same TTL is used for 3 separate caches:
# 1. lotr_characters: The LOTR characters and images that we load from the CSV file (stored in a GitHub gist)
# 2. lotr_quotes: The LOTR quotes that we load from the One Ring API (we load all quotes at once, up to 2500. This does take about a second to load)
# 3. lotr_movies: The LOTR movies that we load from the One Ring API
CACHE_TTL_SECONDS = 60 * 60 * 4

### -------------------------------------------------- ###
###                   Helper functions                 ###
### -------------------------------------------------- ###
def load_characters_and_images(debug=False, bypass_cache=False):
    """Loads the LOTR characters and their images from a CSV file stored in a gist

    If the CSV file has already been loaded into the cache, it will be retrieved from there instead
    of making a network request to the gist

    Args:
        bypass_cache (bool): whether or not to bypass the cache and make a network request to the gist
        debug (bool): whether or not to print debug statements to the console (set to true to enable)

    Returns:
        dict: a dictionary of LOTR characters, keyed by id
    """

    lotr_characters_string = cache.get("lotr_characters")
    if bypass_cache == False and lotr_characters_string != None:
        debug_print(debug, "[Cache] LOTR Characters cache hit, found bytes: " + str(len(lotr_characters_string)))
        return json.decode(lotr_characters_string)

    response = http.get(CSV_ENDPOINT)
    if response.status_code != 200:
        fail("[CHARACTERS] Unexpected status:" + str(response.status_code))
    
    # make the request to the gist, load the csv
    lotr_characters_csv = csv.read_all(response.body(), trim_leading_space=True, skip=1)

    # iterate over the csv and construct a dictionary
    # the key in the dictionary is the id
    # the value is an object with 3 fields: id, name, image
    lotr_characters = {row_fields[1]: {"id": row_fields[1], "name": row_fields[0], "image": row_fields[2]} for row_fields in lotr_characters_csv}
    lotr_characters_string = json.encode(lotr_characters)
    debug_print(debug, "[Cache] LOTR Characters cache miss, loaded bytes: " + str(len(lotr_characters_string)))
    cache.set("lotr_characters", lotr_characters_string, ttl_seconds=CACHE_TTL_SECONDS)
    return lotr_characters

def load_all_quotes(character_ids, headers, debug=False, bypass_cache=False):
    """Loads all of the quotes for the given character ids

    If the quotes have already been loaded into the cache, they will be retrieved from there instead
    of making a network request to the One Ring API

    Args:
        character_ids (list): a list of character ids to load quotes for
        headers (dict): a dictionary of headers to send with the request
        bypass_cache (bool): whether or not to bypass the cache and make a network request to the One Ring API
        debug (bool): whether or not to print debug statements to the console (set to true to enable)
    
    Returns:
        dict: a dictionary of character ids to a list of quotes
    """
    lotr_quotes_string = cache.get("lotr_quotes")
    if bypass_cache == False and lotr_quotes_string != None:
        debug_print(debug, "[Cache] LOTR Quotes cache hit, found bytes: " + str(len(lotr_quotes_string)))
        return json.decode(lotr_quotes_string)
    
    # make a request to the One Ring API to get all of the quotes
    # the characterIds parameter is a list, so we must convert it to a comma-separated string
    response = http.get(ALL_QUOTES_API.format(characterIds=",".join(character_ids)), headers=headers)
    if response.status_code != 200:
        fail("[QUOTES] Unexpected status:" + str(response.status_code))

    quotes = response.json()["docs"]
    # construct a dictionary of character ids to a list of quotes
    # for each quote, add the quote to the list of quotes for the character
    lotr_quotes = {}
    for quote in quotes:
        character_id = quote["character"]
        if character_id not in lotr_quotes:
            lotr_quotes[character_id] = []
        lotr_quotes[character_id].append(quote)
    lotr_quotes_string = json.encode(lotr_quotes)
    debug_print(debug, "[Cache] LOTR Quotes cache miss, loaded bytes: " + str(len(lotr_quotes_string)))
    cache.set("lotr_quotes", lotr_quotes_string, ttl_seconds=CACHE_TTL_SECONDS)
    return lotr_quotes

def load_all_movies(headers, debug=False, bypass_cache=False):
    """Loads all of the LOTR movies from the One Ring API

    If the movies have already been loaded into the cache, they will be retrieved from there instead
    of making a network request to the One Ring API

    Args:
        headers (dict): a dictionary of headers to send with the request
        bypass_cache (bool): whether or not to bypass the cache and make a network request to the One Ring API
        debug (bool): whether or not to print debug statements to the console (set to true to enable)

    Returns:
        dict: a dictionary of movie ids to movie objects
    """

    lotr_movies_string = cache.get("lotr_movies")
    if bypass_cache == False and lotr_movies_string != None:
        debug_print(debug, "[Cache] LOTR Movies cache hit, found bytes: " + str(len(lotr_movies_string)))
        return json.decode(lotr_movies_string)
    
    # make a request to the One Ring API to get all of the movies
    response = http.get(ALL_MOVIES_API, headers=headers)
    if response.status_code != 200:
        fail("[MOVIES] Unexpected status:" + str(response.status_code))
    
    movies = response.json()["docs"]
    # construct a dictionary of movie ids to movie objects
    lotr_movies = {movie["_id"]: movie for movie in movies}
    lotr_movies_string = json.encode(lotr_movies)
    debug_print(debug, "[Cache] LOTR Movies cache miss, loaded bytes: " + str(len(lotr_movies_string)))
    cache.set("lotr_movies", lotr_movies_string, ttl_seconds=CACHE_TTL_SECONDS)
    return lotr_movies

def debug_print(debug, string):
    """Prints a string to the console, but only if the debug parameter is set to true

    Args:
        debug (bool): whether or not debug mode is enabled, which determines whether or not to print
        string (str): the string to print
    
    Returns:
        None
    """
    if debug:
        print(string)

### -------------------------------------------------- ###
###                  Main Applet Logic                 ###
### -------------------------------------------------- ###
def main(config):
    """Main function, invoked by the Pixlet runtime

    Args:
      config (dict): a dictionary of configuration parameters, passed in by the Pixlet runtime
                     The following parameters are supported:
                        - dev_api_key: the API key to use when making requests to the One Ring API when running locally
                        - character_id: the id of the character to use when fetching quotes (to avoid random selection)
                        - debug: whether or not to print debug statements to the console (set to true to enable)
                        - bypass_cache: whether or not to bypass the cache and make a network request to the gist
                     Supply the config parameter when using the pixlet render command
                        For example, pixlet render lotr_quotes.star dev_api_key=my_api_key character_id=5cd99d4bde30eff6ebccde5f debug=true

    Returns:
        render.Root: The rendered output, which is a scrolling marquee with a character image
    """

    # We set the authorization headers for the One Ring API here
    # Decrypt the hardcoded API key, or use the dev_api_key config parameter if running locally
    api_key = secret.decrypt(API_KEY_ENCRYPTED) or config.get("dev_api_key")
    headers = {
        "Authorization": "Bearer " + str(api_key)
    }
    # Set debug to True if the lowercased value of the debug config parameter is "true"
    debug = config.get("debug") != None and config.get("debug").lower() == "true"
    # Set bypass_cache to True if the lowercased value of the bypass_cache config parameter is "true"
    bypass_cache = config.get("bypass_cache") != None and config.get("bypass_cache").lower() == "true"

    debug_print(debug, "[Config] api_key: " + str(api_key))
    debug_print(debug, "[Config] bypass_cache: " + str(bypass_cache))

    # Load the LOTR characters and their images from the CSV file (or the cache)
    lotr_characters = load_characters_and_images(debug=debug, bypass_cache=bypass_cache)

    # Fetch ALL movies from One Ring API (or the cache)
    lotr_movies = load_all_movies(headers=headers, debug=debug, bypass_cache=bypass_cache)

    # Fetch all quotes for the loaded characters (or the cache)
    lotr_quotes = load_all_quotes(character_ids=lotr_characters.keys(), headers=headers, debug=debug, bypass_cache=bypass_cache)

    # Select a random character
    # If the config parameter character_id is supplied, use that character instead
    if config.get("character_id"):
        random_character_id = config.get("character_id")
    else:
        random_character_index = random.number(0, len(lotr_characters)-1)
        random_character_id = lotr_characters.keys()[random_character_index]
    random_character = lotr_characters[random_character_id]

    # Fetch quotes for the selected character
    character_quotes = lotr_quotes[random_character_id]
    debug_print(debug, "[Log] Found " + str(len(character_quotes)) + " quotes for " + random_character["name"] + " (" + random_character["id"] + ")")

    random_quote_index = 0
    random_quote = ""
    if len(character_quotes) == 1:
        random_quote = character_quotes[0]
    else:
        random_quote_index = random.number(0, len(character_quotes)-1)
        random_quote = character_quotes[random_quote_index]
    
    debug_print(debug, "[Log] We picked quote #" + str(random_quote_index) + " and the quote is \"" + str(random_quote["dialog"]) + "\"")
    
    # the layout is two columns, the left column is the quote (in a vertical scrolling marquee), the right column is the character
    # the right column is composed of two rows, the top row (24 pixels high) is the image,
    # the bottom row (8 pixels high) is the character and movie name
    return render.Root(
        delay = 75,
        child = render.Row(
            children = [
                render.Column(
                    children = [
                        render.Box(
                            width = 36,
                            height = 32,
                            color = "#540007",
                            child = render.Marquee(
                                height = 32,
                                scroll_direction = "vertical",
                                offset_start = 32,
                                child = render.WrappedText(
                                    font = "tom-thumb",
                                    width = 36,
                                    content = random_quote["dialog"]
                                )
                            )
                        )
                    ]
                ),
                render.Column(
                    children = [
                        render.Row(
                            expanded = True,
                            main_align = "center",
                            children = [
                                render.Image(
                                    src = base64.decode(random_character["image"]),
                                    width = 28,
                                    height = 24
                                )
                            ]
                        ),
                        render.Row(
                            expanded = True,
                            children = [
                                render.Marquee(
                                    width = 28,
                                    height = 8,
                                    offset_start = 2,
                                    scroll_direction = "horizontal",
                                    align = "center",
                                    child = render.WrappedText(
                                        font = "tom-thumb",
                                        height = 8,
                                        content = random_character["name"] + " - " + lotr_movies[random_quote["movie"]]["name"]
                                    )
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    )