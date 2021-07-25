[![Build Status](https://travis-ci.com/magpie-ea/magpie-backend.svg?branch=master)](https://travis-ci.com/magpie-ea/magpie-backend) [![Coverage Status](https://coveralls.io/repos/github/magpie-ea/magpie-backend/badge.svg?branch=master)](https://coveralls.io/github/magpie-ea/magpie-backend?branch=master)

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Server Documentation](#server-documentation)
    - [Username and password for authentication](#username-and-password-for-authentication)
    - [Experiments](#experiments)
        - [Experiment creation](#experiment-creation)
        - [Complex experiments](#complex-experiments)
        - [Editing an experiment](#editing-an-experiment)
        - [Deactivating an experiment](#deactivating-an-experiment)
        - [Experiment Result submission via HTTP POST](#experiment-result-submission-via-http-post)
        - [Experiment results submission via Phoenix Channels](#experiment-results-submission-via-phoenix-channels)
        - [Experiment results retrieval as CSV](#experiment-results-retrieval-as-csv)
        - [Experiment results retrieval as JSON](#experiment-results-retrieval-as-json)
    - [Custom Data Records](#custom-data-records)
        - [Uploading a data record](#uploading-a-data-record)
        - [Retrieval of data records](#retrieval-of-data-records)
    - [Deploying the Server](#deploying-the-server)
        - [Deployment with Heroku](#deployment-with-heroku)
        - [Local (Offline) Deployment](#local-offline-deployment)
        - [Local (Offline) Deployment with Docker (Old method)](#local-offline-deployment-with-docker-old-method)
            - [First-time installation (requires internet connection)](#first-time-installation-requires-internet-connection)
            - [Deployment](#deployment)
    - [Logging](#logging)
    - [Upgrading a deployed instance of the server](#upgrading-a-deployed-instance-of-the-server)
    - [Creating a new local release](#creating-a-new-local-release)
- [Experiments (Frontend)](#experiments-frontend)
- [Additional Notes](#additional-notes)
- [Development](#development)

<!-- markdown-toc end -->

This is a server backend to run psychological experiments in the browser. It
helps receive, store and retrieve data. It also provides communication channels for multi-participant interactive experiments.

A [live demo](https://magpie-demo.herokuapp.com/) of the app is available. Note that this demo doesn't require user authentication.

If you encounter any bugs during your experiments please [submit an issue](https://github.com/magpie-ea/magpie-backend/issues).

Please also refer to the [\_magpie project site](https://magpie-ea.github.io/magpie-site) and its [section on the server app](https://magpie-ea.github.io/magpie-site/serverapp/overview.html) for additional documentation.

Work on this project was funded via the project
[Pro^3](http://www.xprag.de/?page_id=4759), which is part of the [XPRAG.de](http://www.xprag.de/) funded by the German Research
Foundation (DFG Schwerpunktprogramm 1727).

# Server Documentation

This section documents the server program.

## Username and password for authentication

The app now comes with [Basic access Authentication](https://en.wikipedia.org/wiki/Basic_access_authentication). The username and password are set under `config :magpie, :authentication`.

For local development, the default username is `default` and the default password is `password`. You may change it in `dev.exs`.

If you're deploying on Heroku, be sure to set environment variables `AUTH_USERNAME` and `AUTH_PASSWORD`, either via Heroku command line tool or in the Heroku user interface, under `Settings` tab.

## Experiments

### Experiment creation

One can create a new experiment with the `New` button from the user interface. The experiment name and author are mandatory fields. You can create multiple experiments with the same name + author combination. The unique identifier generated by the database itself will differentiate them.

After an experiment is created, you can see its ID in the main user interface. Use this ID for results submission and retrieval.

### Complex experiments

Complex experiments are now supported via [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html).

In a complex experiment, there is some sort of dependency between different realizations. For example, the experiment might be iterative, in that the input of the next generation will be the output of the previous generation (e.g. iterated narration). Or the experiment might be interactive, in that multiple participants need to be present simultaneously to perform a task (e.g. a game of chess).

Each participant will be assigned a unique `<variant-nr, chain-nr, realization-nr>` identifier, so that such dependencies could be made explicit.

The server is responsible for broadcasting messages between the participants. To make the backend as generic as possible, the specific interpretation and handling of the messages depend on the frontend client. For examples of frontends of complex experiments, please refer to: [1](https://github.com/magpie-ea/color-reference/) and [2](https://github.com/magpie-ea/iterated-experiment-example).

To create such an experiment, you need to specify the total number of variants, chains and realizations. Any positive integer is allowed.

The identifiers will be assigned incrementally in the order of `variant-nr` -> `chain-nr` -> `realization-nr`. Assuming the `<num-variants, num-chains, num-realizations>` trituple is specified as `<2, 3, 10>` at experiment creation, the participant who joins after the participant `<1, 1, 1>` will be assigned the identifier `<2, 1, 1>`, the participant who joins after `<2, 1, 3>` will be assigned the identifier `<1, 2, 3>`, etc.

Normally, an interactive experiment has multiple variants (for example, a speaker and a listener, or player-1 and player-2), while an iterated experiment has multiple chains.

A chain will reach its end when all realizations have been submitted. The total number of expected participants is `num-variants * num-chains * num-realizations`. For example, an iterated narration experiment might have 1 variant, 10 chains, with 20 realizations each chain, meaning that a total of 200 participants will be recruited.

Detailed descriptions can also be found at the experiment creation page.

### Editing an experiment

You can edit an experiment after its creation. However, note that at the moment the `<num_variants, num_chains, num_realizations>` trituple of a complex experiment is not editable after experiment creation.

### Deactivating an experiment

Once you don't want to receive any new submissions for a particular experiment, you can disable it via the edit interface by clicking on the `Edit` button.

### Experiment Result submission via HTTP POST

The server expects to receive a JSON **array** as the set of experiment results, via HTTP POST, at the address `{SERVER_ADDRESS}/api/submit_experiment/:id`, where `:id` is the unique experiment ID shown in the main user interface.

All objects of the array should contain a set of identical keys. Each object normally stands for one trial in the experiment, together with any additional information that is not associated with a particular trial, for example, the native language spoken by the participant.

<!-- Additionally, an optional array named `trial_keys_order`, which specifies the order in which the trial data should be -->
<!--  printed in the CSV output, can be included. If this array is not included, the trial data will be printed in alphabetical order, which might not be ideal. -->

[Here](https://jsfiddle.net/SZJX/Lg3vmk41/) you can find a minimal working example. The [Minimal Template](https://github.com/magpie-ea/MinimalTemplate) contains a full example experiment.

Note that to [POST a JSON object correctly](https://stackoverflow.com/questions/12693947/jquery-ajax-how-to-send-json-instead-of-querystring),
one needs to specify the `Content-Type` header as `application/json`, and use `JSON.stringify` to encode the data first.

Note that `crossDomain: true` is needed since the server domain will likely be different to the domain where the experiment is presented to the participant.

### Experiment results submission via Phoenix Channels

Since the client maintains a socket connection with the server in complex experiments, the submissions in such experiments are also expected to be performed via the socket. The server expects a `"submit_results"` message with a payload containing the `"results"` key. Examples: [1](https://github.com/magpie-ea/color-reference/) and [2](https://github.com/magpie-ea/iterated-experiment-example).

### Experiment results retrieval as CSV

Just press the button to the right of each row in the user interface.

### Experiment results retrieval as JSON

For some experiments, it might helpful to fetch and use data collected from previous experiment submissions in order to dynamically generate future trials. The \_magpie backend now provides this functionality.

For each experiment, you can specify the keys that should be fetched in the "Edit Experiment" user interface on the server app. Then, with a HTTP GET call to the `retrieve_experiment` endpoint, specifying the experiment ID, you will be able to get a JSON object that contains the results of that experiment so far.

`{SERVER_ADDRESS}/api/retrieve_experiment/:id`

A [minimal example](https://jsfiddle.net/SZJX/dp8ewnfx/) of frontend code using jQuery:

```javascript
$.ajax({
  type: 'GET',
  url: 'https://magpie-demo.herokuapp.com/api/retrieve_experiment/1',
  crossDomain: true,
  success: function(responseData, textStatus, jqXHR) {
    console.table(responseData);
  }
});
```

## Custom Data Records

Sometimes, it might be desirable to store custom data records on the server and later retrieve them for experiments, similar to the dynamic retrieval of previous experiment results. Now there is also an interface for it.

The type of each record is also JSON array of objects.

### Uploading a data record

The data record can be either:

- A CSV file containing the data to be stored in this record. The first row will be treated as the headers (keys). The file must have `.csv` extension.
- A JSON array of objects. The file must have `.json` extension.

The file can be chosen in the browser via the upload button.

If a data record is edited and a new file is uploaded, the old record will be overwritten.

### Retrieval of data records

Similar to experiment results, the data records can also be retrieved either as a CSV file via the browser or a JSON file via the API.

The JSON retrieval address is

`{SERVER_ADDRESS}/api/retrieve_custom_record/:id`

## Deploying the Server

This section documents some methods one can use to deploy the server, for both online and offline usages.

### Deployment with Heroku
[Heroku](https://www.heroku.com/) makes it easy to deploy an web app without having to manually manage the infrastructure. It has a free starter tier, which should be sufficient for the purpose of running experiments. If Heroku doesn't satisfy your needs, you may take a look at [Gigalixir](https://www.gigalixir.com/), an alternative free hosting service built for Elixir. Or you may want to to deploy the app on your own server.

We provide a script `deploy.sh` which is tested on MacOS and should also work on Linux. Before running the script, ensure that you have a [Heroku account](https://signup.heroku.com/) already, and have [Git](https://git-scm.com/downloads) and the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) installed and working on your computer. Then run the script with `sh deploy.sh NAME_OF_YOUR_APP USERNAME PASSWORD`, where
- `NAME_OF_YOUR_APP` is a unique name for your instance of the app on Heroku. It must start with a letter, end with a letter or digit, and can only contain lowercase letters, digits, and dashes.
- `USERNAME` and `PASSWORD` are credentials to be used when accessing the admin UI of the app.

The following is a step-by-step guide if you prefer to do the deployment manually instead.

There is an [official guide](https://hexdocs.pm/phoenix/heroku.html) from Phoenix framework on deploying on Heroku. The deployment procedure is based on this guide, but differs in some places.

1. Ensure that you have [the Phoenix Framework installed](https://hexdocs.pm/phoenix/installation.html) and working. (However, if you just want to deploy this server and do no development work/change on it at all, you may skip this step.)

2. Ensure that you have a [Heroku account](https://signup.heroku.com/) already, and have the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) installed and working on your computer.

3. Ensure you have [Git](https://git-scm.com/downloads) installed. Clone this git repo with `git clone https://github.com/magpie-ea/magpie-backend` or `git clone git@github.com:magpie-ea/magpie-backend.git`.

4. `cd` into the project directory just cloned from your Terminal (or cmd.exe on Windows).

5. Run `heroku create --buildpack "https://github.com/HashNuke/heroku-buildpack-elixir.git"`

6. Run `heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git`

   (Note: Although the command line output tells you to run `git push heroku master`, don't do it yet.)

7. Run `heroku buildpacks:add https://github.com/chrismcg/heroku-buildpack-elixir-mix-release`

7. You may want to change the application name instead of using the default name. In that case, run `heroku apps:rename newname`.

8. Run `heroku config:set HOST="[app_name].herokuapp.com" PORT=443` where `[app_name]` is the app name (shown when you first ran `heroku create`, e.g. `mysterious-meadow-6277`, or the app name that you set at the previous step, e.g. `newname`).

9. Run

   ```sh
   heroku addons:create heroku-postgresql:hobby-dev
   heroku config:set POOL_SIZE=18
   ```

10. Run `mix deps.get` then `mix phx.gen.secret`. Then run `heroku config:set SECRET_KEY_BASE="OUTPUT"`, where `OUTPUT` should be the output of the `mix phx.gen.secret` step.

    Note: If you don't have Phoenix framework installed on your computer, you may choose to use some other random generator for this step, which essentially asks for a random 64-character secret. On Mac and Linux, you may run `openssl rand -base64 64 | tr -d '\n'`. Or you may use an online password generator [such as the one offered by LastPass](https://lastpass.com/generatepassword.php).

11. Set the environment variables `AUTH_USERNAME` and `AUTH_PASSWORD` for authentication, either in the Heroku web interface or via the command line, i.e.

    ```sh
    heroku config:set AUTH_USERNAME="your_username"
    heroku config:set AUTH_PASSWORD="your_password"
    ```

    Note: You can also completely disable the basic auth with

    ```sh
    heroku config:set MAGPIE_NO_BASIC_AUTH="true"
    ```

12. Run `git push heroku master`. This will push the `master` branch of the repo to the git remote at Heroku, and deploy the app.

13. Run `heroku run "_build/prod/rel/magpie/bin/magpie eval 'Magpie.ReleaseTasks.db_migrate()'"` (Note the `'` in the command.)

14. Now, `heroku open` should open the frontpage of the app.

### Local (Offline) Deployment

From now on, the _\_magpie_ backend is available as a one-click executable to be run locally. Just download the archive corresponding to your platform under the Releases tab](https://github.com/magpie-ea/magpie-backend/releases). Then:

- Extract the archive
- Go to the folder `bin/`
- In your terminal, run `./magpie console`
- Open `localhost:4000` in your browser

Note that the experiment database lives in the file `magpie_db.sqlite3`.

For now, since the database file is bundled with the release itself, whenever you download a new release, it will contain no previous experiment results. For dynamic retrieval, you can manually upload relevant experiment results as custom records. If you want to keep all previous experiments, you may:

- Copy the old `magpie_db.sqlite3` file from the old release to the old release. However, please note that this method wouldn't work whenever the database schema changes between releases, since [Sqlite doesn't support removing columns in migrations](https://stackoverflow.com/questions/8442147/how-to-delete-or-add-column-in-sqlite).

### Local (Offline) Deployment with Docker (Old method)

If, for whatever reason, the downloaded release fails to run on your system, you may run the _\_magpie_ backend via Docker instead. The following are the instructions.

#### First-time installation (requires internet connection)

The following steps require an internet connection. After they are finished, the server can be launched offline.

1. Install Docker from https://docs.docker.com/install/. You may have to launch the application once in order to let it install its command line tools. Ensure that it's running by typing `docker version` in a terminal (e.g., the Terminal app on MacOS or cmd.exe on Windows).

   Note:

   - Although the Docker app on Windows and Mac asks for login credentials to Docker Hub, they are not needed for local deployment . You can proceed without creating any Docker account/logging in.
   - Linux users would need to install `docker-compose` separately. See relevant instructions at https://docs.docker.com/compose/install/.

2. Ensure you have [Git](https://git-scm.com/downloads) installed. Clone the server repo with `git clone https://github.com/magpie-ea/magpie-backend.git` or `git clone git@github.com:magpie-ea/magpie-backend.git`.

3. Open a terminal (e.g., the Terminal app on MacOS or cmd.exe on Windows), `cd` into the project directory just cloned via git.

4. For the first-time setup, run in the terminal

   ```sh
   docker volume create --name magpie-app-volume -d local
   docker volume create --name magpie-db-volume -d local
   docker-compose run --rm web bash -c "mix deps.get && npm install && node node_modules/brunch/bin/brunch build && mix ecto.migrate"
   ```

#### Deployment

After first-time installation, you can launch a local server instance which sets up the experiment in your browser and stores the results.

1. Run `docker-compose up` to launch the application every time you want to run the server. Wait until the line `web_1 | [info] Running MAGPIE.Endpoint with Cowboy using http://0.0.0.0:4000` appears in the terminal.

2. Visit `localhost:4000` in your browser. You should see the server up and running.

   Note: Windows 7 users who installed _Docker Machine_ might need to find out the IP address used by `docker-machine` instead of `localhost`. See [Docker documentation](https://docs.docker.com/get-started/part2/#build-the-app) for details.

3. Use <kbd>Ctrl + C</kbd> to shut down the server.

Note that the database for storing experiment results is stored at `/var/lib/docker/volumes/magpie-db-volume/_data` folder by default. As long as this folder is preserved, experiment results should persist as well.

## Upgrading a deployed instance of the server

1. `git pull` to pull in the newest changes.
2. `git push heroku master` to pull the changes to the deployed instance hosted on Heroku.
3. You may need to run `heroku run "_build/prod/rel/magpie/bin/magpie eval 'Magpie.ReleaseTasks.db_migrate()'"` again, if there are any changes to the database.

## Creating a new local release

(This is generally not needed for the end users.)

1. Make sure you have [elixir](https://elixir-lang.org/) and [nodejs](https://nodejs.org/en/) installed
2. Clone the repo and `cd` into the directory
3. `git checkout sqlite`
4. `npm install`
5. `node_modules/brunch/bin/brunch build --production`
   (or on Windows: `npm install -g brunch` and then `brunch build --production`)
6. MIX_ENV=prod mix deps.get
7. MIX_ENV=prod mix deps.compile
8. MIX_ENV=prod mix phx.digest
9. MIX_ENV=prod mix release

The release will be generated at `_build/prod/rel/magpie/bin/magpie`.

# Experiments (Frontend)

This program is intended to serve as the backend which stores and returns experiment results. An experiment frontend is normally written as a set of static webpages to be hosted on a hosting provider (e.g. [Github Pages](https://pages.github.com/)) and loaded in the participant's browser.

For detailed documentation on the structure and deployment of experiments, please refer to the [departure point repo](https://github.com/magpie-ea/departure-point) and the [\_magpie documentation](https://magpie-ea.github.io/magpie-site/).

# Additional Notes

- When submitting experiment results, it is expected that each trial record does not contain any object or array among its **values**. The reason is that it would then be hard for the CSV writer to correctly format and produce a CSV file. In such cases, it is best to split experiment results into different keys containing simple values, e.g.

  ```js
  {
    "response1": "a",
    "response2": "b",
    "response3": "c",
    // ...
  }
  ```

  instead of

  ```js
  {
    "response": {"1": "a", "2": "b", "3": "c"},
    // or
    "response": ["a", "b", "c"]
    // ...
  }
  ```

  (However, currently if you actually submitted an object or array, the backend will still print it out, as it is. Good luck trying to parse that in your CSV output though!)

- There is limited guarantee on database reliability on Heroku's Hobby (free) grade. If the magpie-demo site for your experiments, you should retrieve the experiment results and perform backups as soon as possible.

# Development

- This app is based on Phoenix Framework and written in Elixir. The following links could be helpful for learning Elixir/Phoenix:
  - Official website: http://www.phoenixframework.org/
  - Guides: http://phoenixframework.org/docs/overview
  - Docs: https://hexdocs.pm/phoenix
  - Mailing list: http://groups.google.com/group/phoenix-talk
  - Source: https://github.com/phoenixframework/phoenix

To run the server app locally with `dev` environment, the following instructions could help. However, as the configuration of Postgres DB could be platform specific, relevant resources for [Postgres](https://www.postgresql.org/) could help.

1. Install Postgres. Ensure that you have version 9.2 or greater (for its JSON data type). You can check the version with the command `psql --version`.
2. Make sure that Postgres is correctly initialized as a service. If you installed it via Homebrew, the instructions should be shown on the command line. If you're on Linux, [the guide on Arch Linux Wiki](https://wiki.archlinux.org/index.php/PostgreSQL#Initial_configuration) could help.
3. Start a postgres interactive terminal. On Linux you could do it with `sudo su - postgres` followed by `psql`. On MacOS you might be able to run `psql postgres` directly without using `sudo`.
4. Create the database user for dev environment. The username and password is specified in `dev.exs`. By default it's `magpie_dev` and `magpie`:

   ```sql
   CREATE USER magpie_dev WITH PASSWORD 'magpie';
   ```

5. Then, create the `magpie_dev` DB and grant all privileges on this DB to the user.

   ```sql
   CREATE DATABASE magpie_dev;
   GRANT ALL PRIVILEGES ON DATABASE magpie_dev TO magpie_dev;
   ```

   Or, alternatively, allow the user to create DBs by itself:

   ```sql
   ALTER USER magpie_dev CREATEDB;
   ```

6. Run `mix deps.get; mix ecto.create; mix ecto.migrate` in the app folder.

7. Run `npm install` to install the frontend dependencies.

8. Run `mix phx.server` to run the server on `localhost:4000`.

9. Every time a database change is introduced with new migration files, run `mix ecto.migrate` again before starting the server.
