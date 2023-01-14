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
load("http.star", "http")
load("secret.star", "secret")
load("random.star", "random")
load("encoding/csv.star", "csv")

ONE_RING_ROOT_API = "https://the-one-api.dev/v2"
API_KEY_ENCRYPTED = "AV6+xWcEl2FxUXXBCofv20FrllxVMcsXrXECb2capXAwiViRZudepczQSt5y4rrBQVGdfpr3uxwQNlJbIzXyoJZLBY7pRZX9MgJieuz3HWHIbqTlKEWgOVPF6YRJ5p5FVb0ukIrQUbINObJTeWlBT+r+x04Tpr/9DZo="
QUOTES_API_TEMPLATE = ONE_RING_ROOT_API + "/character/{characterId}/quote"
GET_ALL_MOVIES_API = ONE_RING_ROOT_API + "/movie"
CSV_ENDPOINT = "https://gist.githubusercontent.com/pandincus/af0e64d66c646613d0d7081a1183c964/raw/14bf66b15d236ebdb27f04bfcbda4fd6eb6b2574/LOTR_Base64_Characters.csv"

def load_characters_and_images():
    """Loads the LOTR characters and their images from a CSV file stored in a gist

    Returns:
      dict: a dictionary of LOTR characters, keyed by id
    """

    request = http.get(CSV_ENDPOINT)
    if request.status_code != 200:
        fail("Unexpected status:" + request.status_code)
    
    # make the request to the gist, load the csv
    request_body = request.body()
    lotr_characters_csv = csv.read_all(request_body, trim_leading_space=True, skip=1)

    # iterate over the csv and construct a dictionary
    # the key in the dictionary is the id
    # the value is an object with 3 fields: id, name, image
    return {row_fields[1]: {"id": row_fields[1], "name": row_fields[0], "image": base64.decode(row_fields[2])} for row_fields in lotr_characters_csv}

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

def main(config):
    """Main function, invoked by the Pixlet runtime

    Args:
      config (dict): a dictionary of configuration parameters, passed in by the Pixlet runtime
                     The following parameters are supported:
                        - dev_api_key: the API key to use when making requests to the One Ring API when running locally
                        - character_id: the id of the character to use when fetching quotes (to avoid random selection)
                        - debug: whether or not to print debug statements to the console (set to true to enable)
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

    # Load the LOTR characters and their images from the CSV file
    lotr_characters = load_characters_and_images()

    # Fetch ALL movies from One Ring API, store them in a list
    response = http.get(GET_ALL_MOVIES_API, headers=headers)
    if response.status_code != 200:
        fail("One Ring Movies API Failed with status code", response.status_code)

    movies_json = response.json()["docs"]
    movie_names_by_id = {movie["_id"]: movie["name"] for movie in movies_json}

    # Select a random character
    # If the config parameter character_id is supplied, use that character instead
    if config.get("character_id"):
        random_character_id = config.get("character_id")
    else:
        random_character_index = random.number(0, len(lotr_characters)-1)
        random_character_id = lotr_characters.keys()[random_character_index]
    random_character = lotr_characters[random_character_id]

    quotes_api = QUOTES_API_TEMPLATE.format(characterId=random_character_id)
    response = http.get(quotes_api, headers=headers)

    if response.status_code != 200:
        fail("One Ring Quotes API Failed with status code", response.status_code)
    
    quotes_json = response.json()["docs"]

    # print the number of quotes along with the character name and id
    debug_print(debug, "Found " + str(len(quotes_json)) + " quotes for " + random_character["name"] + " (" + random_character["id"] + ")")

    random_quote_index = 0
    random_quote = ""
    if len(quotes_json) == 1:
        random_quote = quotes_json[0]
    else:
        random_quote_index = random.number(0, len(quotes_json)-1)
        random_quote = quotes_json[random_quote_index]
    
    debug_print(debug, "We picked " + str(random_quote_index) + " and the quote is" + str(random_quote))
    
    # the layout is two columns, the left column is the quote (in a scrolling marquee), the right column is the character
    # the right column is composed of two rows, the top row (24 pixels high) is the character image,
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
                                    src = random_character["image"],
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
                                        content = random_character["name"] + " - " + movie_names_by_id[random_quote["movie"]]
                                    )
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    )