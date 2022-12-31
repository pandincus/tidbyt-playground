"""
Applet: LOTR Quotes
Summary: Lord of the Rings Quotes
Description: Displays a random quote from a LOTR movie character
Author: pandincus and Ilya Zinger
"""

#adding some comments to check commits in vscode

load("render.star", "render")
load("http.star", "http")
load("secret.star", "secret")
load("random.star", "random")


ONE_RING_ROOT_API = "https://the-one-api.dev/v2"
# We query for the (currently hardcoded) list of
# Gandalf,Legolas,Gimli,Boromir,Frodo Baggins,Samwise Gamgee,Galadriel,Aragorn II Elessar,Elrond,Gollum,Peregrin Took,Meriadoc Brandybuck,Théoden,Denethor II,Éowyn,Arwen,Faramir
# We have to URL escape the spaces and special characters in their names
# As starlark does not include a function to do this, we have to do it manually
DEFAULT_CHARACTER_NAMES = "Gandalf%2CLegolas%2CGimli%2CBoromir%2CFrodo%20Baggins%2CSamwise%20Gamgee%2CGaladriel%2CAragorn%20II%20Elessar%2CElrond%2CGollum%2CPeregrin%20Took%2CMeriadoc%20Brandybuck%2CTh%C3%A9oden%2CDenethor%20II%2C%C3%89owyn%2CArwen%2CFaramir"
CHARACTERS_API = ONE_RING_ROOT_API + "/character?name=" + DEFAULT_CHARACTER_NAMES
API_KEY_ENCRYPTED = "AV6+xWcEl2FxUXXBCofv20FrllxVMcsXrXECb2capXAwiViRZudepczQSt5y4rrBQVGdfpr3uxwQNlJbIzXyoJZLBY7pRZX9MgJieuz3HWHIbqTlKEWgOVPF6YRJ5p5FVb0ukIrQUbINObJTeWlBT+r+x04Tpr/9DZo="

def main(config):
    # Supply the config parameter when using the pixlet render command
    # For example, pixlet render lotr_quotes.star dev_api_key=my_api_key
    api_key = secret.decrypt(API_KEY_ENCRYPTED) or config.get("dev_api_key")
    headers = {
        "Authorization": "Bearer " + str(api_key)
    }

    # Fetch the characters from the One Ring API, store them in a list
    response = http.get(CHARACTERS_API, headers=headers)
    if response.status_code != 200:
        fail("One Ring API Failed with status code", response.status_code)

    characters_json = response.json()["docs"]
    characters = []
    for i in range(0, len(characters_json)):
        characters.append({
            "name": characters_json[i]["name"],
            "id": characters_json[i]["_id"]
        })

    # Generate random character
    random_character = random.number(0, len(characters)-1)

    return render.Root(
        delay = 100, # 100ms delay between frames (to slow down the scrolling and give the user time to read)
        child = render.Marquee(
            width = 64, # maximum width
            height = 32, # maximum height
            scroll_direction = "horizontal",
            child = render.WrappedText(
                content = characters_json[random_character]["name"]
            )
        )
    )

# Helper function to map a function over a list
def map(f, list):
    return [f(x) for x in list]