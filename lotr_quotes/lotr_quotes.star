"""
Applet: LOTR Quotes
Summary: Lord of the Rings Quotes
Description: Displays a random quote from a LOTR movie character
Author: pandincus and Ilya Zinger
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
CSV_ENDPOINT = "https://gist.githubusercontent.com/pandincus/61249b73811c0d6bd910b3088c89fdb3/raw/a9ccedff07a5c1aa5a77708d41b83fb058a2ef44/LOTR_Base64_Characters.csv"

# Load characters and images
# ----------------------
def load_characters_and_images():

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

def main(config):

    lotr_characters = load_characters_and_images()

    # Supply the config parameter when using the pixlet render command
    # For example, pixlet render lotr_quotes.star dev_api_key=my_api_key
    api_key = secret.decrypt(API_KEY_ENCRYPTED) or config.get("dev_api_key")
    headers = {
        "Authorization": "Bearer " + str(api_key)
    }

    # Fetch ALL movies from One Ring API, store them in a list
    response = http.get(GET_ALL_MOVIES_API, headers=headers)
    if response.status_code != 200:
        fail("One Ring Movies API Failed with status code", response.status_code)

    movies_json = response.json()["docs"]
    movie_names_by_id = {movie["_id"]: movie["name"] for movie in movies_json}

    # Generate random character
    random_character_index = random.number(0, len(lotr_characters)-1)
    random_character_id = lotr_characters.keys()[random_character_index]
    random_character = lotr_characters[random_character_id]

    quotesApi = QUOTES_API_TEMPLATE.format(characterId=random_character_id)
    response = http.get(quotesApi, headers=headers)

    if response.status_code != 200:
        fail("One Ring Quotes API Failed with status code", response.status_code)
    
    quotes_json = response.json()["docs"]

    # print the number of quotes along with the character name and id
    print("Found " + str(len(quotes_json)) + " quotes for " + random_character["name"] + " (" + random_character["id"] + ")")

    if len(quotes_json) == 0:
        print("Found no quotes for " + random_character["name"] + "(" + random_character["id"] + ")")
    elif len(quotes_json) == 1:
        random_quote = quotes_json[0]
    else:
        random_quote_index = random.number(0, len(quotes_json)-1)
        random_quote = quotes_json[random_quote_index]
    
    print("We picked " + str(random_quote_index) + " and the quote is" + str(random_quote))
    
    # entire left side (2/3) = quote
    # top right = character icon
    # bottom right = character name

    # two columns = first column is like 42 pixels wide, second column is 22 pixels wide, 32 pixels tall
    # first column: all it has is a marquee holding wrapped text, scrolling vertically
    # second column: has two rows, first row is 16 pixels tall, second row is 16 pixels tall
    # second column, first row has the rendered image for icon
    # second colun, second row just has wrapped text for the character name

    return render.Root(
        delay = 80,
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