# Lumear buyer and seller app

Flutter mobile app backed by a local Python API and the standalone MySQL database.

Start the API with `node server.js` (or `npm start`). The launcher uses the private
cloud database settings when `.env.cloud` exists. Use `npm run start:local` for
the local database. It requires Python and `backend/requirements-hosting.txt`;
it launches the existing backend rather than replacing it with a Node-only API.
Starting this on your computer does not deploy it online. An online API host and
an APK configured with that host's HTTPS address are still required for USB-free use.

Use the MySQL USB phone launch in VS Code to start the API and connect the tablet.
See [backend setup](backend/README.md) for Gmail email-code setup, launch commands,
connected features, current limitations and verification instructions.
