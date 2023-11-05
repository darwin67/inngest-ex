# Load env
Dotenv.load()

# Start server
Inngest.Dev.Router.start_server()
|> Task.await(:infinity)
