# tamagotchi_server

This is the starting point for your Serverpod server.

To run your server, you first need to start Postgres. It's easiest to do with Docker. (This project does not use Redis — `redis.enabled` is `false` in every runmode config.)

    docker compose up --build --detach

Then you can start the Serverpod server.

    dart bin/main.dart

When you are finished, you can shut down Serverpod with `Ctrl-C`, then stop Postgres.

    docker compose stop
