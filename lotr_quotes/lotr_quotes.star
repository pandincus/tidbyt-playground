"""
Applet: LOTR Quotes
Summary: Lord of the Rings Quotes
Description: Displays a random quote from a LOTR movie character
Author: pandincus and Ilya Zinger
"""

#adding some comments to check commits in vscode

load("render.star", "render")
load("encoding/base64.star", "base64")
load("http.star", "http")
load("secret.star", "secret")
load("random.star", "random")

ONE_RING_ROOT_API = "https://the-one-api.dev/v2"
# We query for the (currently hardcoded) list of
# Gandalf,Legolas,Gimli,Boromir,Frodo Baggins,Samwise Gamgee,Galadriel,Aragorn II Elessar,Elrond,Gollum,Peregrin Took,Meriadoc Brandybuck,Théoden,Denethor II,Éowyn,Arwen,Faramir
# We have to URL escape the spaces and special characters in their names
# starlark allows this via url_encode(str)
DEFAULT_CHARACTER_NAMES = "Gandalf%2CLegolas%2CGimli%2CBoromir%2CFrodo%20Baggins%2CSamwise%20Gamgee%2CGaladriel%2CAragorn%20II%20Elessar%2CElrond%2CGollum%2CPeregrin%20Took%2CMeriadoc%20Brandybuck%2CTh%C3%A9oden%2CDenethor%20II%2C%C3%89owyn%2CArwen%2CFaramir"
CHARACTERS_API = ONE_RING_ROOT_API + "/character?name=" + DEFAULT_CHARACTER_NAMES
API_KEY_ENCRYPTED = "AV6+xWcEl2FxUXXBCofv20FrllxVMcsXrXECb2capXAwiViRZudepczQSt5y4rrBQVGdfpr3uxwQNlJbIzXyoJZLBY7pRZX9MgJieuz3HWHIbqTlKEWgOVPF6YRJ5p5FVb0ukIrQUbINObJTeWlBT+r+x04Tpr/9DZo="
QUOTES_API_TEMPLATE = ONE_RING_ROOT_API + "/character/{characterId}/quote"
GET_ALL_MOVIES_API = ONE_RING_ROOT_API + "/movie"

LOTR_ICON = base64.decode("iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7CAAAOwgEVKEqAAAADcklEQVR4Xj1TTW8bVRQ9M54ZJzO2Z2yPk9pxSBNoa1IajBpbEGgpoKAGoqJUagWIJSyMEGqQWCAksskfoF2wQGKBECvYVCL9AFEa2qhVUhWRj2nrhjSx09ip44nHHzO2xx7eTARn8fTe07vnnnvufRQIJiYm6FQq9XokEvn13CcfYXUzB9Nsg2VciAS9aDIUNgslWG0Lp8dO4cLX5yk7zoazYRiGisfj0YjMbzwV9uDywn2UawYYF41IwIuBaDdu3cugTQh2cwWUi6X/CRibwDRNy+fzfNa2dOxWXLAaOlJvvYSgX0SxXMX3V2/DgsvJ2OnzQNeqH5CYH+wzbS8sy1KBoHxuu1bHdqkKodON9958Be+fPIYT8RiajQZeGNgHoYODm+/AcCLx6X8l0Lb8ZDL5jpJewVBfN2RvJ6mdgRyU9t602ph4+XncW89BFnnnqq+vN0HTtOAo8Pl81MjIyGh/iEehVMGddAYjB3tgWaTeUhmwWjhzPI6GoSOvkjOBotyFJElxx79AIEBfuXrpY87jQja9gbOJA9B2K8hvZvHj9WXMzf8FymrDT6RvamUE/BIo03R8cwgEQaAmJyfx+VdfgJiON16Mg2dp1FkPaF7Cu6NJRAMCOK8fX377E9osC50QdHV3HdU0bc4hmLl8CYybg9XU8ezgIQRFL3TLheMJBsZOHkcH9+NxvgCGppDTamiSdkZCofMP0w8v0PV63VKUJQi8G3AxmL2rEHktqKT+UqUGhuNw7eYCLs7eQW63Cr3RhOzjIbhZxw9mbGxs+fqfM2hoLWIpg59/mwNPWbihZGA0WyhWdBzuCSDWI6NbFJCrtTAaH8DimrZHoKpFUSWPjKZpTyTSORUb2ypSp15Fo97EzUcFrCgKltYfwyA5SHPw9/o2tOreMNK3blzpeq5/H8JkZHtDIgxi7sz8CpFaR9moYWNtlQTk8cu8AosorJNET3Y0jL89vqcgvZbZqjFceLA3BLPdRn6nhK6AiO8u/g7Rw2PhQQaqWoIoSjDJUNmQpDCUFeWIo0CrNmgf6fHqVpH8LAocy2D4mSiGBqJQKwY6ODdOJo8g7Pci6OVBt1qIHYxhcXFxa2pqqkDhkOsb/NM60Xvg6ViImKQR5z8cHUafLOLa8iO8dni/k9XG7FIWQ8fGMT09zcmy3J/NZv/4Fw0uaOoDBK6wAAAAAElFTkSuQmCC")

def main(config):


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

    # Fetch the characters from the One Ring API, store them in a list
    response = http.get(CHARACTERS_API, headers=headers)
    if response.status_code != 200:
        fail("One Ring Characters API Failed with status code", response.status_code)

    characters_json = response.json()["docs"]

    # Generate random character
    random_character_index = random.number(0, len(characters_json)-1)
    random_character = characters_json[random_character_index]

    quotesApi = QUOTES_API_TEMPLATE.format(characterId=random_character["_id"])
    response = http.get(quotesApi, headers=headers)

    if response.status_code != 200:
        fail("One Ring Quotes API Failed with status code", response.status_code)
    
    quotes_json = response.json()["docs"]

    # print the number of quotes along with the character name and id
    print("Found " + str(len(quotes_json)) + " quotes for " + random_character["name"] + " (" + random_character["_id"] + ")")

    if len(quotes_json) == 0:
        print("Found no quotes for " + random_character["name"] + "(" + random_character["_id"] + ")")
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
        delay = 100,
        child = render.Row(
            children = [
                render.Column(
                    children = [
                        render.Box(
                            width = 36,
                            height = 32,
                            color = "#540007",
                            child = render.Marquee(
                                width = 36,
                                height = 32,
                                scroll_direction = "vertical",
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
                                render.Image(src=LOTR_ICON)
                            ]
                        ),
                        render.Row(
                            expanded = True,
                            children = [
                                render.Marquee(
                                    width = 28,
                                    height = 8,
                                    scroll_direction = "horizontal",
                                    align = "center",
                                    child = render.WrappedText(
                                        font = "tom-thumb",
                                        height = 8,
                                        content = random_character["name"]
                                 )
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
                                        content = movie_names_by_id[random_quote["movie"]]
                                    )
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        #delay = 100, # 100ms delay between frames (to slow down the scrolling and give the user time to read)
        #child = render.Marquee(
        #    width = 64, # maximum width
        #    height = 32, # maximum height
        #    scroll_direction = "horizontal",
        #    child = render.WrappedText(
        #        content = random_character["name"] + ": " + random_quote["dialog"]
        #    )
        #)
    )

# Helper function to map a function over a list
def map(f, list):
    return [f(x) for x in list]