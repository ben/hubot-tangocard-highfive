# hubot-tangocard-highfive

This is a [Hubot](https://hubot.github.com/) plugin with two functions:

1. Enable you to publicly high-five someone in the chat room.
1. Optionally send them a gift card.

## Installation

Create the NPM dependency:

```shell
$ npm install hubot-tangocard-highfive --save
```

And tell Hubot to load it on startup by modifying your `external-scripts.json` to look something like this:

```json
[
    "some-plugin",
    "hubot-tangocard-highfive",
    "some-other-plugin"
]
```

## Usage

Run this command in a chat room:

```
hubot highfive @john for nailing that design
```

Hubot will then send a message to the current room (or a configurable public room, see below) with congratulations and a nice GIF.
If configured properly, this command will additionally trigger a gift card to be sent to the high-fived user:

```
hubot highfive @jane $25 for landing that huge account
```

## Configuration

First, set up `HUBOT_HOSTNAME` to a URL where your hubot can be reached via https. Then run:

```
hubot highfive config
```

Hubot will give you a link to the configuration page, where a form will help walk you through all the environment variables you need/want to set.
When you're done filling out the form (and optionally submitting the credit-card information), copy the contents of the text area at the bottom, and paste them into a `heroku config` or `export` command-line, so all the values become part of Hubot's environment.

The basic high-five configuration consists of just two options:

- The chat service (`HUBOT_HIGHFIVE_EMAIL_SERVICE`) helps the plugin figure out how to find the right room to send messages to, and how to format messages properly. If this is set to `slack`, you'll also need to configure `HUBOT_SLACK_API_TOKEN`.
- The announcement room (`HUBOT_HIGHFIVE_ROOM`)  sets the room in which high-fives are announced. If it's empty, the plugin will just spit messages out to the room it's triggered in.

You can add some custom GIFs by specifying `HUBOT_HIGHFIVE_GIFS` to be a set of URLs separated by spaces.

## Tango Card Configuration

The plugin also has the ability to automatically order gift cards from Tango Card and send them to the target user's email address. To access the Tango Card API, you'll have to go to their [information page](https://www.tangocard.com/giftcardapi) and click the "Get More Information" button at the bottom.

Once you've done that, you'll need to tell the plugin some values:

- The award limit (`HUBOT_HIGHFIVE_AWARD_LIMIT`) sets an upper bound on the size of gift card that can be sent. The default is $150.
- The daily limit (`HUBOT_HIGHFIVE_DAILY_LIMIT`) sets a limit on how much any single user can give out in a day. The default is $500.
- The gift card SKU (`HUBOT_TANGOCARD_SKU`) configures which type of gift card you want to send to your team (defaults to an Amazon card if not set.)  You can see the complete list at https://sandbox.tangocard.com/raas/v1/rewards
- Overriding the Tango Card root URL (`HUBOT_TANGOCARD_ROOTURL`) lets you use the sandbox API for testing (it's at https://sandbox.tangocard.com/raas/v1/). The default is the production endpoint.
- When you sign up for the Tango Card API, they'll provide you with a username (`HUBOT_TANGOCARD_USER`) and a secret key (`HUBOT_TANGOCARD_KEY`).
- The customer and account fields (`HUBOT_TANGOCARD_CUSTOMER` and `HUBOT_TANGOCARD_ACCOUNT`) are fairly arbitrary, and only really exist so you can track expenses through Tango Card. This plugin will use the same values for every card it orders.
- Type in the credit card info and hit "Process" to use the Tango Card API to generate a credit-card token (`HUBOT_TANGOCARD_CC`) and record the auth code from the card (`HUBOT_TANGOCARD_AUTH`) and the account email address (`HUBOT_TANGOCARD_EMAIL`). **Note that you have to click the "Process" button to generate a credit-card token.**

## Google Spreadsheet Configuration

The plugin will automatically log gift cards to a Google Spreadsheet. To make this happen, do this:

1. Open the [Google Developers Console](https://console.developers.google.com/project) and create an application. The name doesn't matter.
1. Open the "APIs" section and enable the "Drive API" for your application.
1. Open the "Credentials" section and create a "New Client ID". Choose a "Service Account".
1. Copy the service account's email address and plug it into the highfive configuration form.
1. A JSON file may download automatically - ignore it.
1. Click "Generate new P12 key", and take a note of the resulting password, because you won't be able to get it back.
1. The previous step should have downloaded a `.p12` key file to your computer. Run the following command to convert it to a PEM file:
  ```
  openssl pkcs12 -in downloaded-key-file.p12 -out your-key-file.pem -nodes
  ```
1. Take the contents of that PEM file, and copy-paste them into the highfive configuration form.
1. Create a new Google Spreadsheet, and share it to the email address you got in step 3. Make sure the sharing includes "edit" privileges.
1. Copy the sheet's ID (it's in the url: `https://docs.google.com/…/spreadsheets/d/<SHEET_ID>/…`), and plug that into the highfive config form.
1. Type the name of the worksheet into the highfive config form. This is probably "Sheet1".

This will set the following environment variables:

- `HUBOT_HIGHFIVE_SHEET_EMAIL`
- `HUBOT_HIGHFIVE_SHEET_KEY`
- `HUBOT_HIGHFIVE_SHEET_DOCID`
- `HUBOT_HIGHFIVE_SHEET_SHEETNAME`


## TODO

- Chat services that aren't Slack.
- Other logging services
