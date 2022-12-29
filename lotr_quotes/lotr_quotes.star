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

ONE_RING_ROOT_API = "https://the-one-api.dev/v2"
DEFAULT_CHARACTER_NAMES = "Gandalf,Legolas,Gimli,Boromir,Aragorn,Frodo,Samwise,Gollum,Elrond,Meriadoc,Pippin"
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

    # Render the list of character names, with commas in between each name
    # (This is temporary, we'll replace this with a random quote in the upcoming commits)
    character_names = ", ".join(map(lambda c: c["name"], characters))
    return render.Root(
        child = render.Text(character_names)
    )

# Helper function to map a function over a list
def map(f, list):
    return [f(x) for x in list]