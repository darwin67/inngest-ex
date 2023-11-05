# Load env
Dotenv.load()

# Start server
Inngest.Test.PlugRouter.start_server()
|> Task.await(:infinity)
